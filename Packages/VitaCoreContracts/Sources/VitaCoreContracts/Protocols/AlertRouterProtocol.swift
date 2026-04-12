import Foundation

// MARK: - AlertRouterProtocol

/// Abstraction over the three-tier alert routing system.
/// Alert models are defined in Models/AlertEvent.swift (AlertEvent, AlertBand, AlertFilter).
public protocol AlertRouterProtocol: Sendable {

    /// Returns the full alert history for the past N days.
    func getAlertHistory(days: Int) async throws -> [AlertEvent]

    /// Returns the most recent N alerts.
    func getRecentAlerts(limit: Int) async throws -> [AlertEvent]

    /// Marks an alert as acknowledged.
    func acknowledgeAlert(id: UUID) async throws

    /// Routes an alert through the appropriate presentation tier.
    func route(_ payload: AlertDeliveryPayload) async

    /// Returns the count of unacknowledged alerts at or above the given urgency band.
    func unacknowledgedCount(minimumUrgency: AlertBand) async -> Int

    /// Clears all alerts older than the given number of days.
    func purgeAlerts(olderThan days: Int) async throws
}
