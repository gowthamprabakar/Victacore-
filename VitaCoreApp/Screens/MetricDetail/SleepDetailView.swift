// SleepDetailView.swift
// VitaCore — Sleep Metric Detail Screen
// Critical feature: HYPNOGRAM timeline chart with stage coloured bands.

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - Sleep Stage Model

private enum SleepStage: Int, CaseIterable, Identifiable {
    case deep   = 1
    case light  = 2
    case rem    = 3
    case awake  = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .deep:  return "Deep"
        case .light: return "Light"
        case .rem:   return "REM"
        case .awake: return "Awake"
        }
    }

    var color: Color {
        switch self {
        case .deep:  return Color(hex: "#7C4DFF")
        case .light: return Color(hex: "#006594")   // VCColors.tertiary
        case .rem:   return Color(hex: "#00BFA5")   // VCColors.safe
        case .awake: return Color(hex: "#FF1744")   // VCColors.critical
        }
    }

    var percentage: Double {
        switch self {
        case .deep:  return 0.23
        case .light: return 0.45
        case .rem:   return 0.26
        case .awake: return 0.06
        }
    }
}

// MARK: - Hypnogram Segment

private struct HypnogramSegment: Identifiable {
    let id = UUID()
    let startMinute: Int   // minutes since midnight (23:00 = -60 → use offset from 11pm)
    let endMinute: Int
    let stage: SleepStage
}

/// Converts "h:mm" after 11pm into minutes offset from 11pm.
/// 11pm = 0, midnight = 60, 1am = 120, etc.
private func minutesSince11pm(hour: Int, minute: Int) -> Int {
    let totalMinutes = hour * 60 + minute
    let bedtime = 23 * 60   // 11pm
    return totalMinutes >= bedtime
        ? totalMinutes - bedtime
        : totalMinutes + (24 * 60 - bedtime)
}

private let hypnogramData: [HypnogramSegment] = [
    // 11:00pm → 12:30am  — Light (falling asleep)
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 23, minute: 0),
        endMinute:   minutesSince11pm(hour: 0,  minute: 30),
        stage: .light
    ),
    // 12:30am → 1:15am   — Deep
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 0,  minute: 30),
        endMinute:   minutesSince11pm(hour: 1,  minute: 15),
        stage: .deep
    ),
    // 1:15am → 2:00am    — REM
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 1,  minute: 15),
        endMinute:   minutesSince11pm(hour: 2,  minute: 0),
        stage: .rem
    ),
    // 2:00am → 2:45am    — Light
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 2,  minute: 0),
        endMinute:   minutesSince11pm(hour: 2,  minute: 45),
        stage: .light
    ),
    // 2:45am → 3:15am    — Deep
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 2,  minute: 45),
        endMinute:   minutesSince11pm(hour: 3,  minute: 15),
        stage: .deep
    ),
    // 3:15am → 4:00am    — REM
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 3,  minute: 15),
        endMinute:   minutesSince11pm(hour: 4,  minute: 0),
        stage: .rem
    ),
    // 4:00am → 4:45am    — Light
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 4,  minute: 0),
        endMinute:   minutesSince11pm(hour: 4,  minute: 45),
        stage: .light
    ),
    // 4:45am → 5:30am    — REM
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 4,  minute: 45),
        endMinute:   minutesSince11pm(hour: 5,  minute: 30),
        stage: .rem
    ),
    // 5:30am → 6:20am    — Light
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 5,  minute: 30),
        endMinute:   minutesSince11pm(hour: 6,  minute: 20),
        stage: .light
    ),
    // 6:20am → 6:30am    — Awake
    HypnogramSegment(
        startMinute: minutesSince11pm(hour: 6,  minute: 20),
        endMinute:   minutesSince11pm(hour: 6,  minute: 30),
        stage: .awake
    ),
]

// Total sleep window = 11pm to 6:30am = 450 minutes

// MARK: - Night-by-night debt data

private struct NightSleep: Identifiable {
    let id = UUID()
    let label: String
    let actual: Double    // hours
    let target: Double
}

