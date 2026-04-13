// MetricTooltip.swift
// VitaCore — Sprint 4 O-03: First-time metric education overlay.
//
// Shows a brief "What does this mean?" tooltip the first time a user
// sees a metric card. Uses @AppStorage to track dismissed state so
// tooltips only show once per metric per device lifetime.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - MetricTooltipModifier

struct MetricTooltipModifier: ViewModifier {

    let metric: MetricType
    let explanation: String

    @AppStorage private var hasDismissed: Bool
    @State private var showTooltip = false

    init(metric: MetricType, explanation: String) {
        self.metric = metric
        self.explanation = explanation
        self._hasDismissed = AppStorage(wrappedValue: false, "tooltip_dismissed_\(metric.rawValue)")
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showTooltip {
                    tooltipBubble
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear {
                if !hasDismissed {
                    withAnimation(VCAnimation.cardEntrance.delay(1.5)) {
                        showTooltip = true
                    }
                    // Auto-dismiss after 8 seconds.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 9.5) {
                        dismissTooltip()
                    }
                }
            }
    }

    private var tooltipBubble: some View {
        VStack(alignment: .leading, spacing: VCSpacing.xs) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(VCColors.primary)
                    .font(.subheadline)
                Text("What does this mean?")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(VCColors.onSurface)
                Spacer()
                Button { dismissTooltip() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VCColors.outline)
                        .font(.caption)
                }
            }
            Text(explanation)
                .font(.caption2)
                .foregroundStyle(VCColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VCSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
        .shadow(color: VCColors.shadowAmbient, radius: 8, y: 4)
        .padding(.horizontal, VCSpacing.sm)
        .padding(.top, VCSpacing.xs)
    }

    private func dismissTooltip() {
        withAnimation(VCAnimation.cardEntrance) {
            showTooltip = false
            hasDismissed = true
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a first-time education tooltip for a health metric.
    func metricTooltip(_ metric: MetricType, explanation: String) -> some View {
        modifier(MetricTooltipModifier(metric: metric, explanation: explanation))
    }
}

// MARK: - Tooltip Explanations

enum MetricExplanations {
    static let glucose = "Blood glucose measures the sugar level in your blood. Your safe range is personalised based on your health profile."
    static let bloodPressure = "Blood pressure shows the force of blood against artery walls. Two numbers: systolic (pumping) / diastolic (resting)."
    static let heartRate = "Heart rate is how many times your heart beats per minute at rest. Lower resting HR generally indicates better fitness."
    static let steps = "Daily steps track your overall activity level. Walking after meals can help lower glucose by 15-25 mg/dL."
    static let sleep = "Sleep hours and quality directly impact insulin sensitivity. Poor sleep can raise glucose by 20-30%."
    static let timeInRange = "Time in Range (TIR) is the percentage of time your glucose stays within your safe band. Higher is better."
}
