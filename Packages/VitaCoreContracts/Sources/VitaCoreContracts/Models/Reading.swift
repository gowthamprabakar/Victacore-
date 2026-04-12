import Foundation

/// The direction a metric is trending over a recent window.
public enum TrendDirection: String, Codable, Sendable, Hashable, CaseIterable {
    case rising
    case stable
    case falling
    case risingFast
    case fallingFast

    public var displayName: String {
        switch self {
        case .rising:      return "Rising"
        case .stable:      return "Stable"
        case .falling:     return "Falling"
        case .risingFast:  return "Rising Fast"
        case .fallingFast: return "Falling Fast"
        }
    }

    /// Returns `true` when the direction indicates elevation from baseline.
    public var isElevating: Bool {
        self == .rising || self == .risingFast
    }

    /// Returns `true` when the direction indicates a decline.
    public var isDeclining: Bool {
        self == .falling || self == .fallingFast
    }
}

/// A single scalar health measurement for a given metric at a point in time.
public struct Reading: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricType: MetricType
    public let value: Double
    public let unit: String
    public let timestamp: Date
    /// The skill (data source) that produced this reading.
    public let sourceSkillId: String
    /// Source confidence in [0, 1].
    public let confidence: Float
    public let trendDirection: TrendDirection
    /// Rate of change per minute (nil when trend is indeterminate).
    public let trendVelocity: Double?

    public init(
        id: UUID = UUID(),
        metricType: MetricType,
        value: Double,
        unit: String,
        timestamp: Date,
        sourceSkillId: String,
        confidence: Float,
        trendDirection: TrendDirection = .stable,
        trendVelocity: Double? = nil
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.sourceSkillId = sourceSkillId
        self.confidence = confidence
        self.trendDirection = trendDirection
        self.trendVelocity = trendVelocity
    }
}