private let sleepDebtData: [NightSleep] = [
    NightSleep(label: "Mon", actual: 6.5, target: 8.0),
    NightSleep(label: "Tue", actual: 7.8, target: 8.0),
    NightSleep(label: "Wed", actual: 5.9, target: 8.0),
    NightSleep(label: "Thu", actual: 8.3, target: 8.0),
    NightSleep(label: "Fri", actual: 7.1, target: 8.0),
    NightSleep(label: "Sat", actual: 8.5, target: 8.0),
    NightSleep(label: "Sun", actual: 7.2, target: 8.0),
]

// MARK: - Sleep Score Factor

private struct ScoreFactor: Identifiable {
    let id = UUID()
    let label: String
    let score: Int
    let color: Color
}

private let sleepScoreFactors: [ScoreFactor] = [
    ScoreFactor(label: "Duration",   score: 92, color: Color(hex: "#694ead")),
    ScoreFactor(label: "Efficiency", score: 85, color: Color(hex: "#006594")),
    ScoreFactor(label: "Stages",     score: 88, color: Color(hex: "#00BFA5")),
]

// MARK: - ViewModel

@Observable
@MainActor
final class SleepDetailViewModel {
    var readings: [Reading] = []
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            let fetched = try await graphStore.getRangeReadings(
                for: .sleep,
                from: Date().addingTimeInterval(-7 * 86_400),
                to: Date()
            )
            self.readings = fetched
            viewState = .data(())
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - View

struct SleepDetailView: View {
    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: SleepDetailViewModel?
    @State private var timeRange: TimeRange = .sevenDays

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    MetricDetailHeader(
                        title: "Sleep",
                        onBack: { dismiss() },
                        onLog: {}
                    )

                    heroSection

                    TimeRangeSelector(selected: $timeRange)

                    hypnogramCard

                    stageBreakdownCard

                    respiratoryRateCard

                    sleepDebtCard

                    sleepScoreCard

                    AIInsightCard(
                        insightText: "Your deep sleep has improved 18% this week. Consistent bedtime around 11pm is working well."
                    )
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = SleepDetailViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
    }

    // MARK: Hero Section

    private var heroSection: some View {
        GlassCard(style: .hero) {
            VStack(spacing: VCSpacing.sm) {
                HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
                    Text("7h 12m")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#694ead"))

                    StatusBadge(band: .safe, text: "88% eff.")
                }

                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(hex: "#694ead"))
                    Text("Good sleep")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }
                .padding(.top, VCSpacing.xs)

                HStack(spacing: VCSpacing.xxxl) {
                    sleepStat(value: "11:03pm", label: "Bedtime")
                    sleepStat(value: "6:15am",  label: "Wake time")
                    sleepStat(value: "14 min",  label: "Latency")
                }
                .padding(.top, VCSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    private func sleepStat(value: String, label: String) -> some View {
        VStack(spacing: VCSpacing.xs) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#313238"))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(hex: "#5d5f65"))
        }
    }

    // MARK: Hypnogram Chart (CRITICAL)

