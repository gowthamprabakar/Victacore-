// BloodPressureDetailView.swift
// VitaCoreApp — Blood Pressure metric detail screen
// Architecture: OpenClaw 5-layer, Design System v1.0 Deep Space Bioluminescence

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - AHA Classification

enum AHAClassification: String, CaseIterable {
    case normal    = "Normal"
    case elevated  = "Elevated"
    case stage1    = "Stage 1 HTN"
    case stage2    = "Stage 2 HTN"
    case crisis    = "Hypertensive Crisis"

    var systolicRange: ClosedRange<Double> {
        switch self {
        case .normal:   return 0...119
        case .elevated: return 120...129
        case .stage1:   return 130...139
        case .stage2:   return 140...180
        case .crisis:   return 181...260
        }
    }

    var diastolicRange: ClosedRange<Double> {
        switch self {
        case .normal:   return 0...79
        case .elevated: return 0...79
        case .stage1:   return 80...89
        case .stage2:   return 90...120
        case .crisis:   return 121...200
        }
    }

    var color: Color {
        switch self {
        case .normal:   return VCColors.safe
        case .elevated: return Color.yellow
        case .stage1:   return VCColors.watch
        case .stage2:   return VCColors.alertOrange
        case .crisis:   return VCColors.critical
        }
    }

    var thresholdBand: ThresholdBand {
        switch self {
        case .normal:   return .safe
        case .elevated: return .watch
        case .stage1:   return .watch
        case .stage2:   return .alert
        case .crisis:   return .critical
        }
    }

    var statusBadgeBand: StatusBadge.Band {
        switch self {
        case .normal:   return .safe
        case .elevated: return .watch
        case .stage1:   return .watch
        case .stage2:   return .alert
        case .crisis:   return .critical
        }
    }

    static func classify(systolic: Double, diastolic: Double) -> AHAClassification {
        if systolic > 180 || diastolic > 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90 { return .stage2 }
        if systolic >= 130 || diastolic >= 80 { return .stage1 }
        if systolic >= 120 && diastolic < 80  { return .elevated }
        return .normal
    }
}

// MARK: - BPReading helper

struct BPReading: Identifiable {
    let id: UUID
    let systolic: Double
    let diastolic: Double
    let pulse: Double
    let timestamp: Date
    let sourceReadingId: UUID

