// AlertHistoryView.swift
// VitaCore — Tab 4 Alerts screen: full history with filters and inline expansion.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - AlertHistoryViewModel

@Observable
@MainActor
final class AlertHistoryViewModel {

    var allAlerts: [AlertEvent] = []
    var filteredAlerts: [AlertEvent] = []
    var urgencyFilter: AlertBand? = nil
    var dateRangeDays: Int = 7
    var viewState: ViewState<Void> = .loading
    var expandedAlertId: UUID? = nil

    private let alertRouter: AlertRouterProtocol

    init(alertRouter: AlertRouterProtocol) {
        self.alertRouter = alertRouter
    }

    func load() async {
        viewState = .loading
        do {
            let alerts = try await alertRouter.getAlertHistory(days: dateRangeDays)
            self.allAlerts = alerts.sorted { $0.timestamp > $1.timestamp }
            applyFilter()
            viewState = filteredAlerts.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func setUrgencyFilter(_ band: AlertBand?) {
        urgencyFilter = band
        applyFilter()
        viewState = filteredAlerts.isEmpty ? .empty : .data(())
    }

    func setDateRange(_ days: Int) {
        dateRangeDays = days
        Task { await load() }
    }

    func toggleExpanded(_ id: UUID) {
        expandedAlertId = (expandedAlertId == id) ? nil : id
    }

    func acknowledge(_ alertId: UUID) async {
        try? await alertRouter.acknowledgeAlert(id: alertId)
        await load()
    }

    private func applyFilter() {
        if let urgency = urgencyFilter {
            filteredAlerts = allAlerts.filter { $0.urgency == urgency }
        } else {
            filteredAlerts = allAlerts
        }
    }

    var stats: (total: Int, critical: Int, alert: Int, watch: Int, info: Int) {
        let total    = allAlerts.count
        let critical = allAlerts.filter { $0.urgency == .critical }.count
        let alert    = allAlerts.filter { $0.urgency == .alert }.count
        let watch    = allAlerts.filter { $0.urgency == .watch }.count
        let info     = allAlerts.filter { $0.urgency == .info }.count
        return (total, critical, alert, watch, info)
    }
}

// MARK: - Colour + time helpers (file-private)

private func urgencyColor(_ band: AlertBand) -> Color {
    switch band {
    case .info:     return VCColors.tertiary
    case .watch:    return VCColors.watch
    case .alert:    return VCColors.alertOrange
    case .critical: return VCColors.critical
    }
}

private func relativeTime(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60    { return "now" }
    if seconds < 3600  { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
}

// MARK: - AlertHistoryView

struct AlertHistoryView: View {

    @Environment(\.alertRouter) private var alertRouter
    @State private var viewModel: AlertHistoryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                AlertHistoryContent(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VCColors.background)
            }
        }
        .task {
            if viewModel == nil {
                let vm = AlertHistoryViewModel(alertRouter: alertRouter)
                viewModel = vm
                await vm.load()
            }
        }
    }
}

// MARK: - AlertHistoryContent

private struct AlertHistoryContent: View {

    @Bindable var vm: AlertHistoryViewModel
    @State private var showFilterSheet = false

    // Date-range options
    private let dateRangeOptions: [(label: String, days: Int)] = [
        ("Today", 1),
        ("7d",    7),
        ("30d",   30),
        ("90d",   90)
    ]

