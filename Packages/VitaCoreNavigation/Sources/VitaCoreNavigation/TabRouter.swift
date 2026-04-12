import SwiftUI
import Observation

// MARK: - VCTab

/// The five primary navigation tabs in VitaCore.
public enum VCTab: String, CaseIterable, Identifiable {
    case home
    case chat
    case log
    case alerts
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home:     return "Home"
        case .chat:     return "Chat"
        case .log:      return "Log"
        case .alerts:   return "Alerts"
        case .settings: return "Settings"
        }
    }

    /// SF Symbol name (outline variant — used in unselected state).
    public var icon: String {
        switch self {
        case .home:     return "house"
        case .chat:     return "bubble.left.and.bubble.right"
        case .log:      return "plus.circle"
        case .alerts:   return "bell"
        case .settings: return "gearshape"
        }
    }

    /// SF Symbol name (filled variant — used in selected state).
    public var activeIcon: String {
        switch self {
        case .home:     return "house.fill"
        case .chat:     return "bubble.left.and.bubble.right.fill"
        case .log:      return "plus.circle.fill"
        case .alerts:   return "bell.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - TabRouter

/// Observable tab selection state. Inject via SwiftUI environment.
@Observable
public final class TabRouter {
    public var selectedTab: VCTab = .home

    public init() {}
}
