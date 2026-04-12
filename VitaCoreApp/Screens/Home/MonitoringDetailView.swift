// MonitoringDetailView.swift
// VitaCore — Monitoring Detail Screen
// System diagnostic view: HeartbeatEngine cycle data, metric freshness, thresholds, findings log.

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - Local Models

private enum MetricFreshness {
    case fresh    // < 15 min
    case stale    // 15 min – 24 h
    case missing  // > 24 h or never

    var label: String {
        switch self {
        case .fresh:   return "Fresh"
        case .stale:   return "Stale"
        case .missing: return "Missing"
        }
    }

    var color: Color {
        switch self {
        case .fresh:   return Color(hex: "#00BFA5")
        case .stale:   return Color(hex: "#FFB300")
        case .missing: return Color(hex: "#5d5f65")
        }
    }
}

private struct MetricCard: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let freshness: MetricFreshness
    let timestamp: String
    let icon: String
}

private let metricGrid: [MetricCard] = [
    MetricCard(name: "Glucose",  value: "108 mg/dL", freshness: .fresh,   timestamp: "2 min ago",  icon: "drop.fill"),
    MetricCard(name: "BP",       value: "124/82",    freshness: .stale,   timestamp: "6 h ago",    icon: "heart.fill"),
    MetricCard(name: "HR",       value: "68 bpm",    freshness: .fresh,   timestamp: "1 min ago",  icon: "waveform.path.ecg"),
    MetricCard(name: "HRV",      value: "42 ms",     freshness: .stale,   timestamp: "8 h ago",    icon: "waveform"),
    MetricCard(name: "SpO₂",     value: "98%",       freshness: .fresh,   timestamp: "3 min ago",  icon: "lungs.fill"),
    MetricCard(name: "Steps",    value: "7,520",     freshness: .fresh,   timestamp: "Now",        icon: "figure.walk"),
    MetricCard(name: "Sleep",    value: "7h 12m",    freshness: .fresh,   timestamp: "Today",      icon: "moon.stars.fill"),
    MetricCard(name: "Fluid",    value: "1,200 mL",  freshness: .fresh,   timestamp: "18 min ago", icon: "cup.and.saucer.fill"),
    MetricCard(name: "Weight",   value: "82.4 kg",   freshness: .missing, timestamp: "2 days ago", icon: "scalemass.fill"),
]

private struct ThresholdItem: Identifiable {
    let id = UUID()
    let label: String
    let condition: String
    let icon: String
}

private let thresholds: [ThresholdItem] = [
    ThresholdItem(label: "Glucose target",  condition: "70–140 mg/dL (T2D adjusted)",   icon: "drop.fill"),
    ThresholdItem(label: "BP target",       condition: "<140/90 mmHg (HTN adjusted)",   icon: "heart.fill"),
    ThresholdItem(label: "HR resting",      condition: "50–90 bpm",                     icon: "waveform.path.ecg"),
    ThresholdItem(label: "Fluid minimum",   condition: "2,500 mL/day",                  icon: "cup.and.saucer.fill"),
]

private enum FindingSeverity {
    case alert, watch, ok

    var color: Color {
        switch self {
        case .alert: return Color(hex: "#FF1744")
        case .watch: return Color(hex: "#FFB300")
        case .ok:    return Color(hex: "#00BFA5")
        }
    }

    var label: String {
        switch self {
        case .alert: return "Alert"
        case .watch: return "Watch"
        case .ok:    return "OK"
        }
    }
}

private struct FindingEntry: Identifiable {
    let id = UUID()
    let message: String
    let timeAgo: String
    let severity: FindingSeverity
    let icon: String
}

private let recentFindings: [FindingEntry] = [
    FindingEntry(message: "Glucose elevated (192 mg/dL)",  timeAgo: "2h ago",  severity: .alert, icon: "exclamationmark.triangle.fill"),
    FindingEntry(message: "BP normal (124/82)",            timeAgo: "3h ago",  severity: .ok,    icon: "checkmark.circle.fill"),
    FindingEntry(message: "Extended inactivity (45 min)",  timeAgo: "4h ago",  severity: .watch, icon: "figure.stand"),
    FindingEntry(message: "HR elevated briefly (102 bpm)", timeAgo: "5h ago",  severity: .watch, icon: "waveform.path.ecg"),
    FindingEntry(message: "SpO₂ normal (98%)",             timeAgo: "6h ago",  severity: .ok,    icon: "checkmark.circle.fill"),
    FindingEntry(message: "Fluid intake on track",         timeAgo: "7h ago",  severity: .ok,    icon: "checkmark.circle.fill"),
    FindingEntry(message: "HRV below weekly avg (38 ms)",  timeAgo: "8h ago",  severity: .watch, icon: "arrow.down.circle.fill"),
    FindingEntry(message: "Deep sleep target met",         timeAgo: "9h ago",  severity: .ok,    icon: "checkmark.circle.fill"),
    FindingEntry(message: "Step goal achieved",            timeAgo: "Yesterday", severity: .ok,  icon: "checkmark.circle.fill"),
    FindingEntry(message: "Glucose spike post-meal",       timeAgo: "Yesterday", severity: .watch, icon: "exclamationmark.circle.fill"),
]

// MARK: - ViewModel

@Observable
@MainActor
final class MonitoringDetailViewModel {
    var snapshot: MonitoringSnapshot?
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            snapshot = try await graphStore.getCurrentSnapshot()
            viewState = .data(())
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - View

struct MonitoringDetailView: View {
    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: MonitoringDetailViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    MetricDetailHeader(
                        title: "Monitoring",
                        onBack: { dismiss() },
                        onLog: {}
                    )

