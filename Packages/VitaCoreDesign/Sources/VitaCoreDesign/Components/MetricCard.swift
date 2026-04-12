// MetricCard.swift
// VitaCoreDesign — Health metric display card
// Intentionally self-contained: does NOT import VitaCoreContracts.
// The host app bridges domain types into these generic display parameters.

import SwiftUI

// MARK: - Local supporting types

/// Trend direction token for display purposes (mirrors VitaCoreContracts.TrendDirection).
public enum MetricTrendDirection: String, CaseIterable {
    case rising
    case stable
    case falling
    case risingFast
    case fallingFast
    case unknown

    var icon: String {
        switch self {
        case .rising:      return "arrow.up.right"
        case .stable:      return "arrow.right"
        case .falling:     return "arrow.down.right"
        case .risingFast:  return "arrow.up.forward.circle.fill"
        case .fallingFast: return "arrow.down.forward.circle.fill"
        case .unknown:     return "minus"
        }
    }

    var color: Color {
        switch self {
        case .stable:      return VCColors.safe
        case .rising, .falling: return VCColors.watch
        case .risingFast, .fallingFast: return VCColors.alertOrange
        case .unknown:     return VCColors.outline
        }
    }
}

// MARK: - MetricCard

/// Displays a single health metric with value, unit, trend, status badge,
/// and a mini progress bar.
///
/// Pass `showShimmer: true` while the reading is loading, or `isEmpty: true`
/// when the user has not yet set up the metric.
public struct MetricCard: View {

    // -------------------------------------------------------------------------
    // MARK: Input parameters
    // -------------------------------------------------------------------------

    public let value: String
    public let unit: String
    public let label: String
    public let icon: String                   // SF Symbol name
    public let bandColor: Color?              // nil → uses onSurface
    public let trendDirection: MetricTrendDirection?
    public let showShimmer: Bool
    public let isEmpty: Bool
    /// Progress fraction [0…1] for the mini bar. Nil hides the bar.
    public let progress: Double?
    /// True when the reading is stale / last-known.
    public let isStale: Bool

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        value: String,
        unit: String,
        label: String,
        icon: String,
        bandColor: Color? = nil,
        trendDirection: MetricTrendDirection? = nil,
        showShimmer: Bool = false,
        isEmpty: Bool = false,
        progress: Double? = nil,
        isStale: Bool = false
    ) {
        self.value         = value
        self.unit          = unit
        self.label         = label
        self.icon          = icon
        self.bandColor     = bandColor
        self.trendDirection = trendDirection
        self.showShimmer   = showShimmer
        self.isEmpty       = isEmpty
        self.progress      = progress
        self.isStale       = isStale
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var shimmerPhase: CGFloat = -1
    @State private var appeared: Bool = false

    private var accentColor: Color {
        bandColor ?? VCColors.primary
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                headerRow
                Divider().overlay(VCColors.outlineVariant)
                contentArea
                if let p = progress {
                    progressBar(fraction: p)
                }
            }
        }
        .opacity(isStale ? 0.65 : 1.0)
        .onAppear { appeared = true }
    }

    // -------------------------------------------------------------------------
    // MARK: Subviews
    // -------------------------------------------------------------------------

    private var headerRow: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous))

            Text(label)
                .vcFont(.headline)
                .foregroundStyle(VCColors.onSurface)

            Spacer()

            if let trend = trendDirection {
                Image(systemName: trend.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(trend.color)
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if showShimmer {
            shimmerPlaceholder
        } else if isEmpty {
            emptyState
        } else {
            valueRow
        }
    }

    private var valueRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
            Text(value)
                .vcFont(.hero)
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())

            Text(unit)
                .vcFont(.subhead)
                .foregroundStyle(VCColors.onSurfaceVariant)

            Spacer()

            if isStale {
                Label("Stale", systemImage: "clock")
                    .vcFont(.caption)
                    .foregroundStyle(VCColors.outline)
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Text("Set up")
                .vcFont(.subhead)
                .foregroundStyle(VCColors.outline)
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundStyle(VCColors.primary)
        }
    }

    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        VCColors.surfaceLow,
                        VCColors.surface,
                        VCColors.surfaceLow
                    ],
                    startPoint: .init(x: shimmerPhase, y: 0),
                    endPoint: .init(x: shimmerPhase + 1, y: 0)
                )
            )
            .frame(height: 36)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                    .fill(VCColors.surfaceHigh)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                    .fill(accentColor)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1), height: 4)
                    .animation(VCAnimation.ringFill, value: fraction)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("MetricCard States") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        ScrollView {
            VStack(spacing: VCSpacing.xl) {
                MetricCard(
                    value: "98",
                    unit: "mg/dL",
                    label: "Blood Glucose",
                    icon: "drop.fill",
                    bandColor: VCColors.safe,
                    trendDirection: .stable,
                    progress: 0.55
                )

                MetricCard(
                    value: "142",
                    unit: "mg/dL",
                    label: "Blood Glucose",
                    icon: "drop.fill",
                    bandColor: VCColors.watch,
                    trendDirection: .risingFast,
                    progress: 0.80
                )

                MetricCard(
                    value: "—",
                    unit: "",
                    label: "Heart Rate",
                    icon: "heart.fill",
                    showShimmer: true
                )

                MetricCard(
                    value: "—",
                    unit: "",
                    label: "Blood Oxygen",
                    icon: "lungs.fill",
                    isEmpty: true
                )
            }
            .padding(VCSpacing.xl)
        }
    }
}
#endif
