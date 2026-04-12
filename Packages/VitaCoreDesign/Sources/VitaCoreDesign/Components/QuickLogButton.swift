// QuickLogButton.swift
// VitaCoreDesign — Single quick-log action button

import SwiftUI

// MARK: - QuickLogButton

/// A 44 × 44 pt minimum tap-target button with an SF Symbol icon above a
/// text label, used in the quick-log row on the dashboard.
public struct QuickLogButton: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let icon: String        // SF Symbol name
    public let label: String
    public let color: Color
    public let action: () -> Void

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        icon: String,
        label: String,
        color: Color = VCColors.primary,
        action: @escaping () -> Void
    ) {
        self.icon   = icon
        self.label  = label
        self.color  = color
        self.action = action
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var isPressed: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        Button(action: action) {
            VStack(spacing: VCSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: VCSpacing.tapTarget, height: VCSpacing.tapTarget)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                    )

                Text(label)
                    .vcFont(.caption)
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(QuickLogButtonStyle())
        // Ensure the entire area — including any gap between icon and label — is tappable.
        .contentShape(Rectangle())
    }
}

// MARK: - QuickLogButtonStyle

private struct QuickLogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(VCAnimation.cardPress, value: configuration.isPressed)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("QuickLogButton") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        HStack(spacing: VCSpacing.xl) {
            QuickLogButton(icon: "fork.knife", label: "Meal", color: VCColors.secondary) {}
            QuickLogButton(icon: "drop.fill", label: "Glucose", color: VCColors.safe) {}
            QuickLogButton(icon: "figure.walk", label: "Activity", color: VCColors.tertiary) {}
            QuickLogButton(icon: "pill.fill", label: "Medication", color: VCColors.primary) {}
        }
        .padding()
    }
}
#endif
