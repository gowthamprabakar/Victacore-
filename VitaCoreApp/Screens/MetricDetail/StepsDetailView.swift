// StepsDetailView.swift
// VitaCore — Steps Metric Detail Screen
// Displays step count progress, weekly trend chart, movement patterns, and AI insight.

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - ViewModel

@Observable
@MainActor
final class StepsDetailViewModel {
    var readings: [Reading] = []
    var currentSteps: Int = 0
    var goalSteps: Int = 10_000
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            let fetched = try await graphStore.getRangeReadings(
                for: .steps,
                from: Date().addingTimeInterval(-7 * 86_400),
                to: Date()
            )
            self.readings = fetched
            if let latest = try await graphStore.getLatestReading(for: .steps) {
                self.currentSteps = Int(latest.value)
            }
            viewState = .data(())
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - Mock Weekly Data

private struct DailySteps: Identifiable {
    let id = UUID()
    let day: String
    let steps: Int
    let isToday: Bool
}

private let weeklyStepData: [DailySteps] = [
    DailySteps(day: "Mon", steps: 8_420, isToday: false),
    DailySteps(day: "Tue", steps: 9_100, isToday: false),
    DailySteps(day: "Wed", steps: 6_800, isToday: false),
    DailySteps(day: "Thu", steps: 11_200, isToday: false),
    DailySteps(day: "Fri", steps: 7_950, isToday: false),
    DailySteps(day: "Sat", steps: 10_300, isToday: false),
    DailySteps(day: "Sun", steps: 7_520, isToday: true),
]

private struct HourlyActivity: Identifiable {
    let id = UUID()
    let hour: Int
    let steps: Int
}

private let hourlyData: [HourlyActivity] = [
    HourlyActivity(hour: 6,  steps: 320),
    HourlyActivity(hour: 7,  steps: 780),
    HourlyActivity(hour: 8,  steps: 1_100),
    HourlyActivity(hour: 9,  steps: 940),
    HourlyActivity(hour: 10, steps: 420),
    HourlyActivity(hour: 11, steps: 280),
    HourlyActivity(hour: 12, steps: 350),
    HourlyActivity(hour: 13, steps: 190),
    HourlyActivity(hour: 14, steps: 210),
    HourlyActivity(hour: 15, steps: 160),
    HourlyActivity(hour: 16, steps: 380),
    HourlyActivity(hour: 17, steps: 920),
    HourlyActivity(hour: 18, steps: 740),
    HourlyActivity(hour: 19, steps: 290),
    HourlyActivity(hour: 20, steps: 150),
    HourlyActivity(hour: 21, steps: 80),
]

// MARK: - View

struct StepsDetailView: View {
    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: StepsDetailViewModel?
    @State private var timeRange: TimeRange = .sevenDays

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    MetricDetailHeader(
                        title: "Steps",
                        onBack: { dismiss() },
                        onLog: {}
                    )

                    heroSection

                    TimeRangeSelector(selected: $timeRange)

                    goalRingSection

                    weeklyTrendChart

                    StatisticsStrip(stats: [
                        StatStat(label: "Distance", value: "5.2", unit: "km"),
                        StatStat(label: "Calories", value: "280", unit: "kcal"),
                        StatStat(label: "Active",   value: "42",  unit: "min"),
                        StatStat(label: "Avg",      value: "8.2k", unit: "steps"),
                    ])

                    movementPatternCard

                    streakCard

                    AIInsightCard(
                        insightText: "You're most active in the morning. Consider a lunchtime walk to hit your goal consistently."
                    )
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = StepsDetailViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
    }

    // MARK: Hero Section

    private var heroSection: some View {
        GlassCard(style: .hero) {
            VStack(spacing: VCSpacing.sm) {
                HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
                    Text("7,520")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#694ead"))

                    Text("/ 10,000")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                HStack(spacing: VCSpacing.sm) {
                    Text("steps today")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#5d5f65"))

                    TrendArrow(direction: .rising)
                }

                Text("75% of daily goal")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#5d5f65"))
                    .padding(.top, VCSpacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    // MARK: Goal Ring Section

    private var goalRingSection: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.md) {
                Text("Goal Progress")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                GoalRing(
                    label: "75%",
                    current: 7520,
                    target: 10000,
                    accentColor: VCColors.primary,
                    size: 160
                )
                .frame(width: 160, height: 160)

                Text("7,520 of 10,000 steps")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#5d5f65"))
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Weekly Trend Chart

    private var weeklyTrendChart: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Weekly Trend")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                Chart(weeklyStepData) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Steps", item.steps)
                    )
                    .foregroundStyle(
                        item.isToday
                            ? LinearGradient(
                                colors: [Color(hex: "#694ead"), Color(hex: "#a2395f")],
                                startPoint: .bottom,
                                endPoint: .top
                              )
                            : LinearGradient(
                                colors: [Color(hex: "#694ead").opacity(0.5), Color(hex: "#694ead").opacity(0.3)],
                                startPoint: .bottom,
                                endPoint: .top
                              )
                    )
                    .cornerRadius(VCRadius.sm)

                    RuleMark(y: .value("Goal", 10_000))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "#5d5f65").opacity(0.5))
                        .annotation(position: .trailing) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 2_500)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(hex: "#5d5f65").opacity(0.15))
                        AxisValueLabel {
                            if let steps = value.as(Int.self) {
                                Text(steps >= 1_000 ? "\(steps / 1_000)k" : "\(steps)")
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
                .frame(height: 180)
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Movement Pattern Card

    private var movementPatternCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Movement Pattern")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                Chart(hourlyData) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Steps", item.steps)
                    )
                    .foregroundStyle(
                        (item.hour == 8 || item.hour == 9 || item.hour == 17 || item.hour == 18)
                            ? Color(hex: "#694ead")
                            : Color(hex: "#694ead").opacity(0.35)
                    )
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: [6, 9, 12, 15, 18, 21]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(hour < 12 ? "\(hour)am" : (hour == 12 ? "12pm" : "\(hour - 12)pm"))
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 80)

                HStack(spacing: VCSpacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#FFB300"))
                    Text("Most active: 8–10am, 5–6pm")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Streak Card

    private var streakCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                Text("🔥")
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("12 Day Streak")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#313238"))

                    Text("Keep it up — you're on a roll!")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Spacer()

                StatusBadge(band: .safe, text: "Active")
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
    StepsDetailView()
}
