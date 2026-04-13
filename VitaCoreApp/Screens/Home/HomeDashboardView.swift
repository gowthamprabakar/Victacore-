// HomeDashboardView.swift
// VitaCore — Home Dashboard (Tab 1)
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Architecture: 5-layer OpenClaw | Sprint Phase 1

import SwiftUI
import UserNotifications
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - Home Dashboard View

struct HomeDashboardView: View {

    // MARK: Environment

    @Environment(\.graphStore)        var graphStore
    @Environment(\.personaEngine)     var personaEngine
    @Environment(\.inferenceProvider) var inferenceProvider
    @Environment(\.alertRouter)       var alertRouter
    @Environment(NavigationRouter.self) var navRouter
    @Environment(TabRouter.self)        var tabRouter

    // MARK: State

    @State private var viewModel: HomeDashboardViewModel?
    @State private var pulseScale: CGFloat = 1.0
    @State private var intelligenceDotOpacity: Double = 1.0
    @State private var scrollOffset: CGFloat = 0

    // MARK: Body

    var body: some View {
        ZStack {
            // ── Layer 0: Animated background mesh ──
            BackgroundMesh()
                .ignoresSafeArea()

            // ── Layer 1: Content ──
            switch viewModel?.viewState {
            case .loading, .none:
                loadingOverlay
            case .error(let err):
                errorView(err)
            case .data, .stale, .empty:
                mainScrollContent
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HomeDashboardViewModel(
                    graphStore: graphStore,
                    personaEngine: personaEngine,
                    inferenceProvider: inferenceProvider,
                    alertRouter: alertRouter
                )
            }
            await viewModel?.load()
        }
    }

    // MARK: - Loading (skeleton placeholder matching real layout)

