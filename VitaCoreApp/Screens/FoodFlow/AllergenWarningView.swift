// AllergenWarningView.swift
// VitaCore — Food Flow Stage 5: Allergen Warning Barrier
//
// FULL-SCREEN SAFETY BARRIER. Solid-colour background, no glass, no mesh.
// Heavy haptic on appear. Pulsing icon animation.

import SwiftUI
import UIKit
import VitaCoreDesign
import VitaCoreContracts

// MARK: - AllergenWarningView

struct AllergenWarningView: View {

    // MARK: Props
    let warning: AllergenWarning
    let onAcknowledge: () -> Void  // "I Understand the Risk" (non-severe only)
    let onDiscard: () -> Void       // "Discard This Food"

    // MARK: State
    @State private var pulseScale: CGFloat = 1.0

    // MARK: Computed helpers

    var backgroundColor: Color {
        switch warning.severity {
        case .anaphylactic, .severe:
            return VCColors.critical
        case .moderate:
            return VCColors.alertOrange
        case .mild:
            return VCColors.watch
        }
    }

    var severityLabel: String {
        switch warning.severity {
        case .anaphylactic: return "ANAPHYLACTIC RISK"
        case .severe:       return "SEVERE RISK"
        case .moderate:     return "MODERATE RISK"
        case .mild:         return "MILD RISK"
        }
    }

    /// High-risk: anaphylactic or severe — no "I Understand" option, show 911 instead.
    var isHighRisk: Bool {
        warning.severity == .anaphylactic || warning.severity == .severe
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // SOLID full-screen background — no glass, no blur, no mesh
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: VCSpacing.xl) {
                Spacer()

                // ── Warning icon (pulsing) ───────────────────────────────────
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .shadow(color: .white.opacity(0.5), radius: 24)
                    .accessibilityLabel(Text("Warning: allergen detected"))

                // ── Title ────────────────────────────────────────────────────
                Text("ALLERGEN DETECTED")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(1.5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                // ── Severity capsule ─────────────────────────────────────────
                Text(severityLabel)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, VCSpacing.lg)
                    .padding(.vertical, VCSpacing.xs)
                    .background(
                        Capsule()
                            .stroke(.white.opacity(0.5), lineWidth: 1.5)
                    )

                // ── Allergen name ─────────────────────────────────────────────
                Text(warning.allergen)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.top, VCSpacing.md)

                // ── Details card ─────────────────────────────────────────────
                detailsCard
                    .padding(.horizontal, VCSpacing.xxl)

                Spacer()

                // ── Action buttons ───────────────────────────────────────────
                actionButtons
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.xxl)
            }
        }
        .onAppear {
            triggerHaptic()
            startPulse()
        }
    }

    // MARK: Sub-views

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: VCSpacing.md) {
            detailRow(label: "DETECTED IN", value: warning.detectedInItem)

            Divider()
                .background(.white.opacity(0.3))

            detailRow(label: "MATCH REASON", value: warning.matchReason)

            Text("This analysis uses your allergen profile. Always verify critical allergens with packaging.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, VCSpacing.xs)
        }
        .padding(VCSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.xl)
                .fill(.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.xl)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var actionButtons: some View {
        VStack(spacing: VCSpacing.md) {
            // Primary: Discard (white fill, colored text)
            Button(action: onDiscard) {
                Text("Discard This Food")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(backgroundColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.white)
                    )
            }
            .accessibilityHint(Text("Removes this food from your log"))

            if isHighRisk {
                // Anaphylactic / Severe: show emergency Call 911
                Button {
                    if let url = URL(string: "tel://911") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: VCSpacing.sm) {
                        Image(systemName: "phone.badge.waveform.fill")
                        Text("Call 911")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white, lineWidth: 2)
                    )
                }
                .accessibilityHint(Text("Opens phone dialer to call emergency services"))
            } else {
                // Moderate / Mild: allow user to acknowledge and continue
                Button(action: onAcknowledge) {
                    Text("I Understand the Risk")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(.white, lineWidth: 2)
                        )
                }
                .accessibilityHint(Text("Acknowledges the allergen warning and continues logging"))
            }
        }
    }

    // MARK: Helpers

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.08
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Anaphylactic") {
    AllergenWarningView(
        warning: AllergenWarning(
            allergen: "Peanut",
            severity: .anaphylactic,
            detectedInItem: "Pad Thai Noodles",
            matchReason: "Peanut sauce identified in meal composition"
        ),
        onAcknowledge: {},
        onDiscard: {}
    )
}

#Preview("Moderate") {
    AllergenWarningView(
        warning: AllergenWarning(
            allergen: "Tree Nuts",
            severity: .moderate,
            detectedInItem: "Caesar Salad",
            matchReason: "Almond slivers detected in toppings"
        ),
        onAcknowledge: {},
        onDiscard: {}
    )
}

#Preview("Mild") {
    AllergenWarningView(
        warning: AllergenWarning(
            allergen: "Shellfish",
            severity: .mild,
            detectedInItem: "Fried Rice",
            matchReason: "Shrimp fragments detected in rice dish"
        ),
        onAcknowledge: {},
        onDiscard: {}
    )
}
#endif
