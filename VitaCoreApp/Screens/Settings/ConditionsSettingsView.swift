import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - ViewModel

@Observable
@MainActor
final class ConditionsSettingsViewModel {
    var conditions: [ConditionSummary] = []
    var personaContext: PersonaContext?
    var viewState: ViewState<Void> = .loading
    var isPresentingAddSheet: Bool = false

    private let personaEngine: PersonaEngineProtocol

    init(personaEngine: PersonaEngineProtocol) {
        self.personaEngine = personaEngine
    }

    func load() async {
        viewState = .loading
        do {
            self.personaContext = try await personaEngine.getPersonaContext()
            self.conditions = try await personaEngine.getActiveConditions()
            viewState = conditions.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func addCondition(_ key: ConditionKey, severity: String) async {
        guard let context = personaContext else { return }
        // Avoid duplicates
        guard !context.activeConditions.contains(where: { $0.conditionKey == key }) else { return }
        let new = ConditionSummary(conditionKey: key, severity: severity, daysActive: 0)
        let updated = context.activeConditions + [new]
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: updated,
            activeGoals: context.activeGoals,
            activeMedications: context.activeMedications,
            allergies: context.allergies,
            preferences: context.preferences,
            responseProfiles: context.responseProfiles,
            thresholdOverrides: context.thresholdOverrides,
            dataQualityFlags: context.dataQualityFlags,
            goalProgress: context.goalProgress
        )
        do {
            try await personaEngine.updatePersonaContext(newContext)
            await load()
        } catch {
            viewState = .error(error)
        }
    }

    func removeCondition(_ condition: ConditionSummary) async {
        guard let context = personaContext else { return }
        let updated = context.activeConditions.filter { $0.conditionKey != condition.conditionKey }
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: updated,
            activeGoals: context.activeGoals,
            activeMedications: context.activeMedications,
            allergies: context.allergies,
            preferences: context.preferences,
            responseProfiles: context.responseProfiles,
            thresholdOverrides: context.thresholdOverrides,
            dataQualityFlags: context.dataQualityFlags,
            goalProgress: context.goalProgress
        )
        do {
            try await personaEngine.updatePersonaContext(newContext)
            await load()
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - Main View

struct ConditionsSettingsView: View {
    @Environment(\.personaEngine) var personaEngine
    @State private var viewModel: ConditionsSettingsViewModel?
    @State private var expandedCondition: ConditionKey? = nil

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            Group {
                if let vm = viewModel {
                    conditionsBody(vm: vm)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Conditions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel?.isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VCColors.primary)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .task {
            let vm = ConditionsSettingsViewModel(personaEngine: personaEngine)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isPresentingAddSheet ?? false },
            set: { viewModel?.isPresentingAddSheet = $0 }
        )) {
            if let vm = viewModel {
                AddConditionSheet(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func conditionsBody(vm: ConditionsSettingsViewModel) -> some View {
        switch vm.viewState {
        case .loading:
            VStack {
                Spacer()
                ProgressView()
                    .tint(VCColors.primary)
                Spacer()
            }

        case .empty:
            emptyState(vm: vm)

        case .error(let err):
            errorState(err, vm: vm)

        case .data, .stale:
            conditionsList(vm: vm)
        }
    }

    private func emptyState(vm: ConditionsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.xxl) {
            Spacer()
            GlassCard(style: .standard) {
                VStack(spacing: VCSpacing.lg) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundStyle(VCColors.secondary.opacity(0.6))
                    Text("No conditions added yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Adding your health conditions helps VitaCore personalise insights and alerts for you.")
                        .font(.system(size: 14))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)

                    Button {
                        vm.isPresentingAddSheet = true
                    } label: {
                        Text("Add Your First Condition")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(colors: [VCColors.primary, VCColors.secondary], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                }
                .padding(.vertical, VCSpacing.sm)
            }
            .padding(.horizontal, VCSpacing.xxl)
            Spacer()
        }
    }

    private func errorState(_ error: Error, vm: ConditionsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(VCColors.alertOrange)
            Text("Could not load conditions")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxl)
            Button("Retry") {
                Task { await vm.load() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(VCColors.primary)
            .frame(minHeight: 44)
            Spacer()
        }
    }

    private func conditionsList(vm: ConditionsSettingsViewModel) -> some View {
        ScrollView {
            VStack(spacing: VCSpacing.md) {
                ForEach(vm.conditions) { condition in
                    conditionRow(condition: condition, vm: vm)
                }

                Button {
                    vm.isPresentingAddSheet = true
                } label: {
                    Label("Add Another Condition", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(VCColors.primaryContainer.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                }
                .frame(minHeight: 44)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    private func conditionRow(condition: ConditionSummary, vm: ConditionsSettingsViewModel) -> some View {
        let isExpanded = expandedCondition == condition.conditionKey

        return GlassCard(style: .standard) {
            VStack(spacing: 0) {
                // Main row
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedCondition = isExpanded ? nil : condition.conditionKey
                    }
                } label: {
                    HStack(spacing: VCSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(VCColors.secondary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(VCColors.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(condition.conditionKey.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VCColors.onSurface)

                            HStack(spacing: VCSpacing.sm) {
                                severityChip(condition.severity)

                                Text("\(condition.daysActive) days active")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VCColors.outline)
                            .animation(.spring(response: 0.3), value: isExpanded)
                    }
                    .padding(.vertical, VCSpacing.sm)
                    .frame(minHeight: 44)
                }
                .buttonStyle(PlainButtonStyle())

                // Expanded content
                if isExpanded {
                    Divider()
                        .background(VCColors.outlineVariant)
                        .padding(.vertical, VCSpacing.xs)

                    VStack(spacing: VCSpacing.md) {
                        HStack {
                            Text("Severity")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VCColors.onSurfaceVariant)
                            Spacer()
                            Text(condition.severity.capitalized)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VCColors.onSurface)
                        }

                        Button {
                            Task {
                                await vm.removeCondition(condition)
                                expandedCondition = nil
                            }
                        } label: {
                            Label("Remove Condition", systemImage: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VCColors.critical)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(VCColors.critical.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                        }
                        .frame(minHeight: 44)
                    }
                    .padding(.bottom, VCSpacing.sm)
                    .padding(.top, VCSpacing.xs)
                }
            }
        }
    }

    private func severityChip(_ severity: String) -> some View {
        let color: Color = {
            switch severity.lowercased() {
            case "mild":     return VCColors.safe
            case "moderate": return VCColors.watch
            case "severe":   return VCColors.alertOrange
            default:         return VCColors.outline
            }
        }()

        return Text(severity.capitalized)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, VCSpacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Add Condition Sheet

private struct AddConditionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ConditionsSettingsViewModel

    @State private var searchText: String = ""
    @State private var selectedKey: ConditionKey? = nil
    @State private var selectedSeverity: String = "moderate"
    @State private var isAdding: Bool = false

    private let severityOptions = ["mild", "moderate", "severe"]

    private var filteredConditions: [ConditionKey] {
        let all = ConditionKey.allCases
        if searchText.isEmpty { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh().ignoresSafeArea()

                VStack(spacing: VCSpacing.lg) {
                    // Search bar
                    HStack(spacing: VCSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(VCColors.outline)
                        TextField("Search conditions", text: $searchText)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, VCSpacing.md)
                    .padding(.vertical, VCSpacing.sm)
                    .background(VCColors.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                    .padding(.horizontal, VCSpacing.xxl)

                    // Severity picker
                    HStack(spacing: VCSpacing.sm) {
                        Text("Severity:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                        ForEach(severityOptions, id: \.self) { sev in
                            Button {
                                selectedSeverity = sev
                            } label: {
                                Text(sev.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selectedSeverity == sev ? .white : VCColors.onSurfaceVariant)
                                    .padding(.horizontal, VCSpacing.md)
                                    .padding(.vertical, VCSpacing.xs)
                                    .background(
                                        Capsule().fill(selectedSeverity == sev ? VCColors.primary : VCColors.surfaceLow)
                                    )
                            }
                            .frame(minHeight: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    // Grid of condition cards
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: VCSpacing.md) {
                            ForEach(filteredConditions, id: \.self) { key in
                                conditionCard(key: key)
                            }
                        }
                        .padding(.horizontal, VCSpacing.xxl)
                        .padding(.bottom, 120)
                    }
                }
                .padding(.top, VCSpacing.lg)

                // Add button pinned to bottom
                VStack {
                    Spacer()
                    addButton
                        .padding(.horizontal, VCSpacing.xxl)
                        .padding(.bottom, VCSpacing.xxl)
                }
            }
            .navigationTitle("Add Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(VCColors.primary)
                        .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func conditionCard(key: ConditionKey) -> some View {
        let isSelected = selectedKey == key
        return Button {
            selectedKey = isSelected ? nil : key
        } label: {
            VStack(spacing: VCSpacing.sm) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : VCColors.secondary)

                Text(key.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : VCColors.onSurface)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .padding(VCSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .fill(isSelected
                          ? LinearGradient(colors: [VCColors.primary, VCColors.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [VCColors.primaryContainer.opacity(0.3), VCColors.primaryContainer.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .strokeBorder(isSelected ? VCColors.primary : VCColors.outlineVariant, lineWidth: isSelected ? 2 : 1)
            )
        }
        .frame(minHeight: 44)
    }

    private var addButton: some View {
        Button {
            guard let key = selectedKey else { return }
            Task {
                isAdding = true
                await viewModel.addCondition(key, severity: selectedSeverity)
                isAdding = false
                dismiss()
            }
        } label: {
            ZStack {
                if isAdding {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedKey != nil ? "Add \(selectedKey!.displayName)" : "Select a Condition")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: selectedKey != nil ? [VCColors.primary, VCColors.secondary] : [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .disabled(selectedKey == nil || isAdding)
        .frame(minHeight: 44)
    }
}
