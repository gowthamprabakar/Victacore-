// HeartRateDetailView.swift
// VitaCoreApp — Heart Rate metric detail screen
// Architecture: OpenClaw 5-layer, Design System v1.0 Deep Space Bioluminescence

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - HR Zone

struct HRZone: Identifiable {
    let id = UUID()
    let name: String
    let abbreviation: String
    let minBPM: Double
    let maxBPM: Double
    let color: Color
    let description: String

    static let all: [HRZone] = [
        HRZone(
            name: "Resting", abbreviation: "REST",
            minBPM: 0, maxBPM: 60,
            color: VCColors.safe,
            description: "Below active threshold"
        ),
        HRZone(
            name: "Fat Burn", abbreviation: "FAT",
            minBPM: 60, maxBPM: 80,
            color: VCColors.tertiary,
            description: "Light activity zone"
        ),
        HRZone(
            name: "Cardio", abbreviation: "CARDIO",
            minBPM: 80, maxBPM: 100,
            color: VCColors.watch,
            description: "Aerobic improvement"
        ),
        HRZone(
            name: "Peak", abbreviation: "PEAK",
            minBPM: 100, maxBPM: 300,
            color: VCColors.alertOrange,
            description: "High intensity"
        )
    ]

    static func zone(for bpm: Double) -> HRZone {
        all.first { bpm >= $0.minBPM && bpm < $0.maxBPM } ?? all.last!
    }
}

// MARK: - HRZoneDistribution

struct HRZoneDistribution: Identifiable {
    let id = UUID()
    let zone: HRZone
    var minutes: Int
    var percentage: Double
}

// MARK: - ViewModel

@Observable
@MainActor
final class HeartRateDetailViewModel {

    var readings: [Reading] = []
    var currentReading: Reading?
    var aggregate: AggregatedMetric?
    var timeRange: TimeRange = .twentyFourHours
    var viewState: ViewState<Void> = .loading
    var lastUpdated: Date = Date()

    // HRV & Recovery mock (would come from HKQuantityTypeIdentifierHeartRateVariabilitySDNN)
    var hrv: Double = 42
    var recoveryScore: Double = 0.88
    var oneMinuteRecovery: Double = 18

    private let graphStore: any GraphStoreProtocol