                    systemStatusCard

                    cycleDetailsCard

                    metricFreshnessGrid

                    activeThresholdsCard

                    findingsLogCard

                    nextScheduledCard
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = MonitoringDetailViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
    }

    // MARK: System Status Card

    private var systemStatusCard: some View {
        GlassCard(style: .hero) {
            VStack(spacing: VCSpacing.md) {
                // Header row
                HStack(spacing: VCSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00BFA5").opacity(0.2))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(Color(hex: "#00BFA5"))
                            .frame(width: 10, height: 10)
                    }

                    Text("HeartbeatEngine Active")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#313238"))

                    Spacer()

                    StatusBadge(band: .safe, text: "Live")
                }

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.15))

                // Timing row
                HStack(spacing: 0) {
                    cycleTimingItem(icon: "clock.arrow.circlepath", label: "Last cycle", value: "3 min ago")
                    Divider()
                        .frame(height: 36)
                        .overlay(Color(hex: "#5d5f65").opacity(0.15))
                    cycleTimingItem(icon: "clock.badge.arrow.circlepath", label: "Next cycle", value: "in 2 min")
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    private func cycleTimingItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#694ead"))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "#5d5f65"))
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "#313238"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Cycle Details Card

    private var cycleDetailsCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Last Evaluation Cycle")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))
                    Spacer()
                    Text("Primary (5-min)")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#694ead"))
                        .padding(.horizontal, VCSpacing.sm)
                        .padding(.vertical, VCSpacing.xs)
                        .background(Color(hex: "#694ead").opacity(0.12))
                        .clipShape(Capsule())
                }

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.12))

                VStack(spacing: VCSpacing.sm) {
                    cycleDetailRow(label: "Evaluated at",       value: "14:23:17",  icon: "clock.fill")
                    cycleDetailRow(label: "Metrics evaluated",  value: "15",        icon: "chart.bar.xaxis")
                    cycleDetailRow(label: "Thresholds checked", value: "42",        icon: "slider.horizontal.3")
                    cycleDetailRow(label: "Composite rules",    value: "7",         icon: "link")
                    cycleDetailRow(label: "Duration",           value: "1.2 s",     icon: "bolt.fill")
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    private func cycleDetailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: VCSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#694ead").opacity(0.8))
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#5d5f65"))

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#313238"))
        }
    }

    // MARK: Metric Freshness Grid (3 × 3)

    private var metricFreshnessGrid: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Metric Freshness")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: VCSpacing.sm), count: 3),
                    spacing: VCSpacing.sm
                ) {
                    ForEach(metricGrid) { card in
                        freshnessCell(card: card)
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    private func freshnessCell(card: MetricCard) -> some View {
        VStack(alignment: .leading, spacing: VCSpacing.xs) {
            HStack(spacing: VCSpacing.xs) {
                Image(systemName: card.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(card.freshness.color)
                Spacer()
                Circle()
                    .fill(card.freshness.color)
                    .frame(width: 7, height: 7)
            }

            Text(card.name)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#313238"))

            Text(card.value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "#313238"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(card.timestamp)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#5d5f65"))
        }
        .padding(VCSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.freshness.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .stroke(card.freshness.color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Active Thresholds Card

    private var activeThresholdsCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Active Thresholds")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))
                    Spacer()
                    Text("\(thresholds.count) rules")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.12))

                ForEach(thresholds) { item in
                    HStack(spacing: VCSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#694ead").opacity(0.1))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#694ead"))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color(hex: "#313238"))
                            Text(item.condition)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                        }

                        Spacer()

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "#00BFA5"))
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Recent Findings Log

    private var findingsLogCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Recent Findings")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))
                    Spacer()
                    Text("Last 10")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.12))

                ForEach(Array(recentFindings.enumerated()), id: \.element.id) { index, finding in
                    HStack(alignment: .top, spacing: VCSpacing.md) {
                        // Timeline dot + connector
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(finding.severity.color.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: finding.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(finding.severity.color)
                            }

                            if index < recentFindings.count - 1 {
                                Rectangle()
                                    .fill(Color(hex: "#5d5f65").opacity(0.15))
                                    .frame(width: 1.5, height: 28)
                            }
                        }

                        VStack(alignment: .leading, spacing: VCSpacing.xs) {
                            HStack {
                                Text(finding.message)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(hex: "#313238"))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(finding.severity.label)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(finding.severity.color)
                                    .padding(.horizontal, VCSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(finding.severity.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Text(finding.timeAgo)
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                        }
                        .padding(.bottom, index < recentFindings.count - 1 ? VCSpacing.sm : 0)
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Next Scheduled Card

    private var nextScheduledCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Upcoming Scheduled Events")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.12))

                scheduledEventRow(
                    icon: "clock.badge.checkmark.fill",
                    title: "Daily Review",
                    subtitle: "Tonight at 9:00 PM",
                    color: Color(hex: "#694ead")
                )

                scheduledEventRow(
                    icon: "calendar.badge.clock",
                    title: "Weekly Digest",
                    subtitle: "Sunday at 8:00 AM",
                    color: Color(hex: "#006594")
                )
            }
            .padding(VCSpacing.xxl)
        }
    }

    private func scheduledEventRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: VCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: VCRadius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(hex: "#313238"))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#5d5f65"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color(hex: "#5d5f65").opacity(0.5))
        }
    }
}

// MARK: - Color Hex Helper (local, scoped)

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    MonitoringDetailView()
}
