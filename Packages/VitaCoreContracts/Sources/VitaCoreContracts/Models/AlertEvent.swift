import Foundation

// MARK: - AlertBand

/// Urgency classification for an alert, aligned with ThresholdBand severity.
public enum AlertBand: String, Codable, Sendable, Hashable, CaseIterable {
    case info
    case watch
    case alert
    case critical

    public var priority: Int {
        switch self {
        case .info:     return 0
        case .watch:    return 1
        case .alert:    return 2
        case .critical: return 3
        }
    }

    public var requiresImmediateAttention: Bool {
        self == .alert || self == .critical
    }
}

// MARK: - UserAlertAction

/// The action a user took in response to an alert.
public enum UserAlertAction: String, Codable, Sendable, Hashable, CaseIterable {
    case acknowledged
    case dismissed
    case snoozed
    case escalatedToClinician
    case calledEmergency
    case ignored
}

// MARK: - AlertEvent

/// A triggered alert for an out-of-range health metric.
public struct AlertEvent: Identifiable, Codable, Sendable, Hashable {
    public let alertId: UUID
    public var id: UUID { alertId }
    public let urgency: AlertBand
    public let metricType: MetricType
    public let value: Double
    public let trendDirection: TrendDirection
    /// Natural-language explanation of why this alert was raised.
    public let explanation: String
    /// Specific data points or thresholds that triggered the alert.
    public let evidence: [String]
    public let timestamp: Date
    public var acknowledgedAt: Date?
    public var userAction: UserAlertAction?

    public init(
        alertId: UUID = UUID(),
        urgency: AlertBand,
        metricType: MetricType,
        value: Double,
        trendDirection: TrendDirection,
        explanation: String,
        evidence: [String] = [],
        timestamp: Date = Date(),
        acknowledgedAt: Date? = nil,
        userAction: UserAlertAction? = nil
    ) {
        self.alertId = alertId
        self.urgency = urgency
        self.metricType = metricType
        self.value = value
        self.trendDirection = trendDirection
        self.explanation = explanation
        self.evidence = evidence
        self.timestamp = timestamp
        self.acknowledgedAt = acknowledgedAt
        self.userAction = userAction
    }

    public var isAcknowledged: Bool { acknowledgedAt != nil }
}

// MARK: - AlertFilter

/// Predicate struct for filtering stored alerts.
public struct AlertFilter: Codable, Sendable, Hashable {
    public let urgencyFilter: Set<AlertBand>?
    public let metricFilter: Set<MetricType>?
    public let dateRange: ClosedRange<Date>?

    public init(
        urgencyFilter: Set<AlertBand>? = nil,
        metricFilter: Set<MetricType>? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) {
        self.urgencyFilter = urgencyFilter
        self.metricFilter = metricFilter
        self.dateRange = dateRange
    }

    public func matches(_ event: AlertEvent) -> Bool {
        if let uf = urgencyFilter, !uf.contains(event.urgency) { return false }
        if let mf = metricFilter, !mf.contains(event.metricType) { return false }
        if let dr = dateRange, !dr.contains(event.timestamp) { return false }
        return true
    }
}

// MARK: - AlertDeliveryPayload

/// Payload passed to the AlertRouter for in-app overlay delivery.
public struct AlertDeliveryPayload: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let event: AlertEvent
    /// Suggested deep-link route within the app.
    public let deepLinkRoute: String?
    /// Whether the overlay should auto-dismiss.
    public let autoDismiss: Bool
    /// Seconds after which the overlay auto-dismisses (ignored when `autoDismiss == false`).
    public let autoDismissDelay: TimeInterval

    public init(
        id: UUID = UUID(),
        event: AlertEvent,
        deepLinkRoute: String? = nil,
        autoDismiss: Bool = false,
        autoDismissDelay: TimeInterval = 5
    ) {
        self.id = id
        self.event = event
        self.deepLinkRoute = deepLinkRoute
        self.autoDismiss = autoDismiss
        self.autoDismissDelay = autoDismissDelay
    }
}
