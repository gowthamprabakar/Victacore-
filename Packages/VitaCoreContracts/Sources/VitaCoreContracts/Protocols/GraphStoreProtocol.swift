import Foundation

// MARK: - AggregatedMetric

/// A pre-computed aggregate over a metric's readings across a time window.
public struct AggregatedMetric: Codable, Sendable, Hashable {
    public let metricType: MetricType
    public let min: Double
    public let max: Double
    public let average: Double
    public let count: Int
    public let windowStart: Date
    public let windowEnd: Date

    public init(
        metricType: MetricType,
        min: Double,
        max: Double,
        average: Double,
        count: Int,
        windowStart: Date,
        windowEnd: Date
    ) {
        self.metricType = metricType
        self.min = min
        self.max = max
        self.average = average
        self.count = count
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }
}

// MARK: - GraphStoreProtocol

/// Abstraction over the Kuzu graph store for health data access.
public protocol GraphStoreProtocol: Sendable {

    /// Returns the most recent reading for the given metric, or nil if none exists.
    func getLatestReading(for metricType: MetricType) async throws -> Reading?

    /// Returns readings for a metric within a date range.
    func getRangeReadings(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Reading]

    /// Returns a pre-computed aggregate for a metric over a window.
    func getAggregatedMetric(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> AggregatedMetric?

    /// Returns the full monitoring snapshot (current values for all metrics).
    func getCurrentSnapshot() async throws -> MonitoringSnapshot

    /// Writes a single reading into the graph.
    func writeReading(_ reading: Reading) async throws

    /// Writes multiple readings in a batch.
    func writeReadings(_ readings: [Reading]) async throws

    /// Returns episodes in a date range, optionally filtered by type.
    func getEpisodes(
        from startDate: Date,
        to endDate: Date,
        types: [EpisodeType]
    ) async throws -> [Episode]

    /// Writes a single episode into the graph.
    func writeEpisode(_ episode: Episode) async throws

    /// Deletes readings older than the given date for a metric.
    func purgeReadings(for metricType: MetricType, olderThan date: Date) async throws
}
