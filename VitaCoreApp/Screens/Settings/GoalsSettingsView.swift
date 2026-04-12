import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - GoalType extensions

extension GoalType {
    var displayName: String {
        switch self {
        case .glucoseA1C:      return "Glucose A1C"
        case .bpSystolic:      return "Systolic BP"
        case .bpDiastolic:     return "Diastolic BP"
        case .stepsDaily:      return "Daily Steps"
        case .weightTarget:    return "Weight Target"
        case .sleepDuration:   return "Sleep Duration"
        case .fluidDaily:      return "Daily Fluid"
        case .caloriesDaily:   return "Daily Calories"
        case .carbsDaily:      return "Daily Carbs"
        case .proteinDaily:    return "Daily Protein"
        case .exerciseMinutes: return "Exercise Minutes"
        case .timeInRange:     return "Time in Range"
        case .restingHR:       return "Resting HR"
        case .hrvTarget:       return "HRV Target"
        }
    }

    var unit: String {
        switch self {
        case .glucoseA1C:      return "%"
        case .bpSystolic:      return "mmHg"
        case .bpDiastolic:     return "mmHg"
        case .stepsDaily:      return "steps"
        case .weightTarget:    return "kg"
        case .sleepDuration:   return "hrs"
        case .fluidDaily:      return "mL"
        case .caloriesDaily:   return "kcal"
        case .carbsDaily:      return "g"
        case .proteinDaily:    return "g"
        case .exerciseMinutes: return "min"
        case .timeInRange:     return "%"
        case .restingHR:       return "bpm"
        case .hrvTarget:       return "ms"
        }
    }

    var sliderRange: ClosedRange<Double> {
        switch self {
        case .glucoseA1C:      return 4...12
        case .bpSystolic:      return 90...180
        case .bpDiastolic:     return 60...120
        case .stepsDaily:      return 1000...20000
        case .weightTarget:    return 40...200
        case .sleepDuration:   return 5...10
        case .fluidDaily:      return 500...4000
        case .caloriesDaily:   return 1000...4000
        case .carbsDaily:      return 20...400
        case .proteinDaily:    return 20...250
        case .exerciseMinutes: return 10...180
        case .timeInRange:     return 30...100
        case .restingHR:       return 40...100
        case .hrvTarget:       return 10...100
        }
    }

    var defaultTarget: Double {
        switch self {
        case .glucoseA1C:      return 7.0
        case .bpSystolic:      return 120
        case .bpDiastolic:     return 80
        case .stepsDaily:      return 8000
        case .weightTarget:    return 75
        case .sleepDuration:   return 8
        case .fluidDaily:      return 2000
        case .caloriesDaily:   return 2000
        case .carbsDaily:      return 130
        case .proteinDaily:    return 80
        case .exerciseMinutes: return 30
        case .timeInRange:     return 70
        case .restingHR:       return 60
        case .hrvTarget:       return 50
        }
    }

