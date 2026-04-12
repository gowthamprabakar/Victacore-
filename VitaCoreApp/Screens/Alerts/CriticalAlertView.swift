// CriticalAlertView.swift
// VitaCore — CRITICAL-level full-screen alert cover.
//
// Design intent: Solid VCColors.critical (#FF1744) background, white content.
// No glass, no background mesh. Pulsing metric value. Cannot swipe-dismiss.

import SwiftUI
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - CriticalAlertView

struct CriticalAlertView: View {

    let data: CriticalAlertData

    @Environment(AlertPresentationManager.self) private var alertManager

    // MARK: Animation state
    @State private var pulseScale: CGFloat = 1.0
    @State private var valueScale: CGFloat = 1.0
    @State private var didFireHaptic = false

    var body: some View {
        ZStack {
            // Solid critical red background — intentionally jarring
            VCColors.critical
                .ignoresSafeArea()

            // Subtle darkening vignette at edges for depth
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.20)],
                center: .center,
                startRadius: 120,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── Warning icon ──────────────────────────────────────────────
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                    .padding(.bottom, VCSpacing.xl)

                // ── "HEALTH ALERT" label ──────────────────────────────────────
                Text("HEALTH ALERT")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                    .padding(.bottom, VCSpacing.sm)

                // ── Title ─────────────────────────────────────────────────────
                Text(data.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.lg)

                // ── Metric value (pulsing) ────────────────────────────────────
                if let value = data.metricValue {
                    Group {
                        if let unit = data.metricUnit {
                            Text(metricValueString(value) + " " + unit)
                        } else {
                            Text(metricValueString(value))
                        }
                    }
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(valueScale)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: valueScale
                    )
                    .padding(.bottom, VCSpacing.md)
                }

                // ── Body text ─────────────────────────────────────────────────
                Text(data.body)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.xxl)

                Spacer()

                // ── Evidence strip ────────────────────────────────────────────
                // (No evidence field on CriticalAlertData — use body as context)

                // ── Action buttons ────────────────────────────────────────────
                VStack(spacing: VCSpacing.md) {
                    // Primary
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        alertManager.acknowledgeCritical()
                    } label: {
                        Text(data.title.lowercased().contains("glucose") ? "I've eaten — Got it" : "I understand — Got it")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(VCColors.critical)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white, in: RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Secondary
                    Button {
                        // Call emergency — present phone dialer
                        if let url = URL(string: "tel://911") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Call emergency")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, VCSpacing.xxxl)
                .padding(.bottom, 48)
            }
        }
        // Prevent swipe-dismiss
        .interactiveDismissDisabled(true)
        .onAppear {
            // Heavy haptic on appear
            if !didFireHaptic {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                didFireHaptic = true
            }
            // Start pulse animations
            pulseScale = 1.12
            valueScale = 1.06
        }
    }

    private func metricValueString(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

// MARK: - Preview

#if DEBUG
import VitaCoreNavigation

#Preview("Critical — Hypoglycemia") {
    CriticalAlertView(
        data: CriticalAlertData(
            alertId: UUID(),
            title: "Hypoglycemia Detected",
            body: "Your blood glucose is at 65 mg/dL and falling fast. Take 15g fast-acting carbohydrates immediately.",
            metricValue: 65,
            metricUnit: "mg/dL"
        )
    )
    .environment(AlertPresentationManager())
}

#Preview("Critical — Blood Pressure") {
    CriticalAlertView(
        data: CriticalAlertData(
            alertId: UUID(),
            title: "Blood Pressure Critical",
            body: "Systolic blood pressure of 185 mmHg is above your critical threshold. Sit down, rest, and seek medical attention.",
            metricValue: 185,
            metricUnit: "mmHg"
        )
    )
    .environment(AlertPresentationManager())
}
#endif
