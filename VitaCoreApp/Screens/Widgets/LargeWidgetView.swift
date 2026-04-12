// LargeWidgetView.swift
// VitaCore — Home Screen Large Widget Preview (4×4 grid size)
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Note: This is a widget PREVIEW rendered inside the main app for design
//       review. A future sprint will extract this into a WidgetExtension target.

import SwiftUI
import VitaCoreDesign

// MARK: - LargeWidgetView

/// Simulates a Home Screen large widget (340×340 pt) with a glucose hero,
/// sparkline, metric row, and goal progress bars.
struct LargeWidgetView: View {

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            glucoseHero
            sparkline
            metricRow
            progressBars
        }
        .padding(16)
        .frame(width: 340, height: 340)
        .background(widgetBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(VCColors.primary)
                Text("VitaCore")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VCColors.onSurface)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(VCColors.safe)
                    .frame(width: 6, height: 6)
                Text("All metrics OK")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
        }
    }

    // MARK: Glucose Hero

    private var glucoseHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("142")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)

            VStack(alignment: .leading, spacing: 0) {
                Text("mg/dL")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(VCColors.onSurfaceVariant)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("STABLE")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(VCColors.safe)
            }

            Spacer()

            Text("Glucose")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(VCColors.tertiary)
        }
    }

    // MARK: Sparkline

    /// Uses the existing SparklineChart component from VitaCoreDesign.
    /// Values are seeded deterministically for the preview — real widget
    /// data would be injected via a Timeline entry in the WidgetExtension.
    private var sparkline: some View {
        SparklineChart(
            values: previewSparklineValues,
            safeBandRange: 70...180,
            accentColor: VCColors.primary,
            height: 48
        )
        .frame(height: 48)
    }

    /// 24 deterministic values that trace a gentle arc for design review.
    private var previewSparklineValues: [Double] {
        let bases: [Double] = [
            138, 141, 145, 148, 144, 140, 136, 132,
            130, 134, 138, 142, 146, 148, 145, 141,
            137, 133, 130, 128, 132, 136, 140, 142
        ]
        return bases
    }

    // MARK: Metric Row

    private var metricRow: some View {
        HStack(spacing: 10) {
            miniMetric(icon: "waveform.path.ecg", label: "BP",    value: "124/82", color: VCColors.alertOrange)
            miniMetric(icon: "heart.fill",         label: "HR",    value: "68",     color: VCColors.secondary)
            miniMetric(icon: "moon.fill",          label: "Sleep", value: "7.2h",   color: VCColors.primary)
        }
    }

    // MARK: Progress Bars

    private var progressBars: some View {
        VStack(spacing: 6) {
            progressBar(
                icon: "figure.walk",
                label: "Steps",
                current: 7520,
                target: 10000,
                color: VCColors.primary,
                unit: ""
            )
            progressBar(
                icon: "drop.fill",
                label: "Fluid",
                current: 1200,
                target: 2500,
                color: VCColors.tertiary,
                unit: "mL"
            )
        }
    }

    // MARK: Widget Background

    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [Color.white, VCColors.primaryContainer.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: VCColors.primary.opacity(0.2), radius: 20, y: 6)
    }

    // MARK: - Sub-components

    private func miniMetric(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.7))
        )
    }

    private func progressBar(
        icon: String,
        label: String,
        current: Int,
        target: Int,
        color: Color,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                Spacer()
                Text("\(current.formatted()) / \(target.formatted())\(unit)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(VCColors.outline)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VCColors.surfaceLow)
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(Double(current) / Double(target), 1.0),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Large Widget") {
    LargeWidgetView()
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}
#endif