    private var loadingOverlay: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VCSpacing.lg) {
                // Header skeleton
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        LoadingShimmer(cornerRadius: 6)
                            .frame(width: 90, height: 13)
                        LoadingShimmer(cornerRadius: 8)
                            .frame(width: 130, height: 28)
                    }
                    Spacer()
                    LoadingShimmer(cornerRadius: 22)
                        .frame(width: 44, height: 44)
                }
                .padding(.top, VCSpacing.lg)

                // Health state bar skeleton
                LoadingShimmer(cornerRadius: VCRadius.lg)
                    .frame(height: 48)

                // Section label
                HStack {
                    LoadingShimmer(cornerRadius: 4)
                        .frame(width: 100, height: 12)
                    Spacer()
                }
                .padding(.top, VCSpacing.sm)

                // Goal rings skeleton
                HStack(spacing: VCSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        LoadingShimmer(cornerRadius: VCRadius.lg)
                            .frame(height: 130)
                    }
                }

                // Glucose hero skeleton
                LoadingShimmer(cornerRadius: VCRadius.xl)
                    .frame(height: 220)

                // Metric grid skeleton
                LazyVGrid(columns: [GridItem(.flexible(), spacing: VCSpacing.md), GridItem(.flexible(), spacing: VCSpacing.md)], spacing: VCSpacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        LoadingShimmer(cornerRadius: VCRadius.lg)
                            .frame(height: 108)
                    }
                }
            }
            .padding(.horizontal, VCSpacing.lg)
            .padding(.bottom, 108)
        }
    }

    // MARK: - Error

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(VCColors.alertOrange)
            Text("Unable to load health data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundColor(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxl)
            Button("Retry") {
                Task { await viewModel?.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(VCColors.primary)
        }
    }

    // MARK: - Main Scroll

    @State private var contentVisible: Bool = false

    private var mainScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VCSpacing.lg) {

                // ① Header
                headerSection
                    .padding(.top, VCSpacing.lg)
                    .staggeredEntrance(index: 0, visible: contentVisible)

                // ② Health State Bar
                healthStateSection
                    .staggeredEntrance(index: 1, visible: contentVisible)

                // ③ Today's Goals
                VStack(spacing: VCSpacing.sm) {
                    sectionLabel("TODAY'S GOALS")
                    goalRingsRow
                }
                .staggeredEntrance(index: 2, visible: contentVisible)

                // ④ Live Metrics
                VStack(spacing: VCSpacing.md) {
                    sectionLabel("LIVE METRICS")
                    glucoseHeroCard
                    metricGrid
                }
                .staggeredEntrance(index: 3, visible: contentVisible)

                // ⑤ VitaCore Intelligence (conditional)
                intelligenceSection
                    .staggeredEntrance(index: 4, visible: contentVisible)

                // ⑥ Recent Alerts (conditional)
                alertsSection
                    .staggeredEntrance(index: 5, visible: contentVisible)

                // ⑦ Quick Log
                VStack(spacing: VCSpacing.sm) {
                    sectionLabel("QUICK LOG")
                    quickLogStrip
                }
                .staggeredEntrance(index: 6, visible: contentVisible)

            }
            .padding(.horizontal, VCSpacing.lg)  // 16pt — Apple Health standard
            .padding(.bottom, 108) // clearance for tab bar + home indicator
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel?.load()
        }
        .task {
            // Fire entrance animation once content is ready
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                contentVisible = true
            }
        }
    }

    // MARK: ─── Section: Header ───────────────────────────────────────────

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(VCColors.onSurfaceVariant)
                Text("Praba")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(VCColors.onSurface)
            }

            Spacer()

            // Notification bell
            Button {
                tabRouter.selectedTab = .alerts
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VCColors.onSurfaceVariant)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VCColors.surfaceLow.opacity(0.7)))

                    if !(viewModel?.recentAlerts.isEmpty ?? true) {
                        Circle()
                            .fill(VCColors.critical)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }

            // Avatar
            avatarView
        }
    }

    private var avatarView: some View {
        ZStack {
            // Pulsing outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [VCColors.primary.opacity(0.5), VCColors.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 52, height: 52)
                .scaleEffect(pulseScale)
                .opacity(2.0 - pulseScale)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.2)
                        .repeatForever(autoreverses: false)
                    ) {
                        pulseScale = 1.18
                    }
                }

            // Avatar fill
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VCColors.primary, VCColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text("P")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    // MARK: ─── Section: Health State ─────────────────────────────────────

    @ViewBuilder
    private var healthStateSection: some View {
        if let vm = viewModel {
            HealthStateBar(
                statusText: vm.healthStateText,
                statusColor: vm.healthStateColor,
                lastUpdated: vm.lastUpdatedText
            )
            .onTapGesture {
                navRouter.navigate(to: .monitoringDetail)
            }
        }
    }

    // MARK: ─── Section: Goal Rings ───────────────────────────────────────

    private var goalRingsRow: some View {
        HStack(spacing: VCSpacing.md) {
            let goals = Array((viewModel?.goalProgress ?? []).prefix(3))
            let placeholders = max(0, 3 - goals.count)

            ForEach(goals, id: \.goalType) { goal in
                goalRingCard(goal: goal)
            }

            ForEach(0..<placeholders, id: \.self) { _ in
                placeholderRingCard
            }
        }
    }

    private func goalRingCard(goal: GoalProgress) -> some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.sm) {
                GoalRing(
                    label: "\(Int(goal.percentage))%",
                    current: goal.current,
                    target: goal.target,
                    accentColor: accentColor(for: goal.goalType),
                    size: 72
                )
                Text(goalDisplayName(goal.goalType))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VCSpacing.sm)
        }
    }

    private var placeholderRingCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.sm) {
                Circle()
                    .stroke(VCColors.outline.opacity(0.2), lineWidth: 7)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "minus")
                            .font(.system(size: 14))
                            .foregroundColor(VCColors.outline.opacity(0.4))
                    )
                Text("—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VCColors.outline.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VCSpacing.sm)
        }
    }

    private func goalDisplayName(_ type: GoalType) -> String {
        switch type {
        case .stepsDaily:      return "Steps"
        case .fluidDaily:      return "Fluid"
        case .timeInRange:     return "TIR"
        case .sleepDuration:   return "Sleep"
        case .caloriesDaily:   return "Calories"
        case .exerciseMinutes: return "Exercise"
        default:               return String(describing: type).capitalized
        }
    }

    private func accentColor(for goalType: GoalType) -> Color {
        switch goalType {
        case .stepsDaily:      return VCColors.primary
        case .fluidDaily:      return VCColors.tertiary
        case .timeInRange:     return VCColors.secondary
        case .sleepDuration:   return VCColors.primary
        case .caloriesDaily:   return VCColors.alertOrange
        case .exerciseMinutes: return VCColors.tertiary
        default:               return VCColors.primary
        }
    }

    // MARK: ─── Section: Glucose Hero Card ────────────────────────────────

    private var glucoseHeroCard: some View {
        GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {

                // Row: icon · name · source badge
                HStack(alignment: .center, spacing: VCSpacing.sm) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 17))
                        .foregroundColor(VCColors.tertiary)

                    Text("Blood Glucose")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)

                    Spacer()

                    Text("Dexcom G7")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(VCColors.outline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VCColors.surfaceLow))
                }

                // Large value + unit + trend arrow
                HStack(alignment: .firstTextBaseline, spacing: VCSpacing.md) {
                    let displayValue = viewModel?.glucoseReading.map { "\(Int($0.value))" } ?? "—"
                    let valueColor   = bandColor(viewModel?.glucoseBand ?? .safe)

                    Text(displayValue)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(valueColor)
                        .contentTransition(.numericText())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("mg/dL")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(VCColors.onSurfaceVariant)

                        bandPill(viewModel?.glucoseBand ?? .safe)
                    }

                    Spacer()

                    TrendArrow(
                        direction: mapTrend(viewModel?.glucoseTrend ?? .stable),
                        velocity: trendVelocityText()
                    )
                }

                // Sparkline — 4-hour window
                SparklineChart(
                    values: viewModel?.glucoseReadings.map(\.value) ?? [],
                    safeBandRange: 70...180,
                    accentColor: VCColors.tertiary,
                    height: 56
                )
                .frame(height: 56)

                // Time-axis labels
                HStack {
                    ForEach(timeAxisLabels(), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(VCColors.outline.opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onTapGesture {
            navRouter.navigate(to: .glucoseDetail)
        }
    }

    private func bandPill(_ band: ThresholdBand) -> some View {
        let (label, color) = bandMeta(band)
        return Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func bandMeta(_ band: ThresholdBand) -> (String, Color) {
        switch band {
        case .safe:     return ("In Range", VCColors.safe)
        case .watch:    return ("High", VCColors.watch)
        case .alert:    return ("Very High", VCColors.alertOrange)
        case .critical: return ("Critical", VCColors.critical)
        }
    }

    private func bandColor(_ band: ThresholdBand) -> Color {
        switch band {
        case .safe:     return VCColors.onSurface
        case .watch:    return VCColors.watch
        case .alert:    return VCColors.alertOrange
        case .critical: return VCColors.critical
        }
    }

    private func mapTrend(_ trend: TrendDirection) -> TrendArrow.Direction {
        switch trend {
        case .rising:      return .rising
        case .stable:      return .stable
        case .falling:     return .falling
        case .risingFast:  return .risingFast
        case .fallingFast: return .fallingFast
        }
    }

    private func trendVelocityText() -> String {
        guard let velocity = viewModel?.glucoseReading?.trendVelocity else { return "" }
        let sign = velocity >= 0 ? "+" : ""
        return "\(sign)\(Int(velocity)) mg/dL/hr"
    }

    private func timeAxisLabels() -> [String] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let offsets: [TimeInterval] = [-240, -180, -120, -60, 0]
        return offsets.map { offset in
            offset == 0 ? "Now" : formatter.string(from: now.addingTimeInterval(offset * 60))
        }
    }

    // MARK: ─── Section: Metric Grid (2×2) ────────────────────────────────

    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: VCSpacing.md),
                GridItem(.flexible(), spacing: VCSpacing.md)
            ],
            spacing: VCSpacing.md
        ) {
            metricGridCard(
                icon: "heart.fill",
                iconColor: VCColors.secondary,
                title: "Blood Pressure",
                value: bpValueString(),
                unit: "mmHg",
                badge: bpBadge(),
                badgeColor: bpBadgeColor(),
                progress: bpProgress(),
                destination: .bpDetail
            )

            metricGridCard(
                icon: "waveform.path.ecg",
                iconColor: VCColors.secondary,
                title: "Heart Rate",
                value: hrValueString(),
                unit: "bpm",
                badge: hrBadge(),
                badgeColor: VCColors.safe,
                progress: hrProgress(),
                destination: .hrDetail
            )

            metricGridCard(
                icon: "figure.walk",
                iconColor: VCColors.primary,
                title: "Steps",
                value: formattedSteps(),
                unit: "/ 10k",
                badge: stepsBadge(),
                badgeColor: VCColors.safe,
                progress: stepsProgress(),
                destination: .stepsDetail
            )

            metricGridCard(
                icon: "moon.fill",
                iconColor: VCColors.tertiary,
                title: "Sleep",
                value: sleepValueString(),
                unit: "hrs",
                badge: sleepBadge(),
                badgeColor: sleepBadgeColor(),
                progress: sleepProgress(),
                destination: .sleepDetail
            )
        }
    }

    private func metricGridCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        unit: String,
        badge: String,
        badgeColor: Color,
        progress: Double,
        destination: AppDestination
    ) -> some View {
        GlassCard(style: .small) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {

                // Icon row + badge
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(badgeColor.opacity(0.14)))
                }

                // Title
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VCColors.onSurfaceVariant)

                // Value + unit
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(VCColors.onSurface)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(VCColors.outline)
                        .lineLimit(1)
                }

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VCColors.outline.opacity(0.12))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(iconColor.opacity(0.8))
                            .frame(width: geo.size.width * min(max(progress, 0), 1), height: 3)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 3)

            }
            .padding(VCSpacing.md)
        }
        .onTapGesture {
            navRouter.navigate(to: destination)
        }
    }

    // Metric value helpers

    private func bpValueString() -> String {
        let sys = viewModel?.bpSystolicReading.map { "\(Int($0.value))" } ?? "—"
        let dia = viewModel?.bpDiastolicReading.map { "\(Int($0.value))" } ?? "—"
        guard sys != "—", dia != "—" else { return "—/—" }
        return "\(sys)/\(dia)"
    }

    private func bpBadge() -> String {
        guard let sys = viewModel?.bpSystolicReading?.value else { return "—" }
        if sys < 120 { return "Normal" }
        if sys < 130 { return "Elevated" }
        if sys < 140 { return "High 1" }
        return "High 2"
    }

    private func bpBadgeColor() -> Color {
        guard let sys = viewModel?.bpSystolicReading?.value else { return VCColors.outline }
        if sys < 120 { return VCColors.safe }
        if sys < 130 { return VCColors.watch }
        return VCColors.alertOrange
    }

    private func bpProgress() -> Double {
        guard let sys = viewModel?.bpSystolicReading?.value else { return 0 }
        return min(sys / 160.0, 1.0) // normalise to 160 mmHg ceiling
    }

    private func hrValueString() -> String {
        viewModel?.heartRateReading.map { "\(Int($0.value))" } ?? "—"
    }

    private func hrBadge() -> String {
        guard let hr = viewModel?.heartRateReading?.value else { return "—" }
        if hr < 60 { return "Low" }
        if hr <= 100 { return "Resting" }
        return "Elevated"
    }

    private func hrProgress() -> Double {
        guard let hr = viewModel?.heartRateReading?.value else { return 0 }
        return min(hr / 180.0, 1.0)
    }

    private func formattedSteps() -> String {
        guard let steps = viewModel?.stepsReading?.value else { return "—" }
        let s = Int(steps)
        return s >= 1000 ? String(format: "%.1fk", Double(s) / 1000.0) : "\(s)"
    }

    private func stepsBadge() -> String {
        guard let steps = viewModel?.stepsReading?.value else { return "—" }
        let pct = steps / 10_000.0
        if pct >= 1.0  { return "Done!" }
        if pct >= 0.75 { return "Almost" }
        if pct >= 0.5  { return "On track" }
        return "Keep going"
    }

    private func stepsProgress() -> Double {
        guard let steps = viewModel?.stepsReading?.value else { return 0 }
        return min(steps / 10_000.0, 1.0)
    }

    private func sleepValueString() -> String {
        viewModel?.sleepReading.map { String(format: "%.1f", $0.value) } ?? "—"
    }

    private func sleepBadge() -> String {
        guard let sleep = viewModel?.sleepReading?.value else { return "—" }
        if sleep >= 8.0  { return "Excellent" }
        if sleep >= 7.0  { return "Good" }
        if sleep >= 6.0  { return "Fair" }
        return "Poor"
    }

    private func sleepBadgeColor() -> Color {
        guard let sleep = viewModel?.sleepReading?.value else { return VCColors.outline }
        if sleep >= 7.0  { return VCColors.safe }
        if sleep >= 6.0  { return VCColors.watch }
        return VCColors.alertOrange
    }

    private func sleepProgress() -> Double {
        guard let sleep = viewModel?.sleepReading?.value else { return 0 }
        return min(sleep / 9.0, 1.0) // normalise to 9-hour target
    }

    // MARK: ─── Section: Intelligence Card ────────────────────────────────

    @ViewBuilder
    private var intelligenceSection: some View {
        if let card = viewModel?.prescriptionCard,
           let topRx = card.prescriptions.first {
            intelligenceCard(prescription: topRx)
        }
    }

    private func intelligenceCard(prescription: Prescription) -> some View {
        GlassCard(style: .enhanced) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {

                // Header row: pulsing dot + label + trajectory score
                HStack(spacing: VCSpacing.sm) {
                    Circle()
                        .fill(VCColors.primary)
                        .frame(width: 9, height: 9)
                        .opacity(intelligenceDotOpacity)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.1)
                                .repeatForever(autoreverses: true)
                            ) {
                                intelligenceDotOpacity = 0.3
                            }
                        }

                    Text("VitaCore Intelligence")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.4)
                        .foregroundColor(VCColors.primary)

                    Spacer()

                    // Trajectory score badge
                    if prescription.trajectoryScore > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                            Text("+\(Int(prescription.trajectoryScore * 100))%")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(VCColors.safe)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VCColors.safe.opacity(0.12)))
                    }
                }

                // Insight text derived from prescription fields
                let insightText = buildInsightText(prescription: prescription)
                Text(insightText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(VCColors.onSurface)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Time window tag
                if !prescription.timeWindow.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(prescription.timeWindow)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(VCColors.onSurfaceVariant)
                }

                Divider()
                    .background(VCColors.outline.opacity(0.15))

                // Action buttons
                HStack(spacing: VCSpacing.sm) {
                    intelligenceActionButton(
                        title: "\(prescription.actionVerb) now",
                        style: .primary
                    ) {
                        // Route to the appropriate log entry based on action verb.
                        switch prescription.actionVerb.lowercased() {
                        case "walk", "move", "exercise":
                            tabRouter.selectedTab = .log
                        case "eat", "refuel":
                            tabRouter.selectedTab = .log
                        case "drink", "hydrate":
                            tabRouter.selectedTab = .log
                        default:
                            tabRouter.selectedTab = .chat
                        }
                    }
                    intelligenceActionButton(title: "Tell me more", style: .secondary) {
                        tabRouter.selectedTab = .chat
                    }
                    intelligenceActionButton(title: "Remind me", style: .secondary) {
                        // Schedule a reminder notification in 15 minutes.
                        let content = UNMutableNotificationContent()
                        content.title = "VitaCore Reminder"
                        content.body = "\(prescription.actionVerb): \(prescription.actionDetail)"
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        Task { try? await UNUserNotificationCenter.current().add(request) }
                    }
                }
            }
        }
    }

    private func buildInsightText(prescription: Prescription) -> String {
        let verb    = prescription.actionVerb.lowercased()
        let detail  = prescription.actionDetail
        let qty     = "\(Int(prescription.actionQuantity))"
        let unit    = prescription.actionUnit
        let benefit = prescription.primaryBenefit

        if !unit.isEmpty {
            return "Recommendation: \(verb) \(qty) \(unit) of \(detail) to help \(benefit)."
        }
        return "Recommendation: \(verb) \(detail) to help \(benefit)."
    }

    private enum IntelligenceButtonStyle { case primary, secondary }

    private func intelligenceActionButton(
        title: String,
        style: IntelligenceButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(style == .primary ? .white : VCColors.primary)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, VCSpacing.sm)
                .background(
                    Group {
                        if style == .primary {
                            Capsule().fill(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        } else {
                            Capsule().fill(VCColors.primary.opacity(0.08))
                                .overlay(
                                    Capsule().stroke(VCColors.primary.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: ─── Section: Recent Alerts ────────────────────────────────────

    @ViewBuilder
    private var alertsSection: some View {
        let alerts = viewModel?.recentAlerts ?? []
        if !alerts.isEmpty {
            sectionLabel("RECENT ALERTS")
            VStack(spacing: VCSpacing.sm) {
                ForEach(alerts, id: \.alertId) { alert in
                    alertChip(alert: alert)
                }
            }
        }
    }

    private func alertChip(alert: AlertEvent) -> some View {
        GlassCard(style: .small) {
            HStack(spacing: VCSpacing.md) {
                // Urgency dot
                Circle()
                    .fill(alertColor(alert.urgency))
                    .frame(width: 9, height: 9)

                // Text block
                VStack(alignment: .leading, spacing: 2) {
                    Text(alertTitle(alert))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VCColors.onSurface)
                    Text(alertSubtitle(alert))
                        .font(.system(size: 11))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }

                Spacer()

                // Time + chevron
                HStack(spacing: VCSpacing.sm) {
                    Text(timeAgo(alert.timestamp))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(VCColors.outline)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(VCColors.outline.opacity(0.6))
                }
            }
        }
        .onTapGesture {
            tabRouter.selectedTab = .chat
        }
    }

    private func alertColor(_ urgency: AlertBand) -> Color {
        switch urgency {
        case .info:     return VCColors.tertiary
        case .watch:    return VCColors.watch
        case .alert:    return VCColors.alertOrange
        case .critical: return VCColors.critical
        }
    }

    private func alertTitle(_ alert: AlertEvent) -> String {
        alert.metricType.displayName + " Alert"
    }

    private func alertSubtitle(_ alert: AlertEvent) -> String {
        "\(Int(alert.value)) \(alert.metricType.unit) — tap to discuss with VitaCore"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        switch seconds {
        case ..<60:       return "\(seconds)s"
        case ..<3600:     return "\(seconds / 60)m"
        case ..<86400:    return "\(seconds / 3600)h"
        default:          return "\(seconds / 86400)d"
        }
    }

    // MARK: ─── Section: Quick Log ─────────────────────────────────────────

    private var quickLogStrip: some View {
        GlassCard(style: .standard) {
            HStack(spacing: 0) {
                // Sprint 6: quick-log buttons route to Log tab.
                quickLogButton(icon: "fork.knife",      label: "Food",    color: VCColors.watch)       { tabRouter.selectedTab = .log }
                quickLogButton(icon: "drop.fill",        label: "Fluid",   color: VCColors.tertiary)    { tabRouter.selectedTab = .log }
                quickLogButton(icon: "syringe.fill",     label: "Glucose", color: VCColors.primary)     { tabRouter.selectedTab = .log }
                quickLogButton(icon: "heart.fill",       label: "BP",      color: VCColors.secondary)   { tabRouter.selectedTab = .log }
                quickLogButton(icon: "scalemass.fill",   label: "Weight",  color: VCColors.primary)     { tabRouter.selectedTab = .log }
                quickLogButton(icon: "note.text",        label: "Note",    color: VCColors.outline)     { tabRouter.selectedTab = .log }
            }
            .padding(.vertical, VCSpacing.sm)
        }
    }

    private func quickLogButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.13))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: ─── Shared Helpers ─────────────────────────────────────────────

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(VCColors.outline)
            Spacer()
        }
    }

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Good night,"
        }
    }
}

// MARK: - Optional Double helper

private extension Optional where Wrapped == Double {
    func map(_ transform: (Double) -> String) -> String? {
        guard let self else { return nil }
        return transform(self)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Home Dashboard") {
    HomeDashboardView()
        .environment(NavigationRouter())
        .environment(TabRouter())
}
#endif
