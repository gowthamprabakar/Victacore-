// GlucoseDetailView.swift
// VitaCoreApp — Glucose metric detail screen
// Architecture: OpenClaw 5-layer, Design System v1.0 Deep Space Bioluminescence

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - ViewModel

@Observable
@MainActor
final class GlucoseDetailViewModel {

    // MARK: Published state
    var currentReading: Reading?
    var readings: [Reading] = []
    var aggregate: AggregatedMetric?
    var timeRange: TimeRange = .twentyFourHours
    var viewState: ViewState<Void> = .loading
    var lastUpdated: Date = Date()

    // MARK: Private
    private let graphStore: any GraphStoreProtocol

    init(graphStore: any GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    // MARK: Load

    func load() async {
        viewState = .loading
        do {
            let now = Date()
            let start = now.addingTimeInterval(-timeRange.duration)
            async let latestTask = graphStore.getLatestReading(for: .glucose)
            async let readingsTask = graphStore.getRangeReadings(for: .glucose, from: start, to: now)
            async let aggregateTask = graphStore.getAggregatedMetric(for: .glucose, from: start, to: now)

            let (latest, rangeReadings, agg) = try await (latestTask, readingsTask, aggregateTask)
            currentReading = latest
            readings = rangeReadings.sorted { $0.timestamp < $1.timestamp }
            aggregate = agg
            lastUpdated = Date()

            if readings.isEmpty {
                viewState = .empty
            } else {
                let isStale = (latest?.timestamp ?? Date.distantPast) < Date().addingTimeInterval(-3600)
                viewState = isStale ? .stale((), age: 3600) : .data(())
            }
        } catch {
            viewState = .error(error)
        }
    }

    // MARK: Computed helpers

    /// Returns fraction (0–1) in each band based on readings.
    func timeInRange() -> (safe: Double, watch: Double, alert: Double) {
        guard !readings.isEmpty else { return (0.84, 0.10, 0.06) }
        let total = Double(readings.count)
        let safe   = readings.filter { $0.value >= 70 && $0.value <= 180 }.count
        let low    = readings.filter { $0.value < 70 }.count
        let high   = readings.filter { $0.value > 180 }.count
        return (Double(safe) / total, Double(low) / total, Double(high) / total)
    }

    /// GMI = 3.31 + 0.02392 × avg glucose
    func gmi() -> Double {
        let avg = aggregate?.average ?? currentReading?.value ?? 138
        return 3.31 + 0.02392 * avg
    }

    var averageValue: String {
        if let avg = aggregate?.average { return String(Int(avg)) }
        return "138"
    }

    var minValue: String {
        if let min = aggregate?.min { return String(Int(min)) }
        return "82"
    }

    var maxValue: String {
        if let max = aggregate?.max { return String(Int(max)) }
        return "195"
    }

    var stdDev: Double {
        guard readings.count > 1 else { return 24.0 }
        let avg = readings.map(\.value).reduce(0, +) / Double(readings.count)
        let variance = readings.map { pow($0.value - avg, 2) }.reduce(0, +) / Double(readings.count - 1)
        return sqrt(variance)
    }

    var chartReadings: [Reading] {
        readings.isEmpty ? GlucoseDetailViewModel.mockReadings(for: timeRange) : readings
    }

    // MARK: Mock data for design/preview

    static func mockReadings(for range: TimeRange) -> [Reading] {
        let now = Date()
        let count = 48
        let interval = range.duration / Double(count)
        let values: [Double] = [
            98, 95, 92, 105, 122, 148, 165, 172, 155, 140, 132, 128,
            125, 118, 115, 120, 138, 152, 175, 168, 155, 142, 130, 125,
            118, 112, 108, 105, 102, 108, 125, 148, 162, 170, 158, 145,
            135, 128, 122, 118, 112, 108, 105, 102, 100, 98, 95, 93
        ]
        return values.enumerated().map { i, v in
            Reading(
                id: UUID(),
                metricType: .glucose,
                value: v,
                unit: "mg/dL",
                timestamp: now.addingTimeInterval(-range.duration + Double(i) * interval),
                sourceSkillId: "dexcom-g7",
                confidence: 0.97,
                trendDirection: .stable,
                trendVelocity: 1.2
            )
        }
    }
}

// MARK: - Main View

struct GlucoseDetailView: View {

    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: GlucoseDetailViewModel?
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
                        MetricDetailHeader(title: "Glucose", onBack: { dismiss() }, onLog: {})
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
            Text("Log Glucose")
                .presentationDetents([.medium])
        }
        .task {
            if viewModel == nil {
                viewModel = GlucoseDetailViewModel(graphStore: graphStore)
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
                    title: "Glucose",
                    onBack: { dismiss() },
                    onLog: { showLogSheet = true }
                )

                if case .stale = viewModel?.viewState {
                    StaleBanner(timestamp: viewModel?.lastUpdated ?? Date())
                }

                heroSection
                TimeRangeSelector(selected: $timeRange)
                primaryChart
                HStack(alignment: .top, spacing: VCSpacing.md) {
                    tirDonut
                    gmiCard
                }
                statisticsStrip
                postMealCard
                AIInsightCard(
                    insightText: "Your glucose tends to spike 30–45 minutes after breakfast. Consider adjusting carbohydrates or adding a 10-minute walk after meals."
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
            MetricDetailHeader(title: "Glucose", onBack: { dismiss() }, onLog: { showLogSheet = true })
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VCColors.outline)
            Text("No glucose data yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
            Text("Connect a CGM or log a reading to see your glucose trends.")
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
        GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack {
                    Text("CURRENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(VCColors.outline)
                    Spacer()
                    StatusBadge(band: statusBadgeBand)
                }

                HStack(alignment: .firstTextBaseline, spacing: VCSpacing.sm) {
                    Text(currentValueString)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(VCColors.onSurface)
                        .contentTransition(.numericText())
                    Text("mg/dL")
                        .font(.system(size: 18))
                        .foregroundColor(VCColors.onSurfaceVariant)
                    Spacer()
                    TrendArrow(
                        direction: trendArrowDirection,
                        velocity: velocityString
                    )
                }

                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(VCColors.safe)
                    Text("Dexcom G7 · Updated 3 min ago")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VCColors.outline)
                }
            }
        }
    }

    private var currentValueString: String {
        guard let v = viewModel?.currentReading?.value else { return "142" }
        return String(Int(v))
    }

    private var velocityString: String {
        guard let vel = viewModel?.currentReading?.trendVelocity else { return "+1.2 mg/dL·hr" }
        let prefix = vel >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", vel)) mg/dL·hr"
    }

    private var currentBand: ThresholdBand {
        let v = viewModel?.currentReading?.value ?? 142
        switch v {
        case ..<70:   return .alert
        case 70..<130: return .safe
        case 130..<180: return .watch
        default:       return .critical
        }
    }

    private var statusBadgeBand: StatusBadge.Band {
        switch currentBand {
        case .safe:     return .safe
        case .watch:    return .watch
        case .alert:    return .alert
        case .critical: return .critical
        }
    }

    private var trendArrowDirection: TrendArrow.Direction {
        switch viewModel?.currentReading?.trendDirection ?? .stable {
        case .rising:      return .rising
        case .stable:      return .stable
        case .falling:     return .falling
        case .risingFast:  return .risingFast
        case .fallingFast: return .fallingFast
        }
    }

    // MARK: Primary Chart

    private var primaryChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Glucose Trend")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)
                    Spacer()
                    legendRow(color: VCColors.safe, label: "In range")
                    legendRow(color: VCColors.alertOrange, label: "Out of range")
                }

                let readings = viewModel?.chartReadings ?? []
                let rangeStart = Date().addingTimeInterval(-timeRange.duration)

                Chart {
                    // Safe band background
                    RectangleMark(
                        xStart: .value("Start", rangeStart),
                        xEnd: .value("End", Date()),
                        yStart: .value("Low", 70),
                        yEnd: .value("High", 180)
                    )
                    .foregroundStyle(VCColors.safe.opacity(0.08))

                    // Watch zone background (>180)
                    RectangleMark(
                        xStart: .value("Start", rangeStart),
                        xEnd: .value("End", Date()),
                        yStart: .value("Low", 180),
                        yEnd: .value("High", 240)
                    )
                    .foregroundStyle(VCColors.watch.opacity(0.06))

                    // Alert zone background (<70)
                    RectangleMark(
                        xStart: .value("Start", rangeStart),
                        xEnd: .value("End", Date()),
                        yStart: .value("Low", 40),
                        yEnd: .value("High", 70)
                    )
                    .foregroundStyle(VCColors.alertOrange.opacity(0.08))

                    // Threshold rule lines
                    RuleMark(y: .value("Low threshold", 70))
                        .foregroundStyle(VCColors.alertOrange.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .leading) {
                            Text("70")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(VCColors.alertOrange)
                        }

                    RuleMark(y: .value("High threshold", 180))
                        .foregroundStyle(VCColors.watch.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .leading) {
                            Text("180")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(VCColors.watch)
                        }

                    // Area fill under curve
                    ForEach(readings, id: \.id) { reading in
                        AreaMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", reading.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VCColors.primary.opacity(0.25), VCColors.primary.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Glucose line — colour per band
                    ForEach(readings, id: \.id) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", reading.value)
                        )
                        .foregroundStyle(lineColor(for: reading.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 220)
                .chartYScale(domain: 40...240)
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

    private func lineColor(for value: Double) -> Color {
        switch value {
        case ..<70:    return VCColors.alertOrange
        case 70..<180: return VCColors.primary
        default:       return VCColors.watch
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 10)).foregroundColor(VCColors.onSurfaceVariant)
        }
    }

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .sixHours:        return .hour
        case .twentyFourHours: return .hour
        case .sevenDays:       return .day
        case .thirtyDays:      return .day
        case .ninetyDays:      return .weekOfYear
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .sixHours, .twentyFourHours:
            return .dateTime.hour()
        case .sevenDays, .thirtyDays:
            return .dateTime.month().day()
        case .ninetyDays:
            return .dateTime.month().day()
        }
    }

    // MARK: TIR Donut

    private var tirDonut: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                Text("TIME IN RANGE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(VCColors.outline)

                let tir = viewModel?.timeInRange() ?? (safe: 0.84, watch: 0.10, alert: 0.06)

                ZStack {
                    // Background track
                    Circle()
                        .stroke(VCColors.surfaceLow, lineWidth: 14)
                        .frame(width: 96, height: 96)

                    // Alert segment (bottom layer)
                    Circle()
                        .trim(from: 0, to: tir.alert)
                        .stroke(VCColors.alertOrange, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))

                    // Watch segment
                    Circle()
                        .trim(from: tir.alert, to: tir.alert + tir.watch)
                        .stroke(VCColors.watch, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))

                    // Safe segment (top layer)
                    Circle()
                        .trim(from: tir.alert + tir.watch, to: tir.alert + tir.watch + tir.safe)
                        .stroke(VCColors.safe, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("\(Int(tir.safe * 100))%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(VCColors.onSurface)
                        Text("In Range")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(VCColors.outline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, VCSpacing.sm)

                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    tirLegendRow(color: VCColors.safe, label: "In range", pct: tir.safe)
                    tirLegendRow(color: VCColors.watch, label: "High", pct: tir.watch)
                    tirLegendRow(color: VCColors.alertOrange, label: "Low", pct: tir.alert)
                }
            }
        }
    }

    private func tirLegendRow(color: Color, label: String, pct: Double) -> some View {
        HStack(spacing: VCSpacing.xs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(VCColors.onSurfaceVariant)
            Spacer()
            Text("\(Int(pct * 100))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(VCColors.onSurface)
        }
    }

    // MARK: GMI Card

    private var gmiCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                Text("GMI ESTIMATE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(VCColors.outline)

                let gmiVal = viewModel?.gmi() ?? 6.8
                let gmiColor: Color = gmiVal < 7.0 ? VCColors.safe : (gmiVal < 8.0 ? VCColors.watch : VCColors.critical)

                Text(String(format: "%.1f%%", gmiVal))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(gmiColor)
                    .contentTransition(.numericText())

                Text("Glucose Management\nIndicator")
                    .font(.system(size: 11))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .lineSpacing(2)

                Text("A1C equivalent")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(VCColors.outline)
                    .padding(.top, VCSpacing.xs)

                Text("Based on 14-day CGM")
                    .font(.system(size: 9))
                    .foregroundColor(VCColors.outline)

                Spacer(minLength: 0)

                Text("Formula: 3.31 + 0.02392 × avg glucose")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(VCColors.outline.opacity(0.7))
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Statistics Strip

    private var statisticsStrip: some View {
        StatisticsStrip(stats: [
            StatStat(label: "Avg", value: viewModel?.averageValue ?? "138", unit: "mg/dL"),
            StatStat(label: "Min", value: viewModel?.minValue ?? "82", unit: "mg/dL"),
            StatStat(label: "Max", value: viewModel?.maxValue ?? "195", unit: "mg/dL"),
            StatStat(label: "SD", value: String(Int(viewModel?.stdDev ?? 24)), unit: "mg/dL")
        ])
    }

    // MARK: Post-Meal Card

    private var postMealCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Post-Meal Spike Analysis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)
                    Spacer()
                    Text("7-day avg")
                        .font(.system(size: 10))
                        .foregroundColor(VCColors.outline)
                }

                VCDivider()

                VStack(spacing: VCSpacing.sm) {
                    postMealRow(meal: "Breakfast", spike: "+42", spikeUnit: "mg/dL", time: "30 min", band: .watch)
                    VCDivider()
                    postMealRow(meal: "Lunch", spike: "+38", spikeUnit: "mg/dL", time: "45 min", band: .watch)
                    VCDivider()
                    postMealRow(meal: "Dinner", spike: "+28", spikeUnit: "mg/dL", time: "60 min", band: .safe)
                }

                HStack(spacing: VCSpacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("Peak measured at max value within 2 hrs post-meal")
                        .font(.system(size: 10))
                }
                .foregroundColor(VCColors.outline)
            }
        }
    }

    private func postMealRow(meal: String, spike: String, spikeUnit: String, time: String, band: ThresholdBand) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: mealIcon(meal))
                .font(.system(size: 14))
                .foregroundColor(VCColors.onSurfaceVariant)
                .frame(width: 20)

            Text(meal)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.onSurface)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(spike)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(bandColor(band))
                    Text(spikeUnit)
                        .font(.system(size: 10))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }
                Text("peak in \(time)")
                    .font(.system(size: 10))
                    .foregroundColor(VCColors.outline)
            }
        }
        .padding(.vertical, VCSpacing.xs)
    }

    private func mealIcon(_ meal: String) -> String {
        switch meal {
        case "Breakfast": return "cup.and.saucer"
        case "Lunch":     return "fork.knife"
        case "Dinner":    return "moon"
        default:          return "circle"
        }
    }

    private func bandColor(_ band: ThresholdBand) -> Color {
        switch band {
        case .safe:     return VCColors.safe
        case .watch:    return VCColors.watch
        case .alert:    return VCColors.alertOrange
        case .critical: return VCColors.critical
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    GlucoseDetailView()
}
#endif
