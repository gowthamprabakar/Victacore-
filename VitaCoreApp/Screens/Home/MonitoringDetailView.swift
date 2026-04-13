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

/// Sprint 3.C: build metric grid from real MonitoringSnapshot data.
private func buildMetricGrid(from snapshot: MonitoringSnapshot?) -> [MetricCard] {
    guard let snap = snapshot else {
        // Fallback: show "No data" for all metrics.
        return [
            MetricCard(name: "Glucose", value: "—", freshness: .missing, timestamp: "No data", icon: "drop.fill"),
            MetricCard(name: "HR", value: "—", freshness: .missing, timestamp: "No data", icon: "waveform.path.ecg"),
            MetricCard(name: "Steps", value: "—", freshness: .missing, timestamp: "No data", icon: "figure.walk"),
        ]
    }

    var cards: [MetricCard] = []
    let now = Date()

    func freshness(_ reading: Reading?) -> MetricFreshness {
        guard let r = reading else { return .missing }
        let age = now.timeIntervalSince(r.timestamp)
        if age < 900 { return .fresh }      // < 15 min
        return .stale                       // >= 15 min
    }

    func timeAgo(_ reading: Reading?) -> String {
        guard let r = reading else { return "No data" }
        let mins = Int(now.timeIntervalSince(r.timestamp) / 60)
        if mins < 1 { return "Now" }
        if mins < 60 { return "\(mins) min ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    if let g = snap.glucose {
        cards.append(MetricCard(name: "Glucose", value: "\(Int(g.value)) \(g.unit)", freshness: freshness(g), timestamp: timeAgo(g), icon: "drop.fill"))
    }
    if let sys = snap.bloodPressureSystolic, let dia = snap.bloodPressureDiastolic {
        cards.append(MetricCard(name: "BP", value: "\(Int(sys.value))/\(Int(dia.value))", freshness: freshness(sys), timestamp: timeAgo(sys), icon: "heart.fill"))
    }
    if let hr = snap.heartRate {
        cards.append(MetricCard(name: "HR", value: "\(Int(hr.value)) bpm", freshness: freshness(hr), timestamp: timeAgo(hr), icon: "waveform.path.ecg"))
    }
    if let hrv = snap.heartRateVariability {
        cards.append(MetricCard(name: "HRV", value: "\(Int(hrv.value)) ms", freshness: freshness(hrv), timestamp: timeAgo(hrv), icon: "waveform"))
    }
    if let spo2 = snap.spo2 {
        cards.append(MetricCard(name: "SpO₂", value: "\(Int(spo2.value))%", freshness: freshness(spo2), timestamp: timeAgo(spo2), icon: "lungs.fill"))
    }
    if let steps = snap.steps {
        cards.append(MetricCard(name: "Steps", value: "\(Int(steps.value))", freshness: freshness(steps), timestamp: timeAgo(steps), icon: "figure.walk"))
    }
    if let sleep = snap.sleep {
        let h = Int(sleep.value)
        let m = Int((sleep.value - Double(h)) * 60)
        cards.append(MetricCard(name: "Sleep", value: "\(h)h \(m)m", freshness: freshness(sleep), timestamp: timeAgo(sleep), icon: "moon.stars.fill"))
    }
    if let fluid = snap.fluidIntake {
        cards.append(MetricCard(name: "Fluid", value: "\(Int(fluid.value)) mL", freshness: freshness(fluid), timestamp: timeAgo(fluid), icon: "cup.and.saucer.fill"))
    }
    if let weight = snap.weight {
        cards.append(MetricCard(name: "Weight", value: String(format: "%.1f kg", weight.value), freshness: freshness(weight), timestamp: timeAgo(weight), icon: "scalemass.fill"))
    }
    return cards
}

private struct ThresholdItem: Identifiable {
    let id = UUID()
    let label: String
    let condition: String
    let icon: String
}

/// Sprint 3 M-01: build thresholds from real ThresholdEngine resolution.
private func buildThresholdItems(from set: ThresholdSet?) -> [ThresholdItem] {
    guard let set else {
        return [ThresholdItem(label: "Loading...", condition: "—", icon: "hourglass")]
    }
    var items: [ThresholdItem] = []
    for t in set.thresholds {
        let range = "\(Int(t.safeBand.lowerBound))–\(Int(t.safeBand.upperBound)) \(t.metricType.unit)"
        let priority = t.priority > 0 ? " (priority \(t.priority))" : ""
        items.append(ThresholdItem(
            label: "\(t.metricType.displayName) target",
            condition: range + priority,
            icon: t.metricType.icon
        ))
    }
    return items
}

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

/// Sprint 3 M-02: build findings from real GraphStore episodes.
private func buildRecentFindings(from episodes: [Episode]) -> [FindingEntry] {
    let now = Date()
    return episodes.prefix(10).map { ep in
        let mins = Int(now.timeIntervalSince(ep.referenceTime) / 60)
        let timeAgo: String = {
            if mins < 1 { return "Just now" }
            if mins < 60 { return "\(mins)m ago" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h ago" }
            return "\(hrs / 24)d ago"
        }()

        let severity: FindingSeverity
        let icon: String
        let message: String

        switch ep.episodeType {
        case .cgmGlucose:
            severity = .alert; icon = "exclamationmark.triangle.fill"
            message = "Glucose event"
        case .bpReading:
            severity = .ok; icon = "heart.fill"
            message = "BP reading"
        case .monitoringResult:
            severity = .ok; icon = "checkmark.circle.fill"
            message = "Monitoring cycle completed"
        case .alertEvent:
            severity = .watch; icon = "exclamationmark.circle.fill"
            message = "Alert fired"
        case .nutritionEvent:
            severity = .ok; icon = "leaf.fill"
            message = "Food logged"
        default:
            severity = .ok; icon = "circle.fill"
            message = ep.episodeType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return FindingEntry(message: message, timeAgo: timeAgo, severity: severity, icon: icon)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class MonitoringDetailViewModel {
    var snapshot: MonitoringSnapshot?
    var thresholdSet: ThresholdSet?
    var recentEpisodes: [Episode] = []
    var lastCycleTime: Date?
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            // Load snapshot + recent episodes in parallel.
            async let snapshotTask = graphStore.getCurrentSnapshot()
            async let episodesTask = graphStore.getEpisodes(
                from: Date().addingTimeInterval(-86400),
                to: Date(),
                types: EpisodeType.allCases
            )

            snapshot = try await snapshotTask
            recentEpisodes = try await episodesTask
                .sorted { $0.referenceTime > $1.referenceTime }

            // ThresholdSet from ThresholdResolver (inline, no engine dep needed).
            // The View passes it in or we compute from environment.

            // Last cycle time from most recent monitoringResult episode.
            lastCycleTime = recentEpisodes
                .first { $0.episodeType == .monitoringResult }?
                .referenceTime

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
                    cycleTimingItem(icon: "clock.arrow.circlepath", label: "Last cycle", value: lastCycleDisplay)
                    Divider()
                        .frame(height: 36)
                        .overlay(Color(hex: "#5d5f65").opacity(0.15))
                    cycleTimingItem(icon: "clock.badge.arrow.circlepath", label: "Next cycle", value: nextCycleDisplay)
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    /// Sprint 3 M-03: real cycle timing from HeartbeatEngine.
    private var lastCycleDisplay: String {
        guard let t = viewModel?.lastCycleTime else { return "—" }
        let mins = Int(Date().timeIntervalSince(t) / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins) min ago" }
        return "\(mins / 60)h ago"
    }

    private var nextCycleDisplay: String {
        guard let t = viewModel?.lastCycleTime else { return "—" }
        let secsSince = Date().timeIntervalSince(t)
        let secsUntil = max(0, 60 - secsSince) // 60s cycle
        if secsUntil < 5 { return "Now" }
        return "in \(Int(secsUntil))s"
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
                    ForEach(buildMetricGrid(from: viewModel?.snapshot)) { card in
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
                    Text("\(buildThresholdItems(from: viewModel?.thresholdSet).count) rules")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Divider()
                    .overlay(Color(hex: "#5d5f65").opacity(0.12))

                ForEach(buildThresholdItems(from: viewModel?.thresholdSet)) { item in
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

                ForEach(Array(buildRecentFindings(from: viewModel?.recentEpisodes ?? []).enumerated()), id: \.element.id) { index, finding in
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

                            if index < buildRecentFindings(from: viewModel?.recentEpisodes ?? []).count - 1 {
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
                        .padding(.bottom, index < buildRecentFindings(from: viewModel?.recentEpisodes ?? []).count - 1 ? VCSpacing.sm : 0)
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