    var icon: String {
        switch self {
        case .glucoseA1C, .timeInRange: return "drop.fill"
        case .bpSystolic, .bpDiastolic: return "heart.fill"
        case .stepsDaily:               return "figure.walk"
        case .weightTarget:             return "scalemass.fill"
        case .sleepDuration:            return "moon.fill"
        case .fluidDaily:               return "drop.triangle.fill"
        case .caloriesDaily:            return "flame.fill"
        case .carbsDaily:               return "leaf.fill"
        case .proteinDaily:             return "fork.knife"
        case .exerciseMinutes:          return "bolt.fill"
        case .restingHR:                return "waveform.path.ecg"
        case .hrvTarget:                return "waveform"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class GoalsSettingsViewModel {
    var goals: [GoalSummary] = []
    var personaContext: PersonaContext?
    var viewState: ViewState<Void> = .loading
    var isPresentingAddSheet: Bool = false
    var editingGoal: GoalSummary? = nil

    private let personaEngine: PersonaEngineProtocol

    init(personaEngine: PersonaEngineProtocol) {
        self.personaEngine = personaEngine
    }

    func load() async {
        viewState = .loading
        do {
            self.personaContext = try await personaEngine.getPersonaContext()
            self.goals = try await personaEngine.getActiveGoals()
            viewState = goals.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func updateTarget(type: GoalType, newTarget: Double) async {
        do {
            try await personaEngine.updateGoal(type: type, newTarget: newTarget)
            await load()
        } catch {
            viewState = .error(error)
        }
    }

    func addGoal(type: GoalType, target: Double) async {
        guard let context = personaContext else { return }
        guard !context.activeGoals.contains(where: { $0.goalType == type }) else { return }
        let newGoal = GoalSummary(goalType: type, target: target, current: 0, direction: 1)
        let updated = context.activeGoals + [newGoal]
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: context.activeConditions,
            activeGoals: updated,
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

    func removeGoal(type: GoalType) async {
        guard let context = personaContext else { return }
        let updated = context.activeGoals.filter { $0.goalType != type }
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: context.activeConditions,
            activeGoals: updated,
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

struct GoalsSettingsView: View {
    @Environment(\.personaEngine) var personaEngine
    @State private var viewModel: GoalsSettingsViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            Group {
                if let vm = viewModel {
                    goalsBody(vm: vm)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Goals")
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
            let vm = GoalsSettingsViewModel(personaEngine: personaEngine)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isPresentingAddSheet ?? false },
            set: { viewModel?.isPresentingAddSheet = $0 }
        )) {
            if let vm = viewModel {
                AddGoalSheet(viewModel: vm)
            }
        }
        .sheet(item: Binding(
            get: { viewModel?.editingGoal },
            set: { viewModel?.editingGoal = $0 }
        )) { goal in
            if let vm = viewModel {
                EditGoalSheet(goal: goal, viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func goalsBody(vm: GoalsSettingsViewModel) -> some View {
        switch vm.viewState {
        case .loading:
            VStack {
                Spacer()
                ProgressView().tint(VCColors.primary)
                Spacer()
            }

        case .empty:
            emptyState(vm: vm)

        case .error(let err):
            errorState(err, vm: vm)

        case .data, .stale:
            goalsList(vm: vm)
        }
    }

    private func emptyState(vm: GoalsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.xxl) {
            Spacer()
            GlassCard(style: .standard) {
                VStack(spacing: VCSpacing.lg) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(VCColors.tertiary.opacity(0.6))
                    Text("No goals set yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Set health goals to track your progress and get personalised guidance.")
                        .font(.system(size: 14))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)

                    Button {
                        vm.isPresentingAddSheet = true
                    } label: {
                        Text("Set Your First Goal")
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

    private func errorState(_ error: Error, vm: GoalsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(VCColors.alertOrange)
            Text("Could not load goals")
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

    private func goalsList(vm: GoalsSettingsViewModel) -> some View {
        ScrollView {
            VStack(spacing: VCSpacing.md) {
                ForEach(vm.goals) { goal in
                    goalRow(goal: goal, vm: vm)
                }

                Button {
                    vm.isPresentingAddSheet = true
                } label: {
                    Label("Add Another Goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(VCColors.tertiaryContainer.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                }
                .frame(minHeight: 44)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    private func goalRow(goal: GoalSummary, vm: GoalsSettingsViewModel) -> some View {
        let progress = goal.target == 0 ? 0.0 : min(1.0, goal.current / goal.target)
        let progressColor: Color = progress >= 1.0 ? VCColors.safe : progress >= 0.6 ? VCColors.watch : VCColors.tertiary

        return GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.md) {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VCColors.tertiary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: goal.goalType.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(VCColors.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.goalType.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("\(formatValue(goal.current)) / \(formatValue(goal.target)) \(goal.goalType.unit)")
                            .font(.system(size: 12))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }

                    Spacer()

                    // Drag handle (visual only)
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16))
                        .foregroundStyle(VCColors.outline)

                    Button {
                        vm.editingGoal = goal
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(VCColors.primary.opacity(0.8))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                // Progress bar
                VStack(spacing: VCSpacing.xs) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: VCRadius.pill)
                                .fill(VCColors.surfaceLow)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: VCRadius.pill)
                                .fill(progressColor)
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(Int(progress * 100))% complete")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(progressColor)
                        Spacer()
                        Button {
                            Task { await vm.removeGoal(type: goal.goalType) }
                        } label: {
                            Text("Remove")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VCColors.critical.opacity(0.8))
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Edit Goal Sheet

private struct EditGoalSheet: View {
    let goal: GoalSummary
    let viewModel: GoalsSettingsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var targetValue: Double
    @State private var isSaving: Bool = false

    init(goal: GoalSummary, viewModel: GoalsSettingsViewModel) {
        self.goal = goal
        self.viewModel = viewModel
        _targetValue = State(initialValue: goal.target)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh().ignoresSafeArea()

                VStack(spacing: VCSpacing.xxl) {
                    GlassCard(style: .hero) {
                        VStack(spacing: VCSpacing.lg) {
                            HStack {
                                Image(systemName: goal.goalType.icon)
                                    .font(.system(size: 32))
                                    .foregroundStyle(VCColors.tertiary)
                                Text(goal.goalType.displayName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(VCColors.onSurface)
                                Spacer()
                            }

                            VStack(spacing: VCSpacing.md) {
                                HStack {
                                    Text("Target")
                                        .font(.system(size: 14))
                                        .foregroundStyle(VCColors.onSurfaceVariant)
                                    Spacer()
                                    Text("\(formatValue(targetValue)) \(goal.goalType.unit)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(VCColors.primary)
                                }

                                Slider(
                                    value: $targetValue,
                                    in: goal.goalType.sliderRange,
                                    step: goal.goalType.sliderStep
                                )
                                .tint(VCColors.primary)

                                HStack {
                                    Text(formatValue(goal.goalType.sliderRange.lowerBound))
                                        .font(.system(size: 11))
                                        .foregroundStyle(VCColors.outline)
                                    Spacer()
                                    Text(formatValue(goal.goalType.sliderRange.upperBound))
                                        .font(.system(size: 11))
                                        .foregroundStyle(VCColors.outline)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    GlassCard(style: .standard) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current value")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                                Text("\(formatValue(goal.current)) \(goal.goalType.unit)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(VCColors.onSurface)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Previous target")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                                Text("\(formatValue(goal.target)) \(goal.goalType.unit)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                            }
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    Spacer()

                    Button {
                        Task {
                            isSaving = true
                            await viewModel.updateTarget(type: goal.goalType, newTarget: targetValue)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Update Goal")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(colors: [VCColors.primary, VCColors.secondary], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(isSaving)
                    .frame(minHeight: 44)
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.xxl)
                }
                .padding(.top, VCSpacing.lg)
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(VCColors.primary)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Add Goal Sheet

private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: GoalsSettingsViewModel

    @State private var selectedType: GoalType? = nil
    @State private var targetValue: Double = 0
    @State private var isAdding: Bool = false

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh().ignoresSafeArea()

                VStack(spacing: VCSpacing.lg) {
                    // Target slider (shown when a type is selected)
                    if let type = selectedType {
                        GlassCard(style: .standard) {
                            VStack(spacing: VCSpacing.md) {
                                HStack {
                                    Text("Target for \(type.displayName)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(VCColors.onSurfaceVariant)
                                    Spacer()
                                    Text("\(formatValue(targetValue)) \(type.unit)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(VCColors.primary)
                                }
                                Slider(value: $targetValue, in: type.sliderRange, step: type.sliderStep)
                                    .tint(VCColors.primary)
                            }
                        }
                        .padding(.horizontal, VCSpacing.xxl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Grid of goal type cards
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: VCSpacing.md) {
                            ForEach(GoalType.allCases, id: \.self) { type in
                                goalTypeCard(type: type)
                            }
                        }
                        .padding(.horizontal, VCSpacing.xxl)
                        .padding(.bottom, 120)
                    }
                }
                .animation(.spring(response: 0.35), value: selectedType)
                .padding(.top, VCSpacing.lg)

                VStack {
                    Spacer()
                    addButton
                        .padding(.horizontal, VCSpacing.xxl)
                        .padding(.bottom, VCSpacing.xxl)
                }
            }
            .navigationTitle("Add Goal")
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
        .onChange(of: selectedType) { _, newType in
            if let t = newType { targetValue = t.defaultTarget }
        }
    }

    private func goalTypeCard(type: GoalType) -> some View {
        let isSelected = selectedType == type
        let alreadyAdded = viewModel.goals.contains(where: { $0.goalType == type })

        return Button {
            if !alreadyAdded {
                selectedType = isSelected ? nil : type
            }
        } label: {
            VStack(spacing: VCSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : (alreadyAdded ? VCColors.outline : VCColors.tertiary))

                Text(type.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : (alreadyAdded ? VCColors.outline : VCColors.onSurface))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if alreadyAdded {
                    Text("Added")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VCColors.safe)
                } else if isSelected {
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
                          ? LinearGradient(colors: [VCColors.tertiary, VCColors.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [VCColors.tertiaryContainer.opacity(0.3), VCColors.tertiaryContainer.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .strokeBorder(isSelected ? VCColors.tertiary : VCColors.outlineVariant, lineWidth: isSelected ? 2 : 1)
            )
            .opacity(alreadyAdded ? 0.5 : 1.0)
        }
        .disabled(alreadyAdded)
        .frame(minHeight: 44)
    }

    private var addButton: some View {
        Button {
            guard let type = selectedType else { return }
            Task {
                isAdding = true
                await viewModel.addGoal(type: type, target: targetValue)
                isAdding = false
                dismiss()
            }
        } label: {
            ZStack {
                if isAdding {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedType != nil ? "Add \(selectedType!.displayName)" : "Select a Goal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: selectedType != nil ? [VCColors.primary, VCColors.secondary] : [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .disabled(selectedType == nil || isAdding)
        .frame(minHeight: 44)
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - GoalType slider step helper

private extension GoalType {
    var sliderStep: Double {
        switch self {
        case .glucoseA1C:      return 0.1
        case .bpSystolic:      return 1
        case .bpDiastolic:     return 1
        case .stepsDaily:      return 500
        case .weightTarget:    return 0.5
        case .sleepDuration:   return 0.5
        case .fluidDaily:      return 100
        case .caloriesDaily:   return 50
        case .carbsDaily:      return 5
        case .proteinDaily:    return 5
        case .exerciseMinutes: return 5
        case .timeInRange:     return 1
        case .restingHR:       return 1
        case .hrvTarget:       return 1
        }
    }
}

// MARK: - GoalSummary Identifiable conformance for sheet(item:)
// GoalSummary already conforms to Identifiable via goalType in the contracts package.
// We need to extend it to be usable with sheet(item:) which requires Identifiable.
// Since id: GoalType already exists, this is satisfied.
