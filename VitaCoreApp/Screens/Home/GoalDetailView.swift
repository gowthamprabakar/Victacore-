// GoalDetailView.swift
// VitaCore — Goal Detail Screen
// Critical feature: 3 concentric rings (Steps / Fluid / TIR) using Circle().trim().

import SwiftUI
import Charts
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - Goal Data Models

private struct GoalItem: Identifiable {
    let id = UUID()
    let title: String
    let current: String
    let target: String
    let unit: String
    let progress: Double
    let status: String
    let isExceeding: Bool
    let color: Color
    let icon: String
}

private let goalItems: [GoalItem] = [
    GoalItem(
        title: "Steps",
        current: "7,520",
        target: "10,000",
        unit: "steps",
        progress: 0.75,
        status: "75% complete",
        isExceeding: false,
        color: Color(hex: "#694ead"),
        icon: "figure.walk"
    ),
    GoalItem(
        title: "Fluid",
        current: "1,200",
        target: "2,500",
        unit: "mL",
        progress: 0.48,
        status: "48% complete",
        isExceeding: false,
        color: Color(hex: "#006594"),
        icon: "drop.fill"
    ),
    GoalItem(
        title: "TIR",
        current: "84%",
        target: "80%",
        unit: "target",
        progress: 1.0,
        status: "Exceeding!",
        isExceeding: true,
        color: Color(hex: "#a2395f"),
        icon: "chart.xyaxis.line"
    ),
]

// MARK: - 30-Day Completion Data

private struct DailyCompletion: Identifiable {
    let id = UUID()
    let day: Int
    let rate: Double   // 0–1
}

private let thirtyDayData: [DailyCompletion] = (1...30).map { day in
    DailyCompletion(day: day, rate: Double.random(in: 0.4...1.0))
}

// MARK: - Weekly Grid Model

private struct WeekDay: Identifiable {
    let id = UUID()
    let label: String
    let stepsComplete: Bool
    let fluidComplete: Bool
    let tirComplete: Bool
}

private let weekGrid: [WeekDay] = [
    WeekDay(label: "Mon", stepsComplete: true,  fluidComplete: true,  tirComplete: true),
    WeekDay(label: "Tue", stepsComplete: true,  fluidComplete: false, tirComplete: true),
    WeekDay(label: "Wed", stepsComplete: false, fluidComplete: true,  tirComplete: true),
    WeekDay(label: "Thu", stepsComplete: true,  fluidComplete: true,  tirComplete: true),
    WeekDay(label: "Fri", stepsComplete: true,  fluidComplete: true,  tirComplete: false),
    WeekDay(label: "Sat", stepsComplete: true,  fluidComplete: true,  tirComplete: true),
    WeekDay(label: "Sun", stepsComplete: true,  fluidComplete: false, tirComplete: true),
]

// MARK: - AI Strategy Model

private struct AIStrategy: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
}

private let strategies: [AIStrategy] = [
    AIStrategy(
        title: "Micro-Intervals",
        detail: "Break steps into 3 × 2,500-step blocks throughout the day to hit your target effortlessly.",
        icon: "bolt.fill",
        color: Color(hex: "#694ead")
    ),
    AIStrategy(
        title: "Afternoon Velocity",
        detail: "Your 3pm window is underutilised — add a 10-min walk to boost both steps and fluid intake.",
        icon: "clock.arrow.2.circlepath",
        color: Color(hex: "#006594")
    ),
]

// MARK: - ViewModel

@Observable
@MainActor
final class GoalDetailViewModel {
    var goalProgress: [GoalProgress] = []
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            _ = try await graphStore.getRangeReadings(
                for: .steps,
                from: Date().addingTimeInterval(-30 * 86_400),
                to: Date()
            )
            viewState = .data(())
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - View

struct GoalDetailView: View {
    @Environment(\.graphStore) var graphStore
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: GoalDetailViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    MetricDetailHeader(
                        title: "Your Goals",
                        onBack: { dismiss() },
                        onLog: {}
                    )

                    concentricRingsSection

                    goalCardsSection

                    progressOverTimeCard

                    weeklyConsistencyCard

                    aiStrategySection

                    streakCard
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = GoalDetailViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
    }

    // MARK: Concentric Rings (CRITICAL — 3 rings)

