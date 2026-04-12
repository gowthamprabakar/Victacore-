// LockScreenWidgetView.swift
// VitaCore — Lock Screen Widget Preview
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Note: This is a widget PREVIEW rendered inside the main app for design
//       review. A future sprint will extract this into a WidgetExtension target.

import SwiftUI
import VitaCoreDesign

// MARK: - LockScreenWidgetView

/// Simulates a circular lock screen widget showing glucose value + trend.
/// Rendered at 90×90 pt — matches the accessoryRectangular / accessoryCircular
/// family dimensions for review purposes.
struct LockScreenWidgetView: View {

    // MARK: Inputs

    var glucoseValue: Int = 142
    var unit: String = "mg/dL"
    var trend: TrendIndicator = .stable

    // MARK: Supporting types

    enum TrendIndicator {
        case rising, stable, falling, risingFast, fallingFast

        var icon: String {
            switch self {
            case .rising:      return "arrow.up.right"
            case .stable:      return "arrow.right"
            case .falling:     return "arrow.down.right"
            case .risingFast:  return "arrow.up"
            case .fallingFast: return "arrow.down"
            }
        }
    }

    enum StatusBand {
        case safe, watch, alert, critical

        var color: Color {
            switch self {
            case .safe:     return VCColors.safe
            case .watch:    return VCColors.watch
            case .alert:    return VCColors.alertOrange
            case .critical: return VCColors.critical
            }
        }
    }

    // MARK: Computed

    var band: StatusBand {
        if glucoseValue < 70  { return .critical }
        if glucoseValue < 80  { return .alert }
        if glucoseValue <= 140 { return .safe }
        if glucoseValue <= 180 { return .watch }
        return .alert
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(band.color)

            Text("\(glucoseValue)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)
                .contentTransition(.numericText())

            Text(unit)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(VCColors.onSurfaceVariant)

            Image(systemName: trend.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(band.color)
        }
        .frame(width: 90, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(band.color.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: band.color.opacity(0.2), radius: 10)
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Lock Screen Widget States") {
    VStack(spacing: 20) {
        LockScreenWidgetView(glucoseValue: 142, trend: .stable)   // safe
        LockScreenWidgetView(glucoseValue: 95,  trend: .falling)  // safe / falling
        LockScreenWidgetView(glucoseValue: 185, trend: .rising)   // watch / rising
        LockScreenWidgetView(glucoseValue: 65,  trend: .fallingFast) // critical
    }
    .padding()
    .background(Color.black)
}
#endif