    // Urgency filter options: nil means "All"
    private let urgencyOptions: [(label: String, band: AlertBand?)] = [
        ("All",      nil),
        ("Critical", .critical),
        ("Alert",    .alert),
        ("Watch",    .watch),
        ("Info",     .info)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh()
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {

                        // Stats header
                        statsHeader
                            .padding(.horizontal, VCSpacing.lg)
                            .padding(.top, VCSpacing.md)
                            .padding(.bottom, VCSpacing.sm)

                        // Urgency filter chips
                        urgencyFilterBar
                            .padding(.bottom, VCSpacing.sm)

                        // Date range selector
                        dateRangeBar
                            .padding(.horizontal, VCSpacing.lg)
                            .padding(.bottom, VCSpacing.lg)

                        // Alert list
                        alertListBody
                            .padding(.horizontal, VCSpacing.lg)
                            .padding(.bottom, VCSpacing.xxxl)
                    }
                }
                .refreshable {
                    await vm.load()
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VCColors.primary)
                    }
                    .frame(minWidth: VCSpacing.tapTarget, minHeight: VCSpacing.tapTarget)
                }
            }
        }
    }

    // MARK: Stats header

    private var statsHeader: some View {
        HStack(spacing: VCSpacing.sm) {
            statPill(label: "Total",    value: "\(vm.stats.total)",    color: VCColors.onSurface)
            statPill(label: "Critical", value: "\(vm.stats.critical)", color: VCColors.critical)
            statPill(label: "Watch",    value: "\(vm.stats.watch)",    color: VCColors.watch)
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VCSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                        .strokeBorder(VCColors.outlineVariant.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: Urgency filter chips

    private var urgencyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VCSpacing.sm) {
                ForEach(urgencyOptions, id: \.label) { option in
                    filterChip(label: option.label, isSelected: vm.urgencyFilter == option.band) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.setUrgencyFilter(option.band)
                        }
                    }
                }
            }
            .padding(.horizontal, VCSpacing.lg)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VCColors.primary : VCColors.onSurfaceVariant)
                .padding(.horizontal, VCSpacing.lg)
                .padding(.vertical, VCSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? VCColors.primaryContainer : VCColors.surfaceLow)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? VCColors.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .frame(minHeight: VCSpacing.tapTarget)
        .buttonStyle(.plain)
    }

    // MARK: Date range selector

    private var dateRangeBar: some View {
        HStack(spacing: VCSpacing.sm) {
            ForEach(dateRangeOptions, id: \.days) { option in
                dateRangePill(label: option.label, days: option.days)
            }
        }
    }

    private func dateRangePill(label: String, days: Int) -> some View {
        let isSelected = vm.dateRangeDays == days
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.setDateRange(days)
            }
        } label: {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VCColors.primary : VCColors.onSurfaceVariant)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, VCSpacing.xs + 2)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isSelected ? VCColors.primaryContainer.opacity(0.7) : VCColors.surface)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: VCSpacing.tapTarget)
    }

    // MARK: Alert list body

    @ViewBuilder
    private var alertListBody: some View {
        switch vm.viewState {
        case .loading:
            VStack(spacing: VCSpacing.lg) {
                ForEach(0..<5, id: \.self) { _ in
                    alertRowSkeleton
                }
            }

        case .empty:
            emptyState

        case .error(let error):
            VStack(spacing: VCSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(VCColors.alertOrange)
                Text("Unable to load alerts")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(VCColors.onSurface)
                Text(error.localizedDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await vm.load() }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(VCColors.primary)
                .padding(.top, VCSpacing.sm)
            }
            .padding(.top, VCSpacing.xxxl)

        case .data, .stale:
            LazyVStack(spacing: VCSpacing.sm) {
                ForEach(vm.filteredAlerts) { alert in
                    AlertRowView(
                        alert: alert,
                        isExpanded: vm.expandedAlertId == alert.id,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                vm.toggleExpanded(alert.id)
                            }
                        },
                        onAcknowledge: {
                            Task { await vm.acknowledge(alert.id) }
                        }
                    )
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: VCSpacing.lg) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(VCColors.outline)
            Text("No alerts in this period")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(VCColors.onSurfaceVariant)
            Text("Alerts will appear here when your health metrics go outside your thresholds.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(VCColors.outline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxxl)
        }
        .padding(.top, VCSpacing.xxxl)
    }

    // MARK: Skeleton

    private var alertRowSkeleton: some View {
        HStack(spacing: VCSpacing.md) {
            Circle()
                .fill(VCColors.surfaceHigh)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: VCSpacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(VCColors.surfaceHigh)
                    .frame(height: 14)
                    .frame(maxWidth: 180)
                RoundedRectangle(cornerRadius: 4)
                    .fill(VCColors.surfaceDim)
                    .frame(height: 11)
                    .frame(maxWidth: 240)
            }
            Spacer()
        }
        .padding(VCSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - AlertRowView

private struct AlertRowView: View {

    let alert: AlertEvent
    let isExpanded: Bool
    let onTap: () -> Void
    let onAcknowledge: () -> Void

    var body: some View {
        GlassCard(style: .small) {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsed row
                Button(action: onTap) {
                    HStack(spacing: VCSpacing.md) {
                        // Urgency dot
                        Circle()
                            .fill(urgencyColor(alert.urgency))
                            .frame(width: 8, height: 8)
                            .padding(.top, 2)

                        // Content
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(alert.metricType.displayName) \(formattedValue)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(VCColors.onSurface)
                                .lineLimit(1)

                            Text(alert.explanation)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(VCColors.onSurfaceVariant)
                                .lineLimit(2)

                            Text(relativeTime(alert.timestamp))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(VCColors.outline)
                        }

                        Spacer(minLength: 0)

                        // Trailing indicators
                        HStack(spacing: VCSpacing.xs) {
                            if alert.isAcknowledged {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(VCColors.safe)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(VCColors.outline)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(minHeight: VCSpacing.tapTarget)

                // Expanded evidence
                if isExpanded {
                    Divider()
                        .padding(.vertical, VCSpacing.sm)

                    VStack(alignment: .leading, spacing: VCSpacing.sm) {
                        // Full explanation
                        Text(alert.explanation)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(VCColors.onSurface)

                        // Evidence list
                        if !alert.evidence.isEmpty {
                            VStack(alignment: .leading, spacing: VCSpacing.xs) {
                                Text("Evidence")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                ForEach(alert.evidence.prefix(3), id: \.self) { item in
                                    HStack(alignment: .top, spacing: VCSpacing.xs) {
                                        Text("•")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(urgencyColor(alert.urgency))
                                        Text(item)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(VCColors.onSurfaceVariant)
                                    }
                                }
                            }
                            .padding(VCSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                                    .fill(urgencyColor(alert.urgency).opacity(0.06))
                            )
                        }

                        // Action row
                        HStack(spacing: VCSpacing.sm) {
                            if !alert.isAcknowledged {
                                Button(action: onAcknowledge) {
                                    Label("Acknowledge", systemImage: "checkmark")
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundStyle(VCColors.primary)
                                        .padding(.horizontal, VCSpacing.md)
                                        .padding(.vertical, VCSpacing.xs + 2)
                                        .background(
                                            Capsule()
                                                .fill(VCColors.primaryContainer.opacity(0.6))
                                        )
                                }
                                .buttonStyle(.plain)
                                .frame(minHeight: VCSpacing.tapTarget)
                            }

                            Button {
                                // Open conversation — deep link context
                            } label: {
                                Label("Open conversation", systemImage: "bubble.left.and.bubble.right")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(VCColors.tertiary)
                                    .padding(.horizontal, VCSpacing.md)
                                    .padding(.vertical, VCSpacing.xs + 2)
                                    .background(
                                        Capsule()
                                            .fill(VCColors.tertiaryContainer.opacity(0.4))
                                    )
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: VCSpacing.tapTarget)

                            Spacer()
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var formattedValue: String {
        let unit = alert.metricType.unit
        if alert.value == alert.value.rounded() {
            return "\(Int(alert.value)) \(unit)"
        }
        return String(format: "%.1f \(unit)", alert.value)
    }
}

// MARK: - Previews

#if DEBUG
import VitaCoreMock

#Preview("Alert History") {
    AlertHistoryView()
        .environment(\.alertRouter, MockAlertRouter())
}
#endif