    private var concentricRingsSection: some View {
        GlassCard(style: .hero) {
            VStack(spacing: VCSpacing.lg) {
                Text("Today's Goals")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                ZStack {
                    // ─── Outer ring — Steps (220pt, primary purple) ───
                    Circle()
                        .stroke(Color(hex: "#694ead").opacity(0.15), lineWidth: 16)
                        .frame(width: 220, height: 220)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            Color(hex: "#694ead"),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))

                    // ─── Middle ring — Fluid (170pt, tertiary teal) ───
                    Circle()
                        .stroke(Color(hex: "#006594").opacity(0.15), lineWidth: 16)
                        .frame(width: 170, height: 170)
                    Circle()
                        .trim(from: 0, to: 0.48)
                        .stroke(
                            Color(hex: "#006594"),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 170, height: 170)
                        .rotationEffect(.degrees(-90))

                    // ─── Inner ring — TIR (120pt, secondary rose) ───
                    Circle()
                        .stroke(Color(hex: "#a2395f").opacity(0.15), lineWidth: 16)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: 0.84)
                        .stroke(
                            Color(hex: "#a2395f"),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    // ─── Centre label ───
                    VStack(spacing: 2) {
                        Text("12")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#313238"))
                        Text("day streak")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "#5d5f65"))
                    }
                }
                .frame(width: 260, height: 260)

                // Ring legend
                HStack(spacing: VCSpacing.xl) {
                    ringLegendItem(color: Color(hex: "#694ead"), label: "Steps",  value: "75%")
                    ringLegendItem(color: Color(hex: "#006594"), label: "Fluid",  value: "48%")
                    ringLegendItem(color: Color(hex: "#a2395f"), label: "TIR",    value: "84%")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    private func ringLegendItem(color: Color, label: String, value: String) -> some View {
        VStack(spacing: VCSpacing.xs) {
            HStack(spacing: VCSpacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#5d5f65"))
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#313238"))
        }
    }

    // MARK: Individual Goal Cards

    private var goalCardsSection: some View {
        VStack(spacing: VCSpacing.md) {
            ForEach(goalItems) { item in
                goalCard(item: item)
            }
        }
    }

    private func goalCard(item: GoalItem) -> some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(item.color)
                }

                // Info
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#313238"))
                        Spacer()
                        if item.isExceeding {
                            StatusBadge(band: .safe, text: "Exceeding!")
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
                        Text(item.current)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(item.color)
                        Text("/ \(item.target) \(item.unit)")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#5d5f65"))
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: VCRadius.sm)
                                .fill(Color(hex: "#5d5f65").opacity(0.12))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: VCRadius.sm)
                                .fill(item.color)
                                .frame(
                                    width: min(geo.size.width * item.progress, geo.size.width),
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(VCSpacing.lg)
        }
    }

    // MARK: Progress Over Time Chart

    private var progressOverTimeCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("30-Day Completion Rate")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                Chart(thirtyDayData) { day in
                    AreaMark(
                        x: .value("Day", day.day),
                        y: .value("Rate", day.rate)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#694ead").opacity(0.4),
                                Color(hex: "#694ead").opacity(0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", day.day),
                        y: .value("Rate", day.rate)
                    )
                    .foregroundStyle(Color(hex: "#694ead"))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    RuleMark(y: .value("Target", 0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "#5d5f65").opacity(0.5))
                }
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(hex: "#5d5f65").opacity(0.12))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [1, 8, 15, 22, 30]) { value in
                        AxisValueLabel {
                            if let d = value.as(Int.self) {
                                Text("Day \(d)")
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#5d5f65"))
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: Weekly Consistency Grid

    private var weeklyConsistencyCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                Text("Weekly Consistency")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#313238"))

                // Header row
                HStack(spacing: 0) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                        .frame(width: 50, alignment: .leading)
                    ForEach(weekGrid) { day in
                        Text(day.label)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#5d5f65"))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Steps row
                consistencyRow(label: "Steps", color: Color(hex: "#694ead"), values: weekGrid.map(\.stepsComplete))

                // Fluid row
                consistencyRow(label: "Fluid", color: Color(hex: "#006594"), values: weekGrid.map(\.fluidComplete))

                // TIR row
                consistencyRow(label: "TIR", color: Color(hex: "#a2395f"), values: weekGrid.map(\.tirComplete))
            }
            .padding(VCSpacing.xxl)
        }
    }

    private func consistencyRow(label: String, color: Color, values: [Bool]) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(hex: "#5d5f65"))
                .frame(width: 50, alignment: .leading)

            ForEach(Array(values.enumerated()), id: \.offset) { _, completed in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(completed ? color.opacity(0.85) : Color(hex: "#5d5f65").opacity(0.12))
                        .frame(width: 28, height: 28)

                    if completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: AI Strategy Section

    private var aiStrategySection: some View {
        VStack(alignment: .leading, spacing: VCSpacing.md) {
            Text("AI Strategies")
                .font(.headline)
                .foregroundStyle(Color(hex: "#313238"))
                .padding(.horizontal, VCSpacing.xs)

            ForEach(strategies) { strategy in
                GlassCard(style: .small) {
                    HStack(alignment: .top, spacing: VCSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(strategy.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: strategy.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(strategy.color)
                        }

                        VStack(alignment: .leading, spacing: VCSpacing.xs) {
                            Text(strategy.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(hex: "#313238"))
                            Text(strategy.detail)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#5d5f65"))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(VCSpacing.lg)
                }
            }
        }
    }

    // MARK: Streak Card

    private var streakCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                Text("🔥")
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Current Streak: 12 days")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#313238"))
                    Text("You've hit all 3 goals for 12 consecutive days")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#5d5f65"))
                }

                Spacer()
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
    GoalDetailView()
}
