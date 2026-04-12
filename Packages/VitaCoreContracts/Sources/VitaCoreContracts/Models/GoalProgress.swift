import Foundation

// MARK: - GoalTrend

public enum GoalTrend: String, Codable, Sendable, Hashable, CaseIterable {
    case improving
    case stable
    case worsening
}

// MARK: - GoalProgress

/// Tracks a user's progress toward a single health goal.
public struct GoalProgress: Identifiable, Codable, Sendable, Hashable {
    public var id: GoalType { goalType }
    public let goalType: GoalType
    public let target: Double
    public let current: Double
    /// Percentage complete in [0, 1], clamped.
    public let percentage: Double
    public let trend: GoalTrend
    /// Consecutive days the user has been progressing toward this goal.
    public let streakDays: Int
    public let updatedAt: Date

    public init(
        goalType: GoalType,
        target: Double,
        current: Double,
        trend: GoalTrend = .stable,
        streakDays: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.goalType = goalType
        self.target = target
        self.current = current
        self.percentage = target == 0 ? 0 : min(1.0, max(0.0, current / target))
        self.trend = trend
        self.streakDays = streakDays
        self.updatedAt = updatedAt
    }

    public var isAchieved: Bool { percentage >= 1.0 }
}
