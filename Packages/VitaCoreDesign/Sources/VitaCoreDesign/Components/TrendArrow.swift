// TrendArrow.swift
// VitaCoreDesign — Direction pill with rotated arrow icon

import SwiftUI

// MARK: - TrendArrow

/// A compact pill view showing the direction of a metric's trend.
///
/// Pairs an SF Symbol arrow (rotated to match direction) with an optional
/// velocity string (e.g. "+8 mg/dL/hr").
public struct TrendArrow: View {

    // -------------------------------------------------------------------------
    // MARK: Direction

    public enum Direction: String, CaseIterable {
        case rising
        case stable
        case falling
        case risingFast
        case fallingFast

        /// Degrees to rotate the base "arrow.up" icon.
        var rotation: Double {
            switch self {
            case .rising:      return 0        // straight up
            case .stable:      return 90       // right
            case .falling:     return 180      // down
            case .risingFast:  return -30      // upper-right diagonal
            case .fallingFast: return 150      // lower-right diagonal
            }
        }

        var color: Color {
            switch self {
            case .stable:                 return VCColors.safe
            case .rising, .falling:       return VCColors.watch
            case .risingFast, .fallingFast: return VCColors.alertOrange
            }
        }

        var icon: String { "arrow.up" }

        var defaultLabel: String {
            switch self {
            case .rising:      return "Rising"
            case .stable:      return "Stable"
            case .falling:     return "Falling"
            case .risingFast:  return "Rising fast"
            case .fallingFast: return "Falling fast"
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let direction: Direction
    /// Optional velocity string displayed after the direction label.
    public let velocity: String?

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(direction: Direction, velocity: String? = nil) {
        self.direction = direction
        self.velocity  = velocity
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: direction.icon)
                .font(.system(size: 10, weight: .bold))
                .rotationEffect(.degrees(direction.rotation))

            Text(direction.defaultLabel)
                .vcFont(.badge)
                .textCase(.uppercase)

            if let v = velocity {
                Text(v)
                    .vcFont(.mono)
            }
        }
        .foregroundStyle(direction.color)
        .padding(.horizontal, VCSpacing.sm)
        .padding(.vertical, VCSpacing.xs)
        .background(direction.color.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(direction.color.opacity(0.25), lineWidth: 0.5)
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("TrendArrow") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        VStack(spacing: VCSpacing.lg) {
            ForEach(TrendArrow.Direction.allCases, id: \.self) { dir in
                TrendArrow(direction: dir, velocity: dir == .risingFast ? "+8 mg/dL/hr" : nil)
            }
        }
        .padding()
    }
}
#endif
