import SwiftUI
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - ViewModel

@Observable
@MainActor
final class ConnectionsSettingsViewModel {
    var allSkills: [SkillDescriptor] = []
    var filteredSkills: [SkillDescriptor] = []
    var statusFilter: SkillConnectionStatus? = nil
    var expandedSkillId: String? = nil
    var viewState: ViewState<Void> = .loading

    private let skillBus: SkillBusProtocol

    init(skillBus: SkillBusProtocol) {
        self.skillBus = skillBus
    }

    func load() async {
        viewState = .loading
        let skills = await skillBus.getRegisteredSkills()
        self.allSkills = skills
        applyFilter()
        viewState = .data(())
    }

    func applyFilter() {
        if let status = statusFilter {
            filteredSkills = allSkills.filter { $0.status == status }
        } else {
            filteredSkills = allSkills
        }
    }

    func setFilter(_ status: SkillConnectionStatus?) {
        statusFilter = status
        applyFilter()
    }

    func toggleExpanded(_ id: String) {
        expandedSkillId = expandedSkillId == id ? nil : id
    }

    func sync(_ id: String) async {
        _ = try? await skillBus.syncSkill(id: id)
        await load()
    }

    func disconnect(_ id: String) async {
        try? await skillBus.disconnectSkill(id: id)
        await load()
    }

    var stats: (connected: Int, disconnected: Int, issues: Int) {
        let connected = allSkills.filter { $0.status == .connected }.count
        let disconnected = allSkills.filter { $0.status == .disconnected }.count
        let issues = allSkills.filter { $0.status == .authExpired || $0.status == .error }.count
        return (connected, disconnected, issues)
    }
}

// MARK: - Main View

struct ConnectionsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.skillBus) private var skillBus

    @State private var viewModel: ConnectionsSettingsViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            if let vm = viewModel {
                ConnectionsContentView(vm: vm)
            } else {
                ProgressView()
                    .tint(VCColors.primary)
            }
        }
        .navigationBarHidden(true)
        .task {
            let vm = ConnectionsSettingsViewModel(skillBus: skillBus)
            viewModel = vm
            await vm.load()
        }
        .overlay(alignment: .topLeading) {
            backButton
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(VCColors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VCColors.primary)
            }
        }
        .padding(.leading, VCSpacing.lg)
        .padding(.top, 56)
    }
}

// MARK: - Content View

private struct ConnectionsContentView: View {
    @Bindable var vm: ConnectionsSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: VCSpacing.xl) {
                // Header
                HStack {
                    Spacer().frame(width: 44 + VCSpacing.lg)
                    Text("Connections")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Spacer()
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, 60)

                // Stats header
                statsHeader

                // Filter chips
                filterChips

                // Device list or loading/empty state
                switch vm.viewState {
                case .loading:
                    ProgressView()
                        .tint(VCColors.primary)
                        .padding(.top, VCSpacing.xxl)

                case .data, .stale:
                    if vm.filteredSkills.isEmpty {
                        emptyState
                    } else {
                        devicesSection
                    }

                case .empty:
                    emptyState

                case .error(let err):
                    Text(err.localizedDescription)
                        .foregroundStyle(VCColors.critical)
                        .padding()
                }
            }
            .padding(.bottom, 100)
        }
        .refreshable {
            await vm.load()
        }
    }

    // MARK: Stats Header

    private var statsHeader: some View {
        GlassCard(style: .enhanced) {
            HStack(spacing: 0) {
                statItem(
                    value: "\(vm.stats.connected)",
                    label: "Connected",
                    color: VCColors.safe
                )

                Divider()
                    .frame(height: 36)
                    .background(VCColors.outlineVariant)

                statItem(
                    value: "\(vm.stats.disconnected)",
                    label: "Disconnected",
                    color: VCColors.outline
                )

                Divider()
                    .frame(height: 36)
                    .background(VCColors.outlineVariant)

                statItem(
                    value: "\(vm.stats.issues)",
                    label: "Issues",
                    color: VCColors.alertOrange
                )
            }
        }
        .padding(.horizontal, VCSpacing.xxl)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VCSpacing.md)
    }

    // MARK: Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VCSpacing.sm) {
                filterChip(label: "All", status: nil)
                filterChip(label: "Connected", status: .connected)
                filterChip(label: "Disconnected", status: .disconnected)
                filterChip(label: "Issues", status: .authExpired)
            }
            .padding(.horizontal, VCSpacing.xxl)
        }
    }

    private func filterChip(label: String, status: SkillConnectionStatus?) -> some View {
        let isSelected = vm.statusFilter == status
        return Button {
            vm.setFilter(status)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : VCColors.onSurfaceVariant)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? VCColors.primary : VCColors.surfaceLow)
                )
        }
        .frame(minHeight: 44)
    }

    // MARK: Devices Section

    private var devicesSection: some View {
        VStack(spacing: VCSpacing.md) {
            ForEach(vm.filteredSkills) { skill in
                SkillCard(
                    skill: skill,
                    isExpanded: vm.expandedSkillId == skill.id,
                    onTap: { vm.toggleExpanded(skill.id) },
                    onSync: { await vm.sync(skill.id) },
                    onDisconnect: { await vm.disconnect(skill.id) }
                )
            }
        }
        .padding(.horizontal, VCSpacing.xxl)
    }

    // MARK: Empty State

    private var emptyState: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.md) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(VCColors.outline)
                Text("No devices match this filter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VCColors.onSurface)
                Text("Try selecting a different filter above.")
                    .font(.system(size: 13))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, VCSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, VCSpacing.xxl)
    }
}

