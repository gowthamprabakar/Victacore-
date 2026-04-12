// MediumWidgetView.swift
// VitaCore — Home Screen Medium Widget Preview (2×4 grid size)
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Note: This is a widget PREVIEW rendered inside the main app for design
//       review. A future sprint will extract this into a WidgetExtension target.

import SwiftUI
import VitaCoreDesign

// MARK: - MediumWidgetView

/// Simulates a Home Screen medium widget (340×160 pt) showing 4 key metrics
/// in a 2×2 grid with a status header.
struct MediumWidgetView: View {

    // MARK: Body

    var body: some View {
        VStack(spacing: 10) {
            header
            metricsGrid
        }
        .padding(14)
        .frame(width: 340, height: 160)
        .background(widgetBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("VitaCore")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(VCColors.primary)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(VCColors.safe)
                    .frame(width: 6, height: 6)
                Text("5m ago")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
        }
    }

    // MARK: 2x2 Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            widgetMetric(
                icon: "drop.fill",
                iconColor: VCColors.tertiary,
                label: "Glucose",
                value: "142",
                unit: "mg/dL",
                statusColor: VCColors.safe
            )
            widgetMetric(
                icon: "heart.fill",
                iconColor: VCColors.secondary,
                label: "Heart Rate",
                value: "68",
                unit: "bpm",
                statusColor: VCColors.safe
            )
            widgetMetric(
                icon: "waveform.path.ecg",
                iconColor: VCColors.alertOrange,
                label: "BP",
                value: "124/82",
                unit: "mmHg",
                statusColor: VCColors.watch
            )
            widgetMetric(
                icon: "figure.walk",
                iconColor: VCColors.primary,
                label: "Steps",
                value: "7.5k",
                unit: "/10k",
                statusColor: VCColors.safe
            )
        }
    }

    // MARK: Widget Background

    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [Color.white, VCColors.primaryContainer.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: VCColors.primary.opacity(0.15), radius: 16, y: 4)
    }

    // MARK: Mini Metric Card

    private func widgetMetric(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        unit: String,
        statusColor: Color
    ) -> some View {
        HStack(spacing: 6) {
            // Color-coded left border
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                // Icon + label row
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundStyle(iconColor)
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
                // Value + unit row
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VCColors.onSurface)
                    Text(unit)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(VCColors.outline)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.6))
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Medium Widget") {
    MediumWidgetView()
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
