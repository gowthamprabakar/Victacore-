// MetricDetailComponents.swift
// VitaCoreApp — Shared components for metric detail screens
// Architecture: OpenClaw 5-layer, Design System v1.0 Deep Space Bioluminescence

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - TimeRange

enum TimeRange: String, CaseIterable, Identifiable {
    case sixHours = "6h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .sixHours:       return 6 * 3_600
        case .twentyFourHours: return 24 * 3_600
        case .sevenDays:      return 7 * 86_400
        case .thirtyDays:     return 30 * 86_400
        case .ninetyDays:     return 90 * 86_400
        }
    }

    var displayLabel: String { rawValue }
}

// MARK: - TimeRangeSelector

struct TimeRangeSelector: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: selected == range ? .semibold : .regular))
                        .foregroundColor(selected == range ? .white : VCColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Group {
                                if selected == range {
                                    Capsule().fill(VCColors.primary)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(VCColors.surfaceLow))
    }
}

// MARK: - StatisticsStrip

struct StatStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
}

struct StatisticsStrip: View {
    let stats: [StatStat]

    var body: some View {
        HStack(spacing: VCSpacing.md) {
            ForEach(stats) { stat in
                GlassCard(style: .small) {
                    VStack(alignment: .leading, spacing: VCSpacing.xs) {
                        Text(stat.label.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(VCColors.outline)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(stat.value)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(VCColors.onSurface)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(stat.unit)
                                .font(.system(size: 10))
                                .foregroundColor(VCColors.onSurfaceVariant)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - AIInsightCard

struct AIInsightCard: View {
    let insightText: String

    var body: some View {
        GlassCard(style: .enhanced) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack(spacing: VCSpacing.sm) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                    Text("VITACORE INSIGHT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(VCColors.primary)
                }
                Text(insightText)
                    .font(.system(size: 14))
                    .foregroundColor(VCColors.onSurface)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - MetricDetailHeader

struct MetricDetailHeader: View {
    let title: String
    let onBack: () -> Void
    let onLog: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VCColors.surfaceLow))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)

            Spacer()

            Button(action: onLog) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ViewState Skeleton Shimmer

struct ShimmerBlock: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var phase: CGFloat = 0

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = VCRadius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: VCColors.surfaceLow.opacity(0.6), location: 0),
                        .init(color: VCColors.surfaceLow.opacity(1.0), location: 0.4 + phase * 0.6),
                        .init(color: VCColors.surfaceLow.opacity(0.6), location: 1),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct MetricDetailSkeleton: View {
    var body: some View {
        VStack(spacing: VCSpacing.xl) {
            ShimmerBlock(height: 44, cornerRadius: VCRadius.md)
            ShimmerBlock(height: 130, cornerRadius: VCRadius.lg)
            ShimmerBlock(height: 44, cornerRadius: VCRadius.pill)
            ShimmerBlock(height: 240, cornerRadius: VCRadius.lg)
            HStack(spacing: VCSpacing.md) {
                ShimmerBlock(height: 160, cornerRadius: VCRadius.lg)
                ShimmerBlock(height: 160, cornerRadius: VCRadius.lg)
            }
            ShimmerBlock(height: 80, cornerRadius: VCRadius.lg)
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.vertical, VCSpacing.lg)
    }
}

// MARK: - Error State

struct MetricDetailErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: VCSpacing.xl) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VCColors.alertOrange)
            Text("Unable to Load Data")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxxl)
            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(
                        Capsule().fill(VCColors.primary)
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

// MARK: - Stale Banner

struct StaleBanner: View {
    let timestamp: Date

    var body: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundColor(VCColors.watch)
            Text("Data may be stale — last updated \(timestamp, style: .relative) ago")
                .font(.system(size: 11))
                .foregroundColor(VCColors.onSurfaceVariant)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.sm)
                .fill(VCColors.watch.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.sm)
                        .stroke(VCColors.watch.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Divider helper

struct VCDivider: View {
    var body: some View {
        Rectangle()
            .fill(VCColors.outline.opacity(0.15))
            .frame(height: 1)
    }
}
