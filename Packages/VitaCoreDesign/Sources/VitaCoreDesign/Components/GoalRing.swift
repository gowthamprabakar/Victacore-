// GoalRing.swift
// VitaCoreDesign — Animated circular arc goal tracker

import SwiftUI

// MARK: - GoalRing

/// An animated circular progress ring that fills from 0 % to `current / target`.
///
/// The arc fill is driven by `VCAnimation.ringFill` on appear.
/// The percentage label is centred inside the ring.
public struct GoalRing: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let label: String
    public let current: Double
    public let target: Double
    public let accentColor: Color
    public let size: CGFloat

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        label: String,
        current: Double,
        target: Double,
        accentColor: Color = VCColors.primary,
        size: CGFloat = 120
    ) {
        self.label       = label
        self.current     = current
        self.target      = target
        self.accentColor = accentColor
        self.size        = size
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var animatedProgress: Double = 0

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    private var percentageText: String {
        "\(Int(fraction * 100))%"
    }

    private var lineWidth: CGFloat { size * 0.09 }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        VStack(spacing: VCSpacing.sm) {
            ZStack {
                // Background track
                Circle()
                    .stroke(VCColors.surfaceHigh, lineWidth: lineWidth)

                // Foreground arc with gradient
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [accentColor.opacity(0.6), accentColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                // Centre label
                VStack(spacing: 2) {
                    Text(percentageText)
                        .vcFont(.title2)
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())

                    Text(label)
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, lineWidth + 4)
                }
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(VCAnimation.ringFill) {
                animatedProgress = fraction
            }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(VCAnimation.ringFill) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("GoalRing") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        HStack(spacing: VCSpacing.xxl) {
            GoalRing(label: "Steps", current: 7200, target: 10000, accentColor: VCColors.safe)
            GoalRing(label: "Calories", current: 1450, target: 2000, accentColor: VCColors.secondary, size: 100)
            GoalRing(label: "Water", current: 2.1, target: 2.5, accentColor: VCColors.tertiary, size: 80)
        }
        .padding()
    }
}
#endif
