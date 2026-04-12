import Foundation

/// The context window that MiroFish / MetabolismAgent ingests per inference cycle.
/// This is a frozen interface contract — changes require a version bump.
public struct InferenceRequest: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    /// User-specific personalisation layer.
    public let persona: PersonaContext
    /// Current metric readings.
    public let snapshot: MonitoringSnapshot
    /// User-defined safety bands (may override global defaults).
    public let thresholdSet: ThresholdSet
    /// Recent episodes used as few-shot context.
    public let recentEpisodes: [Episode]
    /// ISO-8601 timestamp at which this request was assembled.
    public let requestedAt: Date
    /// Maximum age of a reading (seconds) before it is considered stale for inference.
    public let stalenessThreshold: TimeInterval
    /// Optional free-text instruction injected by the conversation layer.
    public let conversationalOverride: String?
    /// Model temperature hint [0.0, 1.0] — higher = more exploratory.
    public let temperatureHint: Float

    public init(
        id: UUID = UUID(),
        persona: PersonaContext,
        snapshot: MonitoringSnapshot,
        thresholdSet: ThresholdSet,
        recentEpisodes: [Episode] = [],
        requestedAt: Date = Date(),
        stalenessThreshold: TimeInterval = 3600,
        conversationalOverride: String? = nil,
        temperatureHint: Float = 0.3
    ) {
        self.id = id
        self.persona = persona
        self.snapshot = snapshot
        self.thresholdSet = thresholdSet
        self.recentEpisodes = recentEpisodes
        self.requestedAt = requestedAt
        self.stalenessThreshold = stalenessThreshold
        self.conversationalOverride = conversationalOverride
        self.temperatureHint = temperatureHint
    }
}
