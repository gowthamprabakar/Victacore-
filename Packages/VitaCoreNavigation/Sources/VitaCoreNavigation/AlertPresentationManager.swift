import SwiftUI
import Observation

// MARK: - AlertSheetData

/// Data for an ALERT-level bottom sheet presentation.
public struct AlertSheetData: Identifiable, Hashable {
    public let id: UUID
    public let alertId: UUID
    public let title: String
    public let body: String
    public let metricValue: Double?
    public let metricUnit: String?
    public let triggeredAt: Date
    public let deepLinkRoute: String?

    public init(
        id: UUID = UUID(),
        alertId: UUID,
        title: String,
        body: String,
        metricValue: Double? = nil,
        metricUnit: String? = nil,
        triggeredAt: Date = Date(),
        deepLinkRoute: String? = nil
    ) {
        self.id = id
        self.alertId = alertId
        self.title = title
        self.body = body
        self.metricValue = metricValue
        self.metricUnit = metricUnit
        self.triggeredAt = triggeredAt
        self.deepLinkRoute = deepLinkRoute
    }
}

// MARK: - WatchBannerData

/// Data for a WATCH-level top-banner presentation.
public struct WatchBannerData: Identifiable, Hashable {
    public let id: UUID
    public let alertId: UUID
    public let title: String
    public let subtitle: String?
    public let iconName: String
    /// Seconds before the banner auto-dismisses (0 = no auto-dismiss).
    public let autoDismissSeconds: TimeInterval

    public init(
        id: UUID = UUID(),
        alertId: UUID,
        title: String,
        subtitle: String? = nil,
        iconName: String = "exclamationmark.triangle.fill",
        autoDismissSeconds: TimeInterval = 5
    ) {
        self.id = id
        self.alertId = alertId
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.autoDismissSeconds = autoDismissSeconds
    }
}

// MARK: - AlertPresentationManager

/// Observable three-tier alert presentation state.
///
/// Tier hierarchy:
/// - CRITICAL: Full-screen cover (CriticalAlertData)
/// - ALERT:    Bottom sheet (AlertSheetData)
/// - WATCH:    Top banner (WatchBannerData)
@Observable
public final class AlertPresentationManager {

    public var activeCriticalAlert: CriticalAlertData?
    public var activeAlertSheet: AlertSheetData?
    public var activeWatchBanner: WatchBannerData?

    public init() {}

    // MARK: - Present

    /// Presents a CRITICAL full-screen alert. Replaces any existing critical alert.
    public func presentCritical(_ data: CriticalAlertData) {
        activeCriticalAlert = data
    }

    /// Presents an ALERT-level bottom sheet. Replaces any existing alert sheet.
    public func presentAlert(_ data: AlertSheetData) {
        activeAlertSheet = data
    }

    /// Presents a WATCH-level top banner. Replaces any existing banner.
    public func presentWatch(_ data: WatchBannerData) {
        activeWatchBanner = data
        // Auto-dismiss if configured
        if data.autoDismissSeconds > 0 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(data.autoDismissSeconds * 1_000_000_000))
                // Only dismiss if it's still the same banner
                if activeWatchBanner?.id == data.id {
                    dismissWatch()
                }
            }
        }
    }

    // MARK: - Dismiss

    /// Dismisses the WATCH banner.
    public func dismissWatch() {
        activeWatchBanner = nil
    }

    /// Dismisses the CRITICAL full-screen alert.
    public func acknowledgeCritical() {
        activeCriticalAlert = nil
    }

    /// Dismisses the ALERT bottom sheet.
    public func acknowledgeAlert() {
        activeAlertSheet = nil
    }
}