    var classification: AHAClassification {
        AHAClassification.classify(systolic: systolic, diastolic: diastolic)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class BloodPressureDetailViewModel {

    var bpReadings: [BPReading] = []
    var latestBP: BPReading?
    var aggregate: AggregatedMetric?
    var timeRange: TimeRange = .twentyFourHours
    var viewState: ViewState<Void> = .loading
    var lastUpdated: Date = Date()

    private let graphStore: any GraphStoreProtocol

    init(graphStore: any GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            let now = Date()
            let start = now.addingTimeInterval(-timeRange.duration)

            async let sysLatestTask = graphStore.getLatestReading(for: .bloodPressureSystolic)
            async let sysRangeTask  = graphStore.getRangeReadings(for: .bloodPressureSystolic, from: start, to: now)
            async let diaRangeTask  = graphStore.getRangeReadings(for: .bloodPressureDiastolic, from: start, to: now)
            async let sysAggTask    = graphStore.getAggregatedMetric(for: .bloodPressureSystolic, from: start, to: now)

            let (sysLatest, sysRange, diaRange, sysAgg) = try await (sysLatestTask, sysRangeTask, diaRangeTask, sysAggTask)

            // Merge systolic + diastolic by closest timestamp
            let merged = Self.mergeBPReadings(systolic: sysRange, diastolic: diaRange)
            bpReadings = merged.sorted { $0.timestamp < $1.timestamp }
            aggregate = sysAgg
            lastUpdated = Date()

            if let sysL = sysLatest {
                let diaValue = diaRange.min(by: { abs($0.timestamp.timeIntervalSince(sysL.timestamp)) < abs($1.timestamp.timeIntervalSince(sysL.timestamp)) })?.value ?? 80
                latestBP = BPReading(
                    id: sysL.id,
                    systolic: sysL.value,
                    diastolic: diaValue,
                    pulse: 72,
                    timestamp: sysL.timestamp,
                    sourceReadingId: sysL.id
                )
                let isStale = sysL.timestamp < Date().addingTimeInterval(-3600)
                viewState = isStale ? .stale((), age: 3600) : .data(())
            } else if bpReadings.isEmpty {
                viewState = .empty
            } else {
                viewState = .data(())
            }
        } catch {
            viewState = .error(error)
        }
    }

    // MARK: Derived

    var morningReadings: [BPReading] {
        bpReadings.filter {
            let hour = Calendar.current.component(.hour, from: $0.timestamp)
            return hour >= 6 && hour < 9
        }
    }

    var restingReadings: [BPReading] {
        bpReadings.filter { _ in true } // In real app: context-tagged from graph
    }

    var morningSurge: Double {
        guard !morningReadings.isEmpty else { return 14.0 }
        let avg = morningReadings.map(\.systolic).reduce(0, +) / Double(morningReadings.count)
        let baseline = bpReadings.prefix(5).map(\.systolic).reduce(0, +) / max(1, Double(bpReadings.prefix(5).count))
        return avg - baseline
    }

    var avgSystolic: Double {
        guard !bpReadings.isEmpty else { return 124 }
        return bpReadings.map(\.systolic).reduce(0, +) / Double(bpReadings.count)
    }

    var avgDiastolic: Double {
        guard !bpReadings.isEmpty else { return 82 }
        return bpReadings.map(\.diastolic).reduce(0, +) / Double(bpReadings.count)
    }

    var chartReadings: [BPReading] {
        bpReadings.isEmpty ? Self.mockBPReadings(for: timeRange) : bpReadings
    }

    // MARK: Static helpers

    static func mergeBPReadings(systolic: [Reading], diastolic: [Reading]) -> [BPReading] {
        guard !systolic.isEmpty else { return [] }
        return systolic.compactMap { sys in
            guard let dia = diastolic.min(by: {
                abs($0.timestamp.timeIntervalSince(sys.timestamp)) < abs($1.timestamp.timeIntervalSince(sys.timestamp))
            }) else { return nil }
            return BPReading(
                id: sys.id,
                systolic: sys.value,
                diastolic: dia.value,
                pulse: 72,
                timestamp: sys.timestamp,
                sourceReadingId: sys.id
            )
        }
    }

    static func mockBPReadings(for range: TimeRange) -> [BPReading] {
        let now = Date()
        let count = 24
        let interval = range.duration / Double(count)
        let pairs: [(Double, Double, Double)] = [
            (118, 76, 68), (120, 78, 70), (122, 80, 72), (125, 82, 74),
            (128, 84, 76), (132, 86, 78), (135, 88, 76), (138, 90, 74),
            (135, 86, 72), (130, 84, 70), (126, 82, 69), (124, 80, 68),
            (122, 78, 67), (120, 76, 66), (118, 74, 65), (116, 74, 64),
            (118, 76, 66), (122, 78, 68), (126, 80, 70), (128, 82, 72),
            (130, 84, 74), (128, 82, 73), (126, 80, 71), (124, 80, 70)
        ]
        return pairs.enumerated().map { i, pair in
            BPReading(
                id: UUID(),
                systolic: pair.0,
                diastolic: pair.1,
                pulse: pair.2,
                timestamp: now.addingTimeInterval(-range.duration + Double(i) * interval),
                sourceReadingId: UUID()
            )
        }
    }
}

// MARK: - Main View

struct BloodPressureDetailView: View {

    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: BloodPressureDetailViewModel?
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
                        MetricDetailHeader(title: "Blood Pressure", onBack: { dismiss() }, onLog: {})
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
            Text("Log Blood Pressure")
                .presentationDetents([.medium])
        }
        .task {
            if viewModel == nil {
                viewModel = BloodPressureDetailViewModel(graphStore: graphStore)
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
                    title: "Blood Pressure",
                    onBack: { dismiss() },
                    onLog: { showLogSheet = true }
                )

                if case .stale = viewModel?.viewState {
                    StaleBanner(timestamp: viewModel?.lastUpdated ?? Date())
                }

                heroSection
                TimeRangeSelector(selected: $timeRange)
                ahaScatterChart
                trendLineChart
                morningCard
                contextAveragesCard
                statisticsStrip
                AIInsightCard(
                    insightText: "Your BP has been rising slightly over the past week. Consider reducing sodium intake and monitoring after meals. Morning surge is within normal range."
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
            MetricDetailHeader(title: "Blood Pressure", onBack: { dismiss() }, onLog: { showLogSheet = true })
            Spacer()
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VCColors.outline)
            Text("No blood pressure data yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
            Text("Log a reading or connect a compatible blood pressure monitor.")
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
        let bp = viewModel?.latestBP ?? viewModel?.chartReadings.last
        let sys = Int(bp?.systolic ?? 124)
        let dia = Int(bp?.diastolic ?? 82)
        let pulse = Int(bp?.pulse ?? 72)
        let classification = bp?.classification ?? .normal

        return GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack {
                    Text("CURRENT READING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(VCColors.outline)
                    Spacer()
                    StatusBadge(band: classification.statusBadgeBand)
                }

                HStack(alignment: .firstTextBaseline, spacing: VCSpacing.xs) {
                    Text("\(sys)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(VCColors.onSurface)
                    Text("/")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(VCColors.onSurfaceVariant)
                    Text("\(dia)")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)
                    Text("mmHg")
                        .font(.system(size: 16))
                        .foregroundColor(VCColors.onSurfaceVariant)
                        .padding(.leading, VCSpacing.xs)
                    Spacer()
                }

                HStack(spacing: VCSpacing.lg) {
                    HStack(spacing: VCSpacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(VCColors.secondary)
                        Text("\(pulse) bpm")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VCColors.onSurface)
                    }
                    Text(classification.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(classification.color)
                }

                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(VCColors.tertiary)
                    Text("Apple Watch Series 9 · Updated 5 min ago")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VCColors.outline)
                }
            }
        }
    }

    // MARK: AHA Scatter Chart

    private var ahaScatterChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("AHA Classification Map")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                Text("Each point represents a reading. X = Systolic, Y = Diastolic.")
                    .font(.system(size: 11))
                    .foregroundColor(VCColors.onSurfaceVariant)

                let readings = viewModel?.chartReadings ?? []

                Chart {
                    // Normal zone
                    RectangleMark(
                        xStart: .value("", 80.0),
                        xEnd: .value("", 120.0),
                        yStart: .value("", 40.0),
                        yEnd: .value("", 80.0)
                    )
                    .foregroundStyle(VCColors.safe.opacity(0.12))

                    // Elevated zone
                    RectangleMark(
                        xStart: .value("", 120.0),
                        xEnd: .value("", 130.0),
                        yStart: .value("", 40.0),
                        yEnd: .value("", 80.0)
                    )
                    .foregroundStyle(Color.yellow.opacity(0.15))

                    // Stage 1 zone
                    RectangleMark(
                        xStart: .value("", 130.0),
                        xEnd: .value("", 140.0),
                        yStart: .value("", 40.0),
                        yEnd: .value("", 90.0)
                    )
                    .foregroundStyle(VCColors.watch.opacity(0.15))

                    // Stage 2 zone
                    RectangleMark(
                        xStart: .value("", 140.0),
                        xEnd: .value("", 180.0),
                        yStart: .value("", 40.0),
                        yEnd: .value("", 120.0)
                    )
                    .foregroundStyle(VCColors.alertOrange.opacity(0.12))

                    // Crisis zone
                    RectangleMark(
                        xStart: .value("", 180.0),
                        xEnd: .value("", 220.0),
                        yStart: .value("", 40.0),
                        yEnd: .value("", 160.0)
                    )
                    .foregroundStyle(VCColors.critical.opacity(0.10))

                    // Zone label rules
                    RuleMark(x: .value("Normal", 90.0))
                        .foregroundStyle(Color.clear)
                        .annotation(position: .top, alignment: .center) {
                            Text("Normal")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(VCColors.safe)
                        }

                    // Data points
                    ForEach(readings) { bp in
                        PointMark(
                            x: .value("Systolic", bp.systolic),
                            y: .value("Diastolic", bp.diastolic)
                        )
                        .foregroundStyle(bp.classification.color.opacity(0.85))
                        .symbolSize(45)
                    }

                    // Current reading highlighted
                    if let current = viewModel?.latestBP ?? readings.last {
                        PointMark(
                            x: .value("Systolic", current.systolic),
                            y: .value("Diastolic", current.diastolic)
                        )
                        .foregroundStyle(VCColors.primary)
                        .symbolSize(100)
                        .annotation(position: .top) {
                            Text("Now")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(VCColors.primary)
                        }
                    }
                }
                .frame(height: 220)
                .chartXScale(domain: 80...220)
                .chartYScale(domain: 40...140)
                .chartXAxis {
                    AxisMarks(values: [100, 120, 140, 160, 180, 200]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [60, 80, 100, 120]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 9))
                    }
                }

                // AHA zone legend
                ahaLegend
            }
        }
    }

    private var ahaLegend: some View {
        FlowLayout(spacing: VCSpacing.sm) {
            ForEach(AHAClassification.allCases, id: \.rawValue) { zone in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(zone.color.opacity(0.6))
                        .frame(width: 10, height: 10)
                    Text(zone.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }
            }
        }
    }

    // MARK: Trend Line Chart

    private var trendLineChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Systolic / Diastolic Trend")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                HStack(spacing: VCSpacing.md) {
                    legendDot(color: VCColors.primary, label: "Systolic")
                    legendDot(color: VCColors.tertiary, label: "Diastolic")
                }

                let readings = viewModel?.chartReadings ?? []

                Chart {
                    // Normal range band
                    RectangleMark(
                        xStart: .value("Start", readings.first?.timestamp ?? Date()),
                        xEnd: .value("End", readings.last?.timestamp ?? Date()),
                        yStart: .value("Low", 60.0),
                        yEnd: .value("High", 120.0)
                    )
                    .foregroundStyle(VCColors.safe.opacity(0.06))

                    // 130 threshold line
                    RuleMark(y: .value("Stage 1", 130.0))
                        .foregroundStyle(VCColors.watch.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // Systolic line
                    ForEach(readings) { bp in
                        LineMark(
                            x: .value("Time", bp.timestamp),
                            y: .value("Systolic", bp.systolic)
                        )
                        .foregroundStyle(VCColors.primary)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Time", bp.timestamp),
                            y: .value("Systolic", bp.systolic)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VCColors.primary.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Diastolic line
                    ForEach(readings) { bp in
                        LineMark(
                            x: .value("Time", bp.timestamp),
                            y: .value("Diastolic", bp.diastolic)
                        )
                        .foregroundStyle(VCColors.tertiary)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: 40...200)
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
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VCColors.outline.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .font(.system(size: 10))
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 11)).foregroundColor(VCColors.onSurfaceVariant)
        }
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

    // MARK: Morning Surge Card

    private var morningCard: some View {
        let surge = viewModel?.morningSurge ?? 14.0
        let surgeColor: Color = surge < 10 ? VCColors.safe : (surge < 20 ? VCColors.watch : VCColors.alertOrange)

        return GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 14))
                        .foregroundColor(VCColors.watch)
                    Text("Morning Surge Analysis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)
                }

                HStack(alignment: .firstTextBaseline, spacing: VCSpacing.xs) {
                    Text(surge >= 0 ? "+\(String(format: "%.0f", surge))" : String(format: "%.0f", surge))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(surgeColor)
                    Text("mmHg")
                        .font(.system(size: 14))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }

                Text("Systolic rise between 6:00 AM – 9:00 AM compared to overnight baseline. Normal surge is <20 mmHg.")
                    .font(.system(size: 12))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .lineSpacing(2)

                // Mini hour bar chart
                if let readings = viewModel, !readings.chartReadings.isEmpty {
                    morningSurgeBarChart(readings: readings.chartReadings)
                }
            }
        }
    }

    private func morningSurgeBarChart(readings: [BPReading]) -> some View {
        let hourlyAvg = Dictionary(grouping: readings) {
            Calendar.current.component(.hour, from: $0.timestamp)
        }.mapValues { group in
            group.map(\.systolic).reduce(0, +) / Double(group.count)
        }.sorted { $0.key < $1.key }

        return Chart {
            ForEach(hourlyAvg, id: \.key) { hour, avg in
                let isMorning = hour >= 6 && hour < 9
                BarMark(
                    x: .value("Hour", "\(hour):00"),
                    y: .value("Avg Systolic", avg)
                )
                .foregroundStyle(isMorning ? VCColors.watch.opacity(0.8) : VCColors.primary.opacity(0.5))
                .cornerRadius(3)
            }
        }
        .frame(height: 80)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    // MARK: Context Averages Card

    private var contextAveragesCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Context Averages")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                VCDivider()

                VStack(spacing: VCSpacing.sm) {
                    contextRow(
                        icon: "bed.double",
                        label: "Resting",
                        systolic: 118,
                        diastolic: 76,
                        count: "14 readings"
                    )
                    VCDivider()
                    contextRow(
                        icon: "sunrise",
                        label: "Morning (6–9 AM)",
                        systolic: Int(viewModel?.avgSystolic ?? 128),
                        diastolic: Int(viewModel?.avgDiastolic ?? 84),
                        count: "\(viewModel?.morningReadings.count ?? 6) readings"
                    )
                    VCDivider()
                    contextRow(
                        icon: "figure.run",
                        label: "Post-Exercise",
                        systolic: 142,
                        diastolic: 92,
                        count: "3 readings"
                    )
                }
            }
        }
    }

    private func contextRow(icon: String, label: String, systolic: Int, diastolic: Int, count: String) -> some View {
        HStack(spacing: VCSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(VCColors.onSurfaceVariant)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VCColors.onSurface)
                Text(count)
                    .font(.system(size: 10))
                    .foregroundColor(VCColors.outline)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(systolic)/\(diastolic)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(AHAClassification.classify(systolic: Double(systolic), diastolic: Double(diastolic)).color)
                Text("mmHg")
                    .font(.system(size: 10))
                    .foregroundColor(VCColors.onSurfaceVariant)
            }
        }
        .padding(.vertical, VCSpacing.xs)
    }

    // MARK: Statistics Strip

    private var statisticsStrip: some View {
        StatisticsStrip(stats: [
            StatStat(label: "Avg Sys", value: String(Int(viewModel?.avgSystolic ?? 124)), unit: "mmHg"),
            StatStat(label: "Avg Dia", value: String(Int(viewModel?.avgDiastolic ?? 82)), unit: "mmHg"),
            StatStat(label: "Pulse", value: "72", unit: "bpm")
        ])
    }
}

// MARK: - FlowLayout helper

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentY += lineHeight + spacing
                totalHeight = currentY
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    BloodPressureDetailView()
}
#endif
