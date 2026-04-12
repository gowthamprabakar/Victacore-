// GRDBGraphStore.swift
// VitaCoreGraph — GRDB/SQLite-backed implementation of GraphStoreProtocol.
//
// This is the concrete replacement for the archived Kuzu-based design (AD-01 revised).
// Conforms to the frozen GraphStoreProtocol; the rest of the app is unaware of
// the swap because it only depends on the protocol interface.
//
// Threading model: GRDB's DatabasePool serialises writes and allows concurrent
// reads. The actor's role here is to provide a Sendable/Swift-concurrency-friendly
// API surface; GRDB handles the underlying lock contention.

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - GRDBGraphStore

/// Production `GraphStoreProtocol` implementation backed by SQLite via GRDB.
///
/// Usage:
/// ```swift
/// // In-memory (tests)
/// let store = try GRDBGraphStore.inMemory()
///
/// // On-disk (app)
/// let url = FileManager.default
///     .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
///     .appendingPathComponent("vitacore.sqlite")
/// let store = try GRDBGraphStore(path: url.path)
/// ```
public final class GRDBGraphStore: GraphStoreProtocol, @unchecked Sendable {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    private let dbQueue: DatabaseWriter

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    /// Creates a GRDB graph store backed by a file on disk with Data Protection.
    ///
    /// - Parameter path: Absolute file path for the SQLite database file.
    /// - Throws: GRDB errors from opening/migrating the DB.
    public init(path: String) throws {
        var config = Configuration()
        // Data Protection: require unlock for first access, then remain accessible
        // even when the device is re-locked while the app is running in background.
        config.prepareDatabase { db in
            // `FileProtectionType.completeUnlessOpen` is the iOS-appropriate level
            // for background-running apps that need persistent storage.
            // GRDB honours this via NSFileProtectionKey on the database file.
        }

        let pool = try DatabasePool(path: path, configuration: config)

        // Apply iOS file protection class to the SQLite file (and WAL/SHM siblings).
        try GRDBGraphStore.applyFileProtection(at: path)

        self.dbQueue = pool

        // Run migrations
        try VitaCoreGraphSchema.migrator().migrate(pool)
    }

    /// Creates an in-memory graph store. Use in unit tests or previews.
    public static func inMemory() throws -> GRDBGraphStore {
        let queue = try DatabaseQueue() // empty = in-memory
        try VitaCoreGraphSchema.migrator().migrate(queue)
        return GRDBGraphStore(wrapping: queue)
    }

    /// Internal bridge init used by `inMemory()`.
    private init(wrapping writer: DatabaseWriter) {
        self.dbQueue = writer
    }

    // -------------------------------------------------------------------------
    // MARK: File Protection
    // -------------------------------------------------------------------------

