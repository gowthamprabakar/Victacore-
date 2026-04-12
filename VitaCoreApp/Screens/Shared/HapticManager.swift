// HapticManager.swift
// VitaCoreApp — Unified haptic feedback API.
//
// Use `HapticFeedback.success.trigger()` for one-off calls or
// attach `.hapticFeedback(.selection, trigger: someValue)` to any View
// to fire feedback whenever the trigger value changes.

import SwiftUI
import UIKit

public enum HapticFeedback {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection

    public func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

public extension View {
    /// Triggers haptic feedback whenever `trigger` changes.
    func hapticFeedback(_ style: HapticFeedback, trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            style.trigger()
        }
    }
}
