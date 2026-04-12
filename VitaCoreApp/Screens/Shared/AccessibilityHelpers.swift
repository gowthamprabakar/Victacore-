// AccessibilityHelpers.swift
// VitaCoreApp — View modifiers for VoiceOver and accessibility support.
//
// Provides consistent accessibility labeling for health metric cards,
// live-updating metric markers, and decorative element hiding.

import SwiftUI

public extension View {
    /// Standard accessibility label + value + hint for a health metric card.
    func vitaCoreMetricAccessibility(
        name: String,
        value: String,
        unit: String,
        trend: String? = nil,
        status: String? = nil
    ) -> some View {
        var label = "\(name): \(value) \(unit)"
        if let trend { label += ", trend \(trend)" }
        if let status { label += ", status \(status)" }
        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to view detail")
    }

    /// Mark a view as updating frequently for screen readers.
    func liveMetric() -> some View {
        self.accessibilityAddTraits(.updatesFrequently)
    }

    /// Hide decorative elements from VoiceOver.
    func decorative() -> some View {
        self.accessibilityHidden(true)
    }
}