    init(graphStore: any GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            let now = Date()
            let start = now.addingTimeInterval(-timeRange.duration)
            async let latestTask    = graphStore.getLatestReading(for: .heartRate)
            async let readingsTask  = graphStore.getRangeReadings(for: .heartRate, from: start, to: now)
            async let aggregateTask = graphStore.getAggregatedMetric(for: .heartRate, from: start, to: now)

            let (latest, range, agg) = try await (latestTask, readingsTask, aggregateTask)
            currentReading = latest
            readings = range.sorted { $0.timestamp < $1.timestamp }
            aggregate = agg
            lastUpdated = Date()

            if readings.isEmpty {
                viewState = .empty
            } else {
                let lastTimestamp = latest?.timestamp ?? Date.distantPast
                let age = Date().timeIntervalSince(lastTimestamp)
                viewState = age > 3600 ? .stale((), age: age) : .data(())
            }
        } catch {
            viewState = .error(error)
        }
    }

    // MARK: Zone distribution

    func zoneDistribution() -> [HRZoneDistribution] {
        let source = chartReadings
        guard !source.isEmpty else {
            return HRZone.all.enumerated().map { i, zone in
                let mockMins = [340, 85, 30, 5][i]
                let total = 460.0
                return HRZoneDistribution(zone: zone, minutes: mockMins, percentage: Double(mockMins) / total)
            }
        }
        let totalCount = Double(source.count)
        return HRZone.all.map { zone in
            let count = source.filter { $0.value >= zone.minBPM && $0.value < zone.maxBPM }.count
            return HRZoneDistribution(
                zone: zone,
                minutes: Int(Double(count) / totalCount * timeRange.duration / 60),
                percentage: Double(count) / totalCount
            )
        }
    }

    // MARK: Stats

    var restingHR: Double {
        let resting = chartReadings.filter { HRZone.zone(for: $0.value).name == "Resting" }
        guard !resting.isEmpty else { return aggregate?.min ?? 58 }
        return resting.map(\.value).reduce(0, +) / Double(resting.count)
    }

    var chartReadings: [Reading] {
        readings.isEmpty ? Self.mockReadings(for: timeRange) : readings
    }

    var avgHR: String { String(Int(aggregate?.average ?? 68)) }
    var minHR: String { String(Int(aggregate?.min ?? 52)) }
    var maxHR: String { String(Int(aggregate?.max ?? 138)) }
    var restingHRStr: String { String(Int(restingHR)) }

    var recoveryScorePercent: Int { Int(recoveryScore * 100) }
    var recoveryColor: Color {
        switch recoveryScore {
        case 0.8...: return VCColors.safe
        case 0.6..<0.8: return VCColors.watch
        default: return VCColors.alertOrange
        }
    }

    // MARK: Mock data

    static func mockReadings(for range: TimeRange) -> [Reading] {
        let now = Date()
        let count = 96
        let interval = range.duration / Double(count)
        let values: [Double] = {
            var v: [Double] = []
            for i in 0..<count {
                let hour = Calendar.current.component(.hour, from: now.addingTimeInterval(-range.duration + Double(i) * interval))
                let base: Double
                switch hour {
                case 0..<6:  base = 55 + Double.random(in: -3...3)
                case 6..<9:  base = 72 + Double.random(in: -8...15)
                case 9..<12: base = 68 + Double.random(in: -5...10)
                case 12..<14: base = 75 + Double.random(in: -5...25)
                case 14..<18: base = 70 + Double.random(in: -5...30)
                case 18..<21: base = 80 + Double.random(in: -5...35)
                default:     base = 62 + Double.random(in: -3...8)
                }
                v.append(base)
            }
            return v
        }()

        return values.enumerated().map { i, v in
            Reading(
                id: UUID(),
                metricType: .heartRate,
                value: max(40, min(200, v)),
                unit: "bpm",
                timestamp: now.addingTimeInterval(-range.duration + Double(i) * interval),
                sourceSkillId: "apple-watch-s9",
                confidence: 0.98,
                trendDirection: .stable,
                trendVelocity: nil
            )
        }
    }
}

// MARK: - Main View

