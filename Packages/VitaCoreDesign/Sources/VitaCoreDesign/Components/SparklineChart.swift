// SparklineChart.swift
// VitaCoreDesign — Mini line-chart sparkline using SwiftUI Path

import SwiftUI

// MARK: - SparklineChart

/// A compact sparkline chart drawn with SwiftUI `Path`.
///
/// Features:
/// - Smooth line connecting data points
/// - Gradient fill area beneath the line
/// - Optional horizontal dashed lines for the safe-band range
/// - Animated glow dot at the current (last) value
public struct SparklineChart: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let values: [Double]
    /// When provided, dashed horizontal lines mark the lower and upper bounds.
    public let safeBandRange: ClosedRange<Double>?
    public let accentColor: Color
    public let height: CGFloat

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        values: [Double],
        safeBandRange: ClosedRange<Double>? = nil,
        accentColor: Color = VCColors.primary,
        height: CGFloat = 60
    ) {
        self.values        = values
        self.safeBandRange = safeBandRange
        self.accentColor   = accentColor
        self.height        = height
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var glowOpacity: Double = 0.3

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private var minValue: Double { values.min() ?? 0 }
    private var maxValue: Double {
        let m = values.max() ?? 1
        return m == minValue ? minValue + 1 : m  // avoid division by zero
    }

    private func normalised(_ v: Double) -> Double {
        (v - minValue) / (maxValue - minValue)
    }

    private func point(index: Int, in size: CGSize) -> CGPoint {
        guard values.count > 1 else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
        let y = (1 - normalised(values[index])) * size.height
        return CGPoint(x: x, y: y)
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Safe-band horizontal guides
                if let band = safeBandRange {
                    safeBandLines(band: band, size: size)
                }
                // Gradient fill
                gradientFill(size: size)
                // Line
                sparkLine(size: size)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                // Terminal glow dot
                if let last = values.last, values.count > 1 {
                    let pt = point(index: values.count - 1, in: size)
                    terminalDot(at: pt, value: last)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(VCAnimation.breathe) {
                glowOpacity = 0.9
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Subviews
    // -------------------------------------------------------------------------

    private func sparkLine(size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        path.move(to: point(index: 0, in: size))
        for i in 1..<values.count {
            let p0 = point(index: i - 1, in: size)
            let p1 = point(index: i, in: size)
            let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) * 0.5, y: p0.y)
            let cp2 = CGPoint(x: p1.x - (p1.x - p0.x) * 0.5, y: p1.y)
            path.addCurve(to: p1, control1: cp1, control2: cp2)
        }
        return path
    }

    private func gradientFill(size: CGSize) -> some View {
        sparkFillPath(size: size)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.25), accentColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func sparkFillPath(size: CGSize) -> Path {
        var path = sparkLine(size: size)
        guard values.count > 1 else { return path }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func safeBandLines(band: ClosedRange<Double>, size: CGSize) -> some View {
        Canvas { ctx, _ in
            let dash: [CGFloat] = [4, 4]

            func yForValue(_ v: Double) -> CGFloat {
                (1 - normalised(v)) * size.height
            }

            let lowerY = yForValue(band.lowerBound)
            let upperY = yForValue(band.upperBound)

            var lower = Path()
            lower.move(to: CGPoint(x: 0, y: lowerY))
            lower.addLine(to: CGPoint(x: size.width, y: lowerY))

            var upper = Path()
            upper.move(to: CGPoint(x: 0, y: upperY))
            upper.addLine(to: CGPoint(x: size.width, y: upperY))

            ctx.stroke(lower, with: .color(VCColors.safe.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: dash))
            ctx.stroke(upper, with: .color(VCColors.safe.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: dash))
        }
    }

    private func terminalDot(at point: CGPoint, value: Double) -> some View {
        ZStack {
            // Outer glow halo
            Circle()
                .fill(accentColor.opacity(glowOpacity * 0.25))
                .frame(width: 16, height: 16)

            // Solid dot
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)
                .shadow(color: accentColor.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .position(point)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SparklineChart") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        VStack(spacing: VCSpacing.xxl) {
            SparklineChart(
                values: [95, 102, 98, 110, 105, 99, 97, 100, 98, 96],
                safeBandRange: 70...140,
                accentColor: VCColors.safe,
                height: 80
            )
            .padding(.horizontal)

            SparklineChart(
                values: [130, 145, 160, 155, 170, 168, 158, 162, 155, 148],
                safeBandRange: 70...140,
                accentColor: VCColors.watch,
                height: 80
            )
            .padding(.horizontal)
        }
    }
}
#endif
