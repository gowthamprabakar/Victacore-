import Foundation

// MARK: - DeepLinkHandler

/// Parses `vitacore://` deep links and routes them to the correct tab and destination.
///
/// Supported schemes:
/// ```
/// vitacore://home/glucose
/// vitacore://home/bp
/// vitacore://home/hr
/// vitacore://home/steps
/// vitacore://home/sleep
/// vitacore://home/goal
/// vitacore://chat
/// vitacore://log/food
/// vitacore://log/fluid
/// vitacore://log/glucose
/// vitacore://log/bp
/// vitacore://log/weight
/// vitacore://log/note
/// vitacore://alerts
/// vitacore://settings/conditions
/// vitacore://settings/goals
/// vitacore://settings/medications
/// vitacore://settings/allergies
/// vitacore://settings/connections
/// vitacore://settings/notifications
/// vitacore://settings/privacy
/// vitacore://settings/backup
/// vitacore://settings/export
/// vitacore://settings/about
/// ```
public final class DeepLinkHandler {

    private init() {}

    /// Handles a deep-link URL and updates the tab and navigation routers accordingly.
    /// - Parameters:
    ///   - url: The deep-link URL to handle.
    ///   - tabRouter: The active ``TabRouter`` instance.
    ///   - navRouter: The active ``NavigationRouter`` instance.
    public static func handle(
        url: URL,
        tabRouter: TabRouter,
        navRouter: NavigationRouter
    ) {
        guard url.scheme == "vitacore" else { return }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "home":
            tabRouter.selectedTab = .home
            if let sub = pathComponents.first {
                switch sub {
                case "glucose":  navRouter.navigate(to: .glucoseDetail)
                case "bp":       navRouter.navigate(to: .bpDetail)
                case "hr":       navRouter.navigate(to: .hrDetail)
                case "steps":    navRouter.navigate(to: .stepsDetail)
                case "sleep":    navRouter.navigate(to: .sleepDetail)
                case "goal":     navRouter.navigate(to: .goalDetail)
                case "monitor":  navRouter.navigate(to: .monitoringDetail)
                default:         break
                }
            }

        case "chat":
            tabRouter.selectedTab = .chat

        case "log":
            tabRouter.selectedTab = .log
            if let sub = pathComponents.first {
                switch sub {
                case "food":    navRouter.presentSheet(.foodEntry)
                case "fluid":   navRouter.presentSheet(.fluidEntry)
                case "glucose": navRouter.presentSheet(.glucoseEntry)
                case "bp":      navRouter.presentSheet(.bpEntry)
                case "weight":  navRouter.presentSheet(.weightEntry)
                case "note":    navRouter.presentSheet(.noteEntry)
                default:        break
                }
            }

        case "alerts":
            tabRouter.selectedTab = .alerts

        case "settings":
            tabRouter.selectedTab = .settings
            if let sub = pathComponents.first {
                switch sub {
                case "conditions":    navRouter.navigate(to: .settingsConditions)
                case "goals":         navRouter.navigate(to: .settingsGoals)
                case "medications":   navRouter.navigate(to: .settingsMedications)
                case "allergies":     navRouter.navigate(to: .settingsAllergies)
                case "connections":   navRouter.navigate(to: .settingsConnections)
                case "notifications": navRouter.navigate(to: .settingsNotifications)
                case "privacy":       navRouter.navigate(to: .settingsPrivacy)
                case "backup":        navRouter.navigate(to: .settingsBackup)
                case "export":        navRouter.navigate(to: .settingsExport)
                case "about":         navRouter.navigate(to: .settingsAbout)
                default:              break
                }
            }

        default:
            break
        }
    }
}