struct HeartRateDetailView: View {

    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: HeartRateDetailViewModel?
    @State private var timeRange: TimeRange = .twentyFourHours
    @State private var showLogSheet = false

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            Group {
                switch viewModel?.viewState {
                case .loading, .none:
                    MetricDetailSkeleton()
                case .error(let err):
                    ZStack {
                        MetricDetailHeader(title: "Heart Rate", onBack: { dismiss() }, onLog: {})
                            .padding(.horizontal, VCSpacing.xxl)
                            .padding(.top, VCSpacing.lg)
                            .frame(maxHeight: .infinity, alignment: .top)
                        MetricDetailErrorView(message: err.localizedDescription) {
                            Task { await viewModel?.load() }
                        }
                    }
                case .empty:
                    emptyState
                case .data, .stale:
                    scrollContent
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showLogSheet) {
            Text("Log Heart Rate")
                .presentationDetents([.medium])
        }
        .task {
            if viewModel == nil {
                viewModel = HeartRateDetailViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
        .onChange(of: timeRange) { _, _ in
            Task { await viewModel?.load() }
        }
    }

    // MARK: Scroll content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VCSpacing.xl) {

                MetricDetailHeader(
                    title: "Heart Rate",
                    onBack: { dismiss() },
                    onLog: { showLogSheet = true }
                )

                if case .stale = viewModel?.viewState {
                    StaleBanner(timestamp: viewModel?.lastUpdated ?? Date())
                }

                heroSection
                TimeRangeSelector(selected: $timeRange)
                trendChart
                zoneBarChart
                recoveryCard
                statisticsStrip
                AIInsightCard(
                    insightText: "Your resting heart rate is trending down this week — a sign of improving cardiovascular fitness. HRV is within your normal range, and recovery looks excellent."
                )
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.vertical, VCSpacing.lg)
            .padding(.bottom, VCSpacing.xxxl)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: VCSpacing.xl) {
            MetricDetailHeader(title: "Heart Rate", onBack: { dismiss() }, onLog: { showLogSheet = true })
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VCColors.outline)
            Text("No heart rate data yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
            Text("Connect an Apple Watch or compatible wearable to see your heart rate trends.")
                .font(.system(size: 14))
                .foregroundColor(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxxl)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.vertical, VCSpacing.lg)
    }

    // MARK: Hero Section

    private var heroSection: some View {
        let bpm = Int(viewModel?.currentReading?.value ?? 68)
        let zone = HRZone.zone(for: Double(bpm))
        let trendDir: TrendArrow.Direction = {
            switch viewModel?.currentReading?.trendDirection ?? .stable {
            case .rising:      return .rising
            case .stable:      return .stable
            case .falling:     return .falling
            case .risingFast:  return .risingFast
            case .fallingFast: return .fallingFast
            }
        }()

        return GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack {
                    Text("CURRENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(VCColors.outline)
                    Spacer()
                    StatusBadge(band: {
                        switch zoneBand(zone) {
                        case .safe:     return StatusBadge.Band.safe
                        case .watch:    return StatusBadge.Band.watch
                        case .alert:    return StatusBadge.Band.alert
                        case .critical: return StatusBadge.Band.critical
                        }
                    }())
                }

                HStack(alignment: .firstTextBaseline, spacing: VCSpacing.sm) {
                    Text("\(bpm)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(zone.color)
                        .contentTransition(.numericText())
                    Text("bpm")
                        .font(.system(size: 20))
                        .foregroundColor(VCColors.onSurfaceVariant)
                    Spacer()
                    TrendArrow(direction: trendDir, velocity: "")
                }

                HStack(spacing: VCSpacing.sm) {
                    // Animated heart icon
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(VCColors.secondary)
                    Text(zone.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(zone.color)
                    Text("·")
                        .foregroundColor(VCColors.outline)
                    Text(zone.description)
                        .font(.system(size: 12))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }

                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 10))
                        .foregroundColor(VCColors.outline)
                    Text("Apple Watch Series 9 · Updated 1 min ago")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VCColors.outline)
                }
            }
        }
    }

    private func zoneBand(_ zone: HRZone) -> ThresholdBand {
        switch zone.name {
        case "Resting":  return .safe
        case "Fat Burn": return .safe
        case "Cardio":   return .watch
        default:         return .alert
        }
    }

    // MARK: HR Trend Chart

    private var trendChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Heart Rate Trend")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                let readings = viewModel?.chartReadings ?? []

                Chart {
                    // Zone band backgrounds
                    ForEach(HRZone.all) { zone in
                        RectangleMark(
                            xStart: .value("Start", readings.first?.timestamp ?? Date()),
                            xEnd: .value("End", readings.last?.timestamp ?? Date()),
                            yStart: .value("Low", zone.minBPM),
                            yEnd: .value("High", min(zone.maxBPM, 180))
                        )
                        .foregroundStyle(zone.color.opacity(0.06))
                    }

                    // Resting HR baseline
                    RuleMark(y: .value("Resting", viewModel?.restingHR ?? 58))
                        .foregroundStyle(VCColors.safe.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .leading) {
                            Text("Rest")
                                .font(.system(size: 8))
                                .foregroundColor(VCColors.safe)
                        }

                    // Area fill
                    ForEach(readings, id: \.id) { reading in
                        AreaMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("HR", reading.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [zoneColor(reading.value).opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // HR line — coloured by zone
                    ForEach(readings, id: \.id) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("HR", reading.value)
                        )
                        .foregroundStyle(zoneColor(reading.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 40...180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel(format: xAxisFormat)
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [60, 80, 100, 120, 140, 160]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 10))
                    }
                }

                // Zone legend
                HStack(spacing: VCSpacing.md) {
                    ForEach(HRZone.all) { zone in
                        HStack(spacing: 3) {
                            Circle().fill(zone.color).frame(width: 6, height: 6)
                            Text(zone.name)
                                .font(.system(size: 9))
                                .foregroundColor(VCColors.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }

    private func zoneColor(_ bpm: Double) -> Color {
        HRZone.zone(for: bpm).color
    }

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .sixHours, .twentyFourHours: return .hour
        case .sevenDays, .thirtyDays:     return .day
        case .ninetyDays:                 return .weekOfYear
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .sixHours, .twentyFourHours: return .dateTime.hour()
        case .sevenDays, .thirtyDays:     return .dateTime.month().day()
        case .ninetyDays:                 return .dateTime.month().day()
        }
    }

    // MARK: HR Zone Bar Chart

    private var zoneBarChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Time in HR Zones")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                let distribution = viewModel?.zoneDistribution() ?? []

                Chart(distribution) { dist in
                    BarMark(
                        x: .value("Zone", dist.zone.abbreviation),
                        y: .value("Minutes", dist.minutes)
                    )
                    .foregroundStyle(dist.zone.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("\(dist.minutes)m")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(dist.zone.color)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 11))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 9))
                    }
                }

                // Percentage row
                HStack(spacing: 0) {
                    ForEach(distribution) { dist in
                        Rectangle()
                            .fill(dist.zone.color.opacity(0.8))
                            .frame(height: 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: CGFloat(dist.percentage), anchor: .leading)
                    }
                }
                .clipShape(Capsule())
                .frame(height: 6)

                HStack(spacing: VCSpacing.md) {
                    ForEach(distribution) { dist in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dist.zone.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(dist.zone.color)
                            Text("\(Int(dist.percentage * 100))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(VCColors.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }

    // MARK: Recovery Card

    private var recoveryCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Recovery Analysis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                VCDivider()

                HStack(spacing: VCSpacing.md) {
                    // Recovery Score donut
                    recoveryDonut
                    // HRV + 1-min recovery stats
                    VStack(alignment: .leading, spacing: VCSpacing.md) {
                        recoveryStatRow(
                            icon: "waveform.path.ecg",
                            label: "HRV (SDNN)",
                            value: String(format: "%.0f ms", viewModel?.hrv ?? 42),
                            color: VCColors.tertiary
                        )
                        VCDivider()
                        recoveryStatRow(
                            icon: "arrow.down.heart",
                            label: "1-min HR Recovery",
                            value: String(format: "%.0f bpm/min", viewModel?.oneMinuteRecovery ?? 18),
                            color: VCColors.safe
                        )
                        VCDivider()
                        recoveryStatRow(
                            icon: "moon.zzz",
                            label: "Overnight Resting",
                            value: "\(Int(viewModel?.restingHR ?? 58)) bpm",
                            color: VCColors.primary
                        )
                    }
                }

                Text("1-minute HR recovery of ≥12 bpm/min is considered normal. HRV ≥40ms indicates good autonomic balance.")
                    .font(.system(size: 11))
                    .foregroundColor(VCColors.outline)
                    .lineSpacing(2)
                    .padding(.top, VCSpacing.xs)
            }
        }
    }

    private var recoveryDonut: some View {
        let score = viewModel?.recoveryScore ?? 0.88
        let color = viewModel?.recoveryColor ?? VCColors.safe

        return VStack(spacing: VCSpacing.xs) {
            ZStack {
                Circle()
                    .stroke(VCColors.surfaceLow, lineWidth: 12)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(score))
                    .stroke(
                        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(Int(score * 100))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                    Text("%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VCColors.outline)
                }
            }
            Text("Recovery")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VCColors.onSurfaceVariant)
            Text("Score")
                .font(.system(size: 9))
                .foregroundColor(VCColors.outline)
        }
    }

    private func recoveryStatRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(VCColors.onSurfaceVariant)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(VCColors.onSurface)
            }
        }
    }

    // MARK: Statistics Strip

    private var statisticsStrip: some View {
        StatisticsStrip(stats: [
            StatStat(label: "Avg", value: viewModel?.avgHR ?? "68", unit: "bpm"),
            StatStat(label: "Min", value: viewModel?.minHR ?? "52", unit: "bpm"),
            StatStat(label: "Max", value: viewModel?.maxHR ?? "138", unit: "bpm"),
            StatStat(label: "Rest", value: viewModel?.restingHRStr ?? "58", unit: "bpm")
        ])
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HeartRateDetailView()
}
#endif