// MARK: - Skill Card

private struct SkillCard: View {
    let skill: SkillDescriptor
    let isExpanded: Bool
    let onTap: () -> Void
    let onSync: () async -> Void
    let onDisconnect: () async -> Void

    @State private var isSyncing = false
    @State private var isDisconnecting = false

    var body: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                // Main row
                Button(action: onTap) {
                    HStack(spacing: VCSpacing.md) {
                        // Device icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(brandColor(for: skill).opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: skill.iconName)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(brandColor(for: skill))
                        }

                        // Name + status + last sync
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: VCSpacing.sm) {
                                Text(skill.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VCColors.onSurface)
                                statusBadge(skill.status)
                            }

                            if let lastSync = skill.lastSyncDescription {
                                Text(lastSync)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                                    .lineLimit(1)
                            } else {
                                Text("Never synced")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VCColors.outline)
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VCColors.outline)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(minHeight: 44)

                // Expanded section
                if isExpanded {
                    Divider()
                        .background(VCColors.outlineVariant)
                        .padding(.top, VCSpacing.sm)

                    VStack(alignment: .leading, spacing: VCSpacing.md) {
                        // Supported metrics
                        if !skill.supportedMetrics.isEmpty {
                            VStack(alignment: .leading, spacing: VCSpacing.xs) {
                                Text("SUPPORTED METRICS")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(VCColors.outline)

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: VCSpacing.xs
                                ) {
                                    ForEach(skill.supportedMetrics, id: \.self) { metric in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(VCColors.tertiary)
                                                .frame(width: 5, height: 5)
                                            Text(metric.displayName)
                                                .font(.system(size: 12))
                                                .foregroundStyle(VCColors.onSurfaceVariant)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }

                        // Action buttons
                        HStack(spacing: VCSpacing.sm) {
                            // Sync button
                            Button {
                                Task {
                                    isSyncing = true
                                    await onSync()
                                    isSyncing = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(VCColors.tertiary)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    Text(isSyncing ? "Syncing..." : "Sync Now")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(VCColors.tertiary)
                                .padding(.horizontal, VCSpacing.md)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: VCRadius.sm)
                                        .strokeBorder(VCColors.tertiary.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .disabled(isSyncing || isDisconnecting)
                            .frame(minHeight: 44)

                            Spacer()

                            // Connect / Disconnect button
                            if skill.status == .connected {
                                Button {
                                    Task {
                                        isDisconnecting = true
                                        await onDisconnect()
                                        isDisconnecting = false
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isDisconnecting {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(VCColors.critical)
                                        } else {
                                            Image(systemName: "xmark.circle")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        Text(isDisconnecting ? "Disconnecting..." : "Disconnect")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(VCColors.critical)
                                    .padding(.horizontal, VCSpacing.md)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: VCRadius.sm)
                                            .strokeBorder(VCColors.critical.opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .disabled(isSyncing || isDisconnecting)
                                .frame(minHeight: 44)
                            } else {
                                Button {
                                    // Connect action — placeholder
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Connect")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, VCSpacing.md)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: VCRadius.sm)
                                            .fill(VCColors.primary)
                                    )
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                    .padding(.top, VCSpacing.md)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
        }
    }

    private func statusBadge(_ status: SkillConnectionStatus) -> some View {
        Text(status.displayLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(statusColor(status))
            )
    }

    private func statusColor(_ status: SkillConnectionStatus) -> Color {
        switch status {
        case .connected:    return VCColors.safe
        case .disconnected: return VCColors.outline
        case .authExpired:  return VCColors.alertOrange
        case .syncing:      return VCColors.tertiary
        case .error:        return VCColors.critical
        }
    }

    private func brandColor(for skill: SkillDescriptor) -> Color {
        // Assign distinct brand-like colors per device ecosystem
        switch skill.id {
        case let id where id.contains("apple") || id.contains("healthkit"):
            return VCColors.safe
        case let id where id.contains("garmin"):
            return VCColors.tertiary
        case let id where id.contains("whoop"):
            return Color(red: 0.9, green: 0.2, blue: 0.3)
        case let id where id.contains("oura"):
            return Color(red: 0.4, green: 0.2, blue: 0.8)
        case let id where id.contains("dexcom"):
            return VCColors.alertOrange
        case let id where id.contains("withings"):
            return Color(red: 0.0, green: 0.5, blue: 0.8)
        case let id where id.contains("polar"):
            return VCColors.secondary
        case let id where id.contains("fitbit") || id.contains("google"):
            return Color(red: 0.0, green: 0.7, blue: 0.4)
        default:
            return VCColors.primary
        }
    }
}

// MARK: - Extensions

extension SkillConnectionStatus {
    var displayLabel: String {
        switch self {
        case .connected:    return "Connected"
        case .disconnected: return "Off"
        case .authExpired:  return "Auth Expired"
        case .syncing:      return "Syncing"
        case .error:        return "Error"
        }
    }
}

extension MetricType {
    var displayName: String {
        // Use the raw value as a fallback display name
        return self.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
