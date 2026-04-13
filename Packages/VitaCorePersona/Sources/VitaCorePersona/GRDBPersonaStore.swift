// GRDBPersonaStore.swift
// VitaCorePersona — Persistence layer for PersonaContext.
//
// Owns its own SQLite file (`vitacore_persona.sqlite`) so persona state
// is decoupled from the graph store's `vitacore.sqlite`. This keeps the
// C01 component independently testable and independently purgeable.

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - GRDBPersonaStore

public actor GRDBPersonaStore {

    private let writer: any DatabaseWriter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Apply pending migrations so callers see a fully-initialised store.
        try PersonaMigrator.migrator.migrate(writer)
    }

    // -------------------------------------------------------------------------
    // MARK: Factories
    // -------------------------------------------------------------------------

    /// File-backed store in the app's Application Support directory.
    /// Creates the directory + file if they don't exist. Safe to call
    /// multiple times; subsequent calls reuse the existing file.
    public static func defaultStore() throws -> GRDBPersonaStore {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("VitaCore", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let file = dir.appendingPathComponent("vitacore_persona.sqlite")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: file.path, configuration: config)

        // T039 / FR-020: apply iOS file-protection class so persona PHI
        // (conditions, medications, allergies) is unavailable while the
        // device is locked. Matches VitaCoreGraph's protection level.
        let fm2 = FileManager.default
        let protectionAttrs: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUnlessOpen
        ]
        for ext in ["", "-wal", "-shm"] {
            let path = file.path + ext
            if fm2.fileExists(atPath: path) {
                try? fm2.setAttributes(protectionAttrs, ofItemAtPath: path)
            }
        }

        return try GRDBPersonaStore(writer: pool)
    }

    /// In-memory store for tests. Uses `DatabaseQueue` because SQLite's
    /// in-memory databases don't support WAL journal mode (required by
    /// `DatabasePool`).
    public static func inMemory() throws -> GRDBPersonaStore {
        let queue = try DatabaseQueue()
        return try GRDBPersonaStore(writer: queue)
    }

    // -------------------------------------------------------------------------
    // MARK: Read
    // -------------------------------------------------------------------------

    /// Returns the stored `PersonaContext`, or `nil` if no row exists
    /// for any user yet (pre-onboarding / fresh install).
    ///
    /// T035 / FR-019: if the stored blob fails to decode (schema drift
    /// after an app update added a non-optional field), we log the
    /// error, delete the corrupt row, and return `nil` so the caller
    /// re-bootstraps. This prevents the app from bricking on upgrade.
    public func loadContext() async throws -> PersonaContext? {
        let decoder = self.decoder
        let row: PersonaContextRow? = try await writer.read { db in
            try PersonaContextRow.fetchOne(db)
        }
        guard let row else { return nil }
        do {
            return try decoder.decode(PersonaContext.self, from: row.blob)
        } catch {
            // T035: schema drift — blob shape doesn't match current
            // PersonaContext. Log, delete, and let the caller re-bootstrap.
            print("⚠️ VitaCorePersona: blob decode failed (\(error)) — deleting corrupt row and re-bootstrapping")
            try await deleteAll()
            return nil
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Write
    // -------------------------------------------------------------------------

    /// Persists the given context, upserting on `user_id`. Updates the
    /// `updated_at` timestamp to `Date()`.
    public func saveContext(_ context: PersonaContext) async throws {
        let blob = try encoder.encode(context)
        let row = PersonaContextRow(
            userId: context.userId.uuidString,
            blob: blob,
            updatedAt: Date()
        )
        try await writer.write { db in
            try row.save(db)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Bootstrap (T031 — actor-isolated, race-free)
    // -------------------------------------------------------------------------

    /// Atomically loads or bootstraps the persona context. Because this
    /// runs inside the actor, concurrent callers are serialised — the
    /// first call that finds an empty store runs the inferencer and
    /// saves; the second call sees the saved row and returns it.
    ///
    /// Returns the context (either stored or freshly inferred). If the
    /// inferencer returns `.provisional` (data-adequacy gate not met),
    /// the context is NOT persisted and subsequent calls will re-run
    /// the inferencer, allowing HealthKit back-fill to arrive.
    public func bootstrapIfNeeded(
        inferencer: PersonaInferencer,
        graphStore: GraphStoreProtocol
    ) async throws -> PersonaContext {
        // 1. Check for existing row first.
        if let existing = try await loadContext() {
            return existing
        }
        // 2. Infer from graph data.
        let decision = try await inferencer.inferContext(from: graphStore)
        // 3. Only persist when confident (T030 data-adequacy gate).
        if decision.shouldPersist {
            try await saveContext(decision.context)
        }
        return decision.context
    }

    // -------------------------------------------------------------------------
    // MARK: Mutate (T032 — atomic read-modify-write)
    // -------------------------------------------------------------------------

    /// Atomically reads the current context, applies the transform, and
    /// saves. Because this runs inside the actor, concurrent mutations
    /// are serialised — no lost updates.
    ///
    /// If no context exists yet (pre-bootstrap / provisional), a
    /// transient healthy-baseline default is created, transformed, and
    /// saved — so the user can set goals/meds/allergies even before
    /// HealthKit has provided enough data for a confident bootstrap.
    public func mutate(
        _ transform: @Sendable (PersonaContext) -> PersonaContext
    ) async throws -> PersonaContext {
        // Read + transform + write in a SINGLE GRDB transaction to
        // prevent actor reentrancy from causing lost updates.
        let decoder = self.decoder
        let encoder = self.encoder
        let updated: PersonaContext = try await writer.write { db in
            let current: PersonaContext
            if let row = try PersonaContextRow.fetchOne(db),
               let ctx = try? decoder.decode(PersonaContext.self, from: row.blob) {
                current = ctx
            } else {
                current = PersonaContext(userId: UUID())
            }
            let result = transform(current)
            let blob = try encoder.encode(result)
            let row = PersonaContextRow(
                userId: result.userId.uuidString,
                blob: blob,
                updatedAt: Date()
            )
            try row.save(db)
            return result
        }
        return updated
    }

    /// Deletes every persona row. Used by the "reset app" flow and by
    /// tests that want a clean slate.
    public func deleteAll() async throws {
        _ = try await writer.write { db in
            try PersonaContextRow.deleteAll(db)
        }
    }
}

// MARK: - Errors

public enum PersonaStoreError: Error, LocalizedError, Sendable {
    case noContextToMutate

    public var errorDescription: String? {
        switch self {
        case .noContextToMutate:
            return "No persona context exists to mutate. Call bootstrapIfNeeded first."
        }
    }
}
