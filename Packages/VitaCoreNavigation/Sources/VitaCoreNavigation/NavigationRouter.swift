import SwiftUI
import Observation

// MARK: - Supporting Data Types

/// Data passed to the food review sheet.
public struct FoodReviewData: Identifiable, Hashable {
    public let id: UUID
    public let description: String
    public let imageData: Data?

    public init(id: UUID = UUID(), description: String, imageData: Data? = nil) {
        self.id = id
        self.description = description
        self.imageData = imageData
    }
}

/// Data passed to the critical alert full-screen cover.
public struct CriticalAlertData: Identifiable, Hashable {
    public let id: UUID
    public let alertId: UUID
    public let title: String
    public let body: String
    public let metricValue: Double?
    public let metricUnit: String?
    public let triggeredAt: Date

    public init(
        id: UUID = UUID(),
        alertId: UUID,
        title: String,
        body: String,
        metricValue: Double? = nil,
        metricUnit: String? = nil,
        triggeredAt: Date = Date()
    ) {
        self.id = id
        self.alertId = alertId
        self.title = title
        self.body = body
        self.metricValue = metricValue
        self.metricUnit = metricUnit
        self.triggeredAt = triggeredAt
    }
}

// MARK: - AppDestination

/// All push-navigation destinations in the app.
public enum AppDestination: Hashable {
    // Dashboard details
    case glucoseDetail
    case bpDetail
    case hrDetail
    case stepsDetail
    case sleepDetail
    case goalDetail

    // Monitoring
    case monitoringDetail

    // Profile
    case userProfile

    // Settings
    case settingsConditions
    case settingsGoals
    case settingsMedications
    case settingsAllergies
    case settingsConnections
    case settingsNotifications
    case settingsPrivacy
    case settingsBackup
    case settingsExport
    case settingsAbout
}

// MARK: - SheetDestination

/// All sheet presentations in the app.
public enum SheetDestination: Identifiable {
    case foodEntry
    case fluidEntry
    case glucoseEntry
    case bpEntry
    case weightEntry
    case noteEntry
    case foodReview(FoodReviewData)
    case allergenWarning
    case medicationInteraction

    public var id: String {
        switch self {
        case .foodEntry:              return "foodEntry"
        case .fluidEntry:             return "fluidEntry"
        case .glucoseEntry:           return "glucoseEntry"
        case .bpEntry:                return "bpEntry"
        case .weightEntry:            return "weightEntry"
        case .noteEntry:              return "noteEntry"
        case .foodReview(let data):   return "foodReview-\(data.id)"
        case .allergenWarning:        return "allergenWarning"
        case .medicationInteraction:  return "medicationInteraction"
        }
    }
}

// MARK: - FullScreenDestination

/// All full-screen cover presentations in the app.
public enum FullScreenDestination: Identifiable {
    case criticalAlert(CriticalAlertData)
    case onboarding

    public var id: String {
        switch self {
        case .criticalAlert(let data): return "criticalAlert-\(data.id)"
        case .onboarding:              return "onboarding"
        }
    }
}

// MARK: - NavigationRouter

/// Observable navigation state for all five tab stacks plus sheet / full-screen overlays.
@Observable
public final class NavigationRouter {

    public var homePath      = NavigationPath()
    public var chatPath      = NavigationPath()
    public var logPath       = NavigationPath()
    public var alertsPath    = NavigationPath()
    public var settingsPath  = NavigationPath()

    public var presentedSheet: SheetDestination?
    public var presentedFullScreen: FullScreenDestination?

    public init() {}

    // MARK: - Navigation helpers

    /// Pushes a destination onto the correct tab stack based on context.
    /// Defaults to pushing onto the home path if no tab-specific mapping is needed.
    public func navigate(to destination: AppDestination) {
        switch destination {
        case .settingsConditions, .settingsGoals, .settingsMedications,
             .settingsAllergies, .settingsConnections, .settingsNotifications,
             .settingsPrivacy, .settingsBackup, .settingsExport, .settingsAbout:
            settingsPath.append(destination)
        case .userProfile:
            settingsPath.append(destination)
        default:
            homePath.append(destination)
        }
    }

    /// Presents a sheet.
    public func presentSheet(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }

    /// Dismisses the currently presented sheet.
    public func dismissSheet() {
        presentedSheet = nil
    }

    /// Presents a full-screen cover.
    public func presentFullScreen(_ destination: FullScreenDestination) {
        presentedFullScreen = destination
    }

    /// Dismisses the full-screen cover.
    public func dismissFullScreen() {
        presentedFullScreen = nil
    }

    /// Pops all views in the home stack back to root.
    public func popToRootHome() {
        homePath = NavigationPath()
    }
}