    private var hypnogramCard: some View {
        GlassCard(style: .enhanced) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Last Night")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))
                    Spacer()
                    Text("Hypnogram")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                // HYPNOGRAM — RectangleMark per stage segment
                // X: minutes offset from 11pm (0–450 = 11pm–6:30am)
                // Y: SleepStage.rawValue (1=Deep…4=Awake)
                Chart(hypnogramData) { segment in
                    RectangleMark(
                        xStart: .value("Start", segment.startMinute),
                        xEnd:   .value("End",   segment.endMinute),
                        yStart: .value("Stage", Double(segment.stage.rawValue) - 0.42),
                        yEnd:   .value("Stage", Double(segment.stage.rawValue) + 0.42)
                    )
                    .foregroundStyle(segment.stage.color.opacity(segment.stage == .awake ? 0.9 : 0.80))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    // Show labels at key hours: 11pm(0), 1am(120), 3am(240), 5am(360), 6:30am(450)
                    AxisMarks(values: [0, 60, 120, 180, 240, 300, 360, 420, 450]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(hex: "#5d5f65").opacity(0.12))
                        AxisValueLabel {
                            if let minutes = value.as(Int.self) {
                                Text(minuteLabel(for: minutes))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4]) { value in
                        AxisValueLabel {
                            if let stage = value.as(Int.self),
                               let s = SleepStage(rawValue: stage) {
                                Text(s.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(s.color)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0.3...4.7)
                .frame(height: 180)

                // Stage colour legend
                HStack(spacing: VCSpacing.lg) {
                    ForEach(SleepStage.allCases) { stage in
                        HStack(spacing: VCSpacing.xs) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stage.color)
                                .frame(width: 12, height: 10)
                            Text(stage.label)
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                        }
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    /// Converts a minutes-since-11pm offset back to a readable time label.
    private func minuteLabel(for offset: Int) -> String {
        let totalMinutes = (23 * 60 + offset) % (24 * 60)
        let hour = totalMinutes / 60
        let min  = totalMinutes % 60
        let period = hour < 12 ? "am" : "pm"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if min == 0 {
            return "\(displayHour)\(period)"
        } else {
            return "\(displayHour):\(String(format: "%02d", min))\(period)"
        }
    }

    // MARK: Stage Breakdown Card

    private var stageBreakdownCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Sleep Stages")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                ForEach(SleepStage.allCases) { stage in
                    VStack(spacing: VCSpacing.xs) {
                        HStack {
                            Circle()
                                .fill(stage.color)
                                .frame(width: 10, height: 10)
                            Text(stage.label)
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "#313238"))
                            Spacer()
                            Text("\(Int(stage.percentage * 100))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(hex: "#313238"))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: VCRadius.sm)
                                    .fill(Color(hex: "#5d5f65").opacity(0.1))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: VCRadius.sm)
                                    .fill(stage.color)
                                    .frame(width: geo.size.width * stage.percentage, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Respiratory Rate Card

    private var respiratoryRateCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.lg) {
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Respiratory Rate")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))

                    HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
                        Text("14.2")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#006594"))
                        Text("breaths/min")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#5d5f65"))
                    }

                    Text("Normal range: 12–20")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Spacer()

                SparklineChart(
                    values: [13.8, 14.5, 14.1, 15.0, 13.9, 14.4, 14.2],
                    safeBandRange: nil,
                    accentColor: VCColors.tertiary,
                    height: 50
                )
                .frame(width: 100, height: 50)
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Sleep Debt Card

    private var sleepDebtCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    Text("Sleep Debt Tracker")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#313238"))
                    Spacer()
                    Text("7-day rolling")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Chart(sleepDebtData) { night in
                    // Target bar (background)
                    BarMark(
                        x: .value("Day", night.label),
                        y: .value("Target", night.target)
                    )
                    .foregroundStyle(Color(hex: "#5d5f65").opacity(0.12))
                    .cornerRadius(VCRadius.sm)

                    // Actual bar
                    BarMark(
                        x: .value("Day", night.label),
                        y: .value("Actual", night.actual)
                    )
                    .foregroundStyle(
                        night.actual >= night.target
                            ? Color(hex: "#00BFA5").opacity(0.85)
                            : Color(hex: "#FF6B00").opacity(0.85)
                    )
                    .cornerRadius(VCRadius.sm)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 4, 6, 8]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(hex: "#5d5f65").opacity(0.12))
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text("\(Int(h))h")
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .frame(height: 140)

                HStack(spacing: VCSpacing.lg) {
                    HStack(spacing: VCSpacing.xs) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#00BFA5"))
                            .frame(width: 14, height: 8)
                        Text("Met target")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#5d5f65"))
                    }
                    HStack(spacing: VCSpacing.xs) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#FF6B00"))
                            .frame(width: 14, height: 8)
                        Text("Sleep debt")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#5d5f65"))
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Sleep Score Card

    private var sleepScoreCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.lg) {
                Text("Sleep Score")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: VCSpacing.xxxl) {
                    // Big circular score
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#5d5f65").opacity(0.15), lineWidth: 10)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: 0.88)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#694ead"), Color(hex: "#00BFA5")],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("88")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#313238"))
                            Text("/100")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                        }
                    }

                    // Factor list
                    VStack(alignment: .leading, spacing: VCSpacing.sm) {
                        ForEach(sleepScoreFactors) { factor in
                            HStack(spacing: VCSpacing.sm) {
                                Circle()
                                    .fill(factor.color)
                                    .frame(width: 8, height: 8)
                                Text(factor.label)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                                Spacer()
                                Text("\(factor.score)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color(hex: "#313238"))
                            }
                        }
                    }
                }
            }
            .padding(VCSpacing.xxl)
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
    SleepDetailView()
}
