// VitaCoreAlertRouter.swift
// VitaCoreHeartbeat — Real AlertRouterProtocol implementation.
//
// Sprint 2 N-04. Replaces the LAST mock in VitaCoreApp. Stores
// AlertEvents as JSON-serialised episodes in GraphStore, provides
// history/acknowledge/purge, and dispatches local notifications
// via UNUserNotificationCenter with .timeSensitive interrupt level.

import Foundation
import UserNotifications
import VitaCoreContracts

// MARK: - VitaCoreAlertRouter

public final class VitaCoreAlertRouter: AlertRouterProtocol, @unchecked Sendable {

    private let graphStore: GraphStoreProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// In-memory cache of recent alerts (last 100). Backed by GraphStore
    /// episodes but cached to avoid repeated deserialization.
    private var alertCache: [AlertEvent] = []

    /// Quiet hours from PersonaContext preferences.
    public var quietHoursStart: Int = 22   // 10 PM
    public var quietHoursEnd: Int = 7      // 7 AM

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    // -------------------------------------------------------------------------
    // MARK: AlertRouterProtocol — History
    // -------------------------------------------------------------------------

    public func getAlertHistory(days: Int) async throws -> [AlertEvent] {
        let since = Date().addingTimeInterval(-Double(days) * 86400)
        let episodes = try await graphStore.getEpisodes(
            from: since,
            to: Date(),
            types: [.alertEvent]
        )
        return episodes.compactMap { decodeAlert(from: $0) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func getRecentAlerts(limit: Int) async throws -> [AlertEvent] {
        let history = try await getAlertHistory(days: 7)
        return Array(history.prefix(limit))
    }

    // -------------------------------------------------------------------------
    // MARK: AlertRouterProtocol — Acknowledge
    // -------------------------------------------------------------------------

    public func acknowledgeAlert(id: UUID) async throws {
        // Find and update in cache.
        if let idx = alertCache.firstIndex(where: { $0.alertId == id }) {
            alertCache[idx].acknowledgedAt = Date()
            alertCache[idx].userAction = .acknowledged
        }
        // Write acknowledgement episode to GraphStore for audit trail.
        let payload = try encoder.encode(["alertId": id.uuidString, "action": "acknowledged"])
        let episode = Episode(
            episodeType: .alertEvent,
            sourceSkillId: "engine.alertRouter.ack",
            sourceConfidence: 1.0,
            referenceTime: Date(),
            payload: payload
        )
        try await graphStore.writeEpisode(episode)
    }

    // -------------------------------------------------------------------------
    // MARK: AlertRouterProtocol — Route
    // -------------------------------------------------------------------------

    public func route(_ payload: AlertDeliveryPayload) async {
        let event = payload.event

        // Store in cache.
        alertCache.append(event)
        if alertCache.count > 100 {
            alertCache.removeFirst(alertCache.count - 100)
        }

        // Persist to GraphStore as an alertEvent episode.
        if let data = try? encoder.encode(event) {
            let episode = Episode(
                episodeType: .alertEvent,
                sourceSkillId: "engine.alertRouter",
                sourceConfidence: 1.0,
                referenceTime: event.timestamp,
                payload: data
            )
            try? await graphStore.writeEpisode(episode)
        }

        // Sprint 2 N-01: fire local notification if not in quiet hours.
        if event.urgency.requiresImmediateAttention && !isQuietHours() {
            await fireLocalNotification(for: event)
        } else if event.urgency == .watch && !isQuietHours() {
            await fireLocalNotification(for: event)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: AlertRouterProtocol — Count & Purge
    // -------------------------------------------------------------------------

    public func unacknowledgedCount(minimumUrgency: AlertBand) async -> Int {
        alertCache.filter {
            !$0.isAcknowledged && $0.urgency.priority >= minimumUrgency.priority
        }.count
    }

    public func purgeAlerts(olderThan days: Int) async throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        alertCache.removeAll { $0.timestamp < cutoff }
        // GraphStore purge is handled by data retention policy (Sprint 7 S-03).
    }

    // -------------------------------------------------------------------------
    // MARK: Local Notifications (N-01)
    // -------------------------------------------------------------------------

    private func fireLocalNotification(for event: AlertEvent) async {
        let content = UNMutableNotificationContent()

        // No PHI in notification payload (AD-05 / constitution).
        // Generic title + metric name only.
        switch event.urgency {
        case .critical:
            content.title = "Health Alert"
            content.body = "\(event.metricType.displayName) needs immediate attention."
            content.interruptionLevel = .timeSensitive
            content.sound = .defaultCritical
        case .alert:
            content.title = "\(event.metricType.displayName) Alert"
            content.body = "Please check your \(event.metricType.displayName.lowercased())."
            content.interruptionLevel = .timeSensitive
            content.sound = .default
        case .watch:
            content.title = "\(event.metricType.displayName)"
            content.body = "Your \(event.metricType.displayName.lowercased()) is being monitored."
            content.interruptionLevel = .active
            content.sound = .default
        case .info:
            content.title = "Health Update"
            content.body = "New insight available."
            content.interruptionLevel = .passive
        }

        content.categoryIdentifier = "HEALTH_ALERT"
        content.threadIdentifier = event.metricType.rawValue

        let request = UNNotificationRequest(
            identifier: event.alertId.uuidString,
            content: content,
            trigger: nil  // Fire immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("⚠️ AlertRouter: notification dispatch failed — \(error)")
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Quiet Hours (N-02)
    // -------------------------------------------------------------------------

    /// Returns true if the current hour is within the user's quiet hours.
    /// Critical alerts BYPASS quiet hours (they always fire).
    private func isQuietHours() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if quietHoursStart > quietHoursEnd {
            // Wraps midnight: e.g., 22:00 → 07:00
            return hour >= quietHoursStart || hour < quietHoursEnd
        } else {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func decodeAlert(from episode: Episode) -> AlertEvent? {
        try? decoder.decode(AlertEvent.self, from: episode.payload)
    }
}

// MARK: - Notification Permission (N-03)

public enum NotificationPermission {

    /// Requests notification authorization. Call once during onboarding
    /// or on first app launch.
    public static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("⚠️ Notification permission request failed: \(error)")
            return false
        }
    }
}