    private static func applyFileProtection(at path: String) throws {
        #if os(iOS)
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUnlessOpen
        ]
        try? fm.setAttributes(attrs, ofItemAtPath: path)
        // Apply to WAL/SHM siblings too
        try? fm.setAttributes(attrs, ofItemAtPath: path + "-wal")
        try? fm.setAttributes(attrs, ofItemAtPath: path + "-shm")
        #endif
    }

    // -------------------------------------------------------------------------
    // MARK: GraphStoreProtocol — Reading queries
    // -------------------------------------------------------------------------

    public func getLatestReading(for metricType: MetricType) async throws -> Reading? {
        try await dbQueue.read { db in
            let row = try ReadingRow
                .filter(Column("metric_type") == metricType.rawValue)
                .order(Column("timestamp").desc)
                .fetchOne(db)
            return row?.toReading()
        }
    }

    public func getRangeReadings(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Reading] {
        try await dbQueue.read { db in
            let rows = try ReadingRow
                .filter(Column("metric_type") == metricType.rawValue)
                .filter(Column("timestamp") >= startDate)
                .filter(Column("timestamp") <= endDate)
                .order(Column("timestamp").asc)
                .fetchAll(db)
            return rows.compactMap { $0.toReading() }
        }
    }

    public func getAggregatedMetric(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> AggregatedMetric? {
        try await dbQueue.read { db in
            // Single-query SQL aggregate — MUCH faster than fetching all rows and
            // reducing in Swift. Uses the (metric_type, timestamp) composite index.
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    MIN(value) AS min_v,
                    MAX(value) AS max_v,
                    AVG(value) AS avg_v,
                    COUNT(*)   AS count_v
                FROM readings
                WHERE metric_type = ?
                  AND timestamp >= ?
                  AND timestamp <= ?
                """,
                arguments: [metricType.rawValue, startDate, endDate]
            )

            guard let row else { return nil }
            let count: Int = row["count_v"] ?? 0
            guard count > 0 else { return nil }

            return AggregatedMetric(
                metricType:  metricType,
                min:         row["min_v"] ?? 0,
                max:         row["max_v"] ?? 0,
                average:     row["avg_v"] ?? 0,
                count:       count,
                windowStart: startDate,
                windowEnd:   endDate
            )
        }
    }

    public func getCurrentSnapshot() async throws -> MonitoringSnapshot {
        // Build a full-metric snapshot by running 15 latest-reading queries in
        // parallel. GRDB allows concurrent reads through DatabasePool.
        async let glucose      = try self.getLatestReading(for: .glucose)
        async let bpSys        = try self.getLatestReading(for: .bloodPressureSystolic)
        async let bpDia        = try self.getLatestReading(for: .bloodPressureDiastolic)
        async let hr           = try self.getLatestReading(for: .heartRate)
        async let hrv          = try self.getLatestReading(for: .heartRateVariability)
        async let spo2         = try self.getLatestReading(for: .spo2)
        async let steps        = try self.getLatestReading(for: .steps)
        async let inactivity   = try self.getLatestReading(for: .inactivityDuration)
        async let sleep        = try self.getLatestReading(for: .sleep)
        async let fluid        = try self.getLatestReading(for: .fluidIntake)
        async let calories     = try self.getLatestReading(for: .calories)
        async let carbs        = try self.getLatestReading(for: .carbs)
        async let protein      = try self.getLatestReading(for: .protein)
        async let fat          = try self.getLatestReading(for: .fat)
        async let weight       = try self.getLatestReading(for: .weight)

        // Await all concurrent reads
        let g      = try await glucose
        let sys    = try await bpSys
        let dia    = try await bpDia
        let h      = try await hr
        let hv     = try await hrv
        let ox     = try await spo2
        let st     = try await steps
        let inact  = try await inactivity
        let sl     = try await sleep
        let fl     = try await fluid
        let cal    = try await calories
        let cb     = try await carbs
        let pr     = try await protein
        let ft     = try await fat
        let wt     = try await weight

        // Compute evaluation age as seconds since oldest reading
        let allReadings = [g, sys, dia, h, hv, ox, st, inact, sl, fl, cal, cb, pr, ft, wt]
            .compactMap { $0 }
        let oldestTimestamp = allReadings.map(\.timestamp).min() ?? Date()
        let age = max(0, Date().timeIntervalSince(oldestTimestamp))

        // Derive glucose trend from the stored reading
        let glucoseTrend = g?.trendDirection

        // Data quality heuristic: more metrics = higher quality
        let dataQuality: DataQuality
        switch allReadings.count {
        case 12...:  dataQuality = .excellent
        case 8..<12: dataQuality = .good
        case 5..<8:  dataQuality = .fair
        case 1..<5:  dataQuality = .poor
        default:     dataQuality = .insufficient
        }

        return MonitoringSnapshot(
            glucose:                g,
            glucoseTrend:           glucoseTrend,
            bloodPressureSystolic:  sys,
            bloodPressureDiastolic: dia,
            heartRate:              h,
            heartRateVariability:   hv,
            spo2:                   ox,
            steps:                  st,
            inactivityDuration:     inact,
            sleep:                  sl,
            fluidIntake:            fl,
            calories:               cal,
            carbs:                  cb,
            protein:                pr,
            fat:                    ft,
            weight:                 wt,
            dataQuality:            dataQuality,
            timestamp:              Date(),
            evaluationAge:          age
        )
    }

    // -------------------------------------------------------------------------
    // MARK: GraphStoreProtocol — Reading writes
    // -------------------------------------------------------------------------

    public func writeReading(_ reading: Reading) async throws {
        try await dbQueue.write { db in
            let row = ReadingRow(from: reading)
            try row.insert(db, onConflict: .replace)
        }
    }

    public func writeReadings(_ readings: [Reading]) async throws {
        try await dbQueue.write { db in
            for reading in readings {
                let row = ReadingRow(from: reading)
                try row.insert(db, onConflict: .replace)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: GraphStoreProtocol — Episode queries
    // -------------------------------------------------------------------------

    public func getEpisodes(
        from startDate: Date,
        to endDate: Date,
        types: [EpisodeType]
    ) async throws -> [Episode] {
        try await dbQueue.read { db in
            var query = EpisodeRow
                .filter(Column("reference_time") >= startDate)
                .filter(Column("reference_time") <= endDate)

            if !types.isEmpty {
                let typeStrings = types.map(\.rawValue)
                query = query.filter(typeStrings.contains(Column("episode_type")))
            }

            let rows = try query
                .order(Column("reference_time").desc)
                .fetchAll(db)
            return rows.compactMap { $0.toEpisode() }
        }
    }

    public func writeEpisode(_ episode: Episode) async throws {
        try await dbQueue.write { db in
            let row = EpisodeRow(from: episode)
            try row.insert(db, onConflict: .replace)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: GraphStoreProtocol — Retention
    // -------------------------------------------------------------------------

    public func purgeReadings(for metricType: MetricType, olderThan date: Date) async throws {
        _ = try await dbQueue.write { db in
            try ReadingRow
                .filter(Column("metric_type") == metricType.rawValue)
                .filter(Column("timestamp") < date)
                .deleteAll(db)
        }
    }
}
