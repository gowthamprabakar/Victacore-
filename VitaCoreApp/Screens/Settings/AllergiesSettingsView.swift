import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Severity color helper

private extension AllergenSeverity {
    var color: Color {
        switch self {
        case .anaphylactic: return VCColors.critical
        case .severe:       return VCColors.critical
        case .moderate:     return VCColors.alertOrange
        case .mild:         return VCColors.watch
        }
    }

    var label: String {
        switch self {
        case .anaphylactic: return "Anaphylactic"
        case .severe:       return "Severe"
        case .moderate:     return "Moderate"
        case .mild:         return "Mild"
        }
    }

    var icon: String {
        switch self {
        case .anaphylactic: return "exclamationmark.octagon.fill"
        case .severe:       return "exclamationmark.triangle.fill"
        case .moderate:     return "exclamationmark.circle.fill"
        case .mild:         return "info.circle.fill"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class AllergiesSettingsViewModel {
    var allergies: [AllergenSummary] = []
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
            self.allergies = try await personaEngine.getAllergies()
            viewState = allergies.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func addAllergen(name: String, severity: AllergenSeverity) async {
        guard let context = personaContext else { return }
        guard !context.allergies.contains(where: { $0.allergen.lowercased() == name.lowercased() }) else { return }
        let newAllergen = AllergenSummary(allergen: name, severity: severity)
        let updated = context.allergies + [newAllergen]
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: context.activeConditions,
            activeGoals: context.activeGoals,
            activeMedications: context.activeMedications,
            allergies: updated,
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

    func removeAllergen(id: UUID) async {
        guard let context = personaContext else { return }
        let updated = context.allergies.filter { $0.id != id }
        let newContext = PersonaContext(
            userId: context.userId,
            activeConditions: context.activeConditions,
            activeGoals: context.activeGoals,
            activeMedications: context.activeMedications,
            allergies: updated,
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

struct AllergiesSettingsView: View {
    @Environment(\.personaEngine) var personaEngine
    @State private var viewModel: AllergiesSettingsViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            Group {
                if let vm = viewModel {
                    allergiesBody(vm: vm)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Allergies")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel?.isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VCColors.watch)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .task {
            let vm = AllergiesSettingsViewModel(personaEngine: personaEngine)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isPresentingAddSheet ?? false },
            set: { viewModel?.isPresentingAddSheet = $0 }
        )) {
            if let vm = viewModel {
                AddAllergySheet(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func allergiesBody(vm: AllergiesSettingsViewModel) -> some View {
        switch vm.viewState {
        case .loading:
            VStack {
                Spacer()
                ProgressView().tint(VCColors.watch)
                Spacer()
            }

        case .empty:
            emptyState(vm: vm)

        case .error(let err):
            errorState(err, vm: vm)

        case .data, .stale:
            allergiesList(vm: vm)
        }
    }

    private func emptyState(vm: AllergiesSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.xxl) {
            Spacer()
            GlassCard(style: .standard) {
                VStack(spacing: VCSpacing.lg) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(VCColors.watch.opacity(0.6))
                    Text("No allergies registered")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Adding known allergies helps VitaCore flag potential risks in food recommendations and medication interactions.")
                        .font(.system(size: 14))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)

                    Button {
                        vm.isPresentingAddSheet = true
                    } label: {
                        Text("Add Your First Allergy")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(colors: [VCColors.watch, VCColors.alertOrange], startPoint: .leading, endPoint: .trailing)
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

    private func errorState(_ error: Error, vm: AllergiesSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(VCColors.alertOrange)
            Text("Could not load allergies")
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

    private func allergiesList(vm: AllergiesSettingsViewModel) -> some View {
        ScrollView {
            VStack(spacing: VCSpacing.md) {
                // Safety notice for anaphylactic entries
                if vm.allergies.contains(where: { $0.severity == .anaphylactic }) {
                    GlassCard(style: .small) {
                        Label {
                            Text("You have anaphylactic allergies. Always carry emergency medication and inform caregivers.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VCColors.critical)
                        } icon: {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(VCColors.critical)
                        }
                    }
                }

                ForEach(vm.allergies) { allergy in
                    allergyRow(allergy: allergy, vm: vm)
                }

                Button {
                    vm.isPresentingAddSheet = true
                } label: {
                    Label("Add Another Allergy", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.watch)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(VCColors.watch.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                }
                .frame(minHeight: 44)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.vertical, VCSpacing.lg)
        }
    }

    private func allergyRow(allergy: AllergenSummary, vm: AllergiesSettingsViewModel) -> some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(allergy.severity.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: allergy.severity.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(allergy.severity.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(allergy.allergen)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)

                    // Severity badge
                    Text(allergy.severity.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(allergy.severity.color)
                        .padding(.horizontal, VCSpacing.sm)
                        .padding(.vertical, 3)
                        .background(allergy.severity.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    Task { await vm.removeAllergen(id: allergy.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VCColors.critical.opacity(0.8))
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Add Allergy Sheet

private struct AddAllergySheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: AllergiesSettingsViewModel

    @State private var selectedPreset: String? = nil
    @State private var customAllergen: String = ""
    @State private var isCustomEntry: Bool = false
    @State private var selectedSeverity: AllergenSeverity = .moderate
    @State private var isAdding: Bool = false
    @State private var validationError: String? = nil

    private let presets: [String] = [
        "Peanuts", "Tree Nuts", "Dairy", "Gluten",
        "Shellfish", "Soy", "Eggs", "Sesame"
    ]

    private let presetIcons: [String: String] = [
        "Peanuts": "allergens",
        "Tree Nuts": "leaf.fill",
        "Dairy": "drop.fill",
        "Gluten": "wheat",
        "Shellfish": "fish.fill",
        "Soy": "leaf.circle.fill",
        "Eggs": "circle.fill",
        "Sesame": "circle.grid.3x3.fill"
    ]

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var finalAllergenName: String {
        if isCustomEntry {
            return customAllergen.trimmingCharacters(in: .whitespaces)
        }
        return selectedPreset ?? ""
    }

    private var canAdd: Bool { !finalAllergenName.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VCSpacing.xl) {
                        // Preset allergen grid
                        VStack(alignment: .leading, spacing: VCSpacing.md) {
                            sectionLabel("COMMON ALLERGENS")

                            LazyVGrid(columns: gridColumns, spacing: VCSpacing.md) {
                                ForEach(presets, id: \.self) { preset in
                                    presetCard(preset)
                                }
                            }
                        }

                        // Custom entry toggle
                        VStack(alignment: .leading, spacing: VCSpacing.md) {
                            sectionLabel("CUSTOM ALLERGEN")

                            Button {
                                isCustomEntry.toggle()
                                if isCustomEntry { selectedPreset = nil }
                            } label: {
                                HStack {
                                    Image(systemName: isCustomEntry ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(VCColors.primary)
                                    Text("Enter a custom allergen")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(VCColors.onSurface)
                                    Spacer()
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if isCustomEntry {
                                TextField("e.g. Latex, Bee venom, Penicillin", text: $customAllergen)
                                    .font(.system(size: 15))
                                    .foregroundStyle(VCColors.onSurface)
                                    .padding(VCSpacing.md)
                                    .background(VCColors.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.spring(response: 0.3), value: isCustomEntry)

                        // Severity picker
                        VStack(alignment: .leading, spacing: VCSpacing.md) {
                            sectionLabel("REACTION SEVERITY")

                            VStack(spacing: VCSpacing.sm) {
                                ForEach(AllergenSeverity.allCases, id: \.self) { sev in
                                    Button {
                                        selectedSeverity = sev
                                    } label: {
                                        HStack(spacing: VCSpacing.md) {
                                            Image(systemName: selectedSeverity == sev ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(sev.color)
                                                .font(.system(size: 20))

                                            Image(systemName: sev.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(sev.color)
                                                .frame(width: 20)

                                            Text(sev.label)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(VCColors.onSurface)

                                            Spacer()
                                        }
                                        .padding(.horizontal, VCSpacing.md)
                                        .padding(.vertical, VCSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: VCRadius.md)
                                                .fill(selectedSeverity == sev ? sev.color.opacity(0.1) : VCColors.surfaceLow.opacity(0.5))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: VCRadius.md)
                                                .strokeBorder(selectedSeverity == sev ? sev.color : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .frame(minHeight: 44)
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        if let err = validationError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(VCColors.critical)
                        }

                        // Add button
                        Button {
                            guard canAdd else {
                                validationError = "Please select or enter an allergen."
                                return
                            }
                            validationError = nil
                            Task {
                                isAdding = true
                                await viewModel.addAllergen(name: finalAllergenName, severity: selectedSeverity)
                                isAdding = false
                                dismiss()
                            }
                        } label: {
                            ZStack {
                                if isAdding {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(canAdd ? "Add \(finalAllergenName)" : "Select an Allergen")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: canAdd ? [VCColors.watch, VCColors.alertOrange] : [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(!canAdd || isAdding)
                        .frame(minHeight: 44)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.vertical, VCSpacing.lg)
                }
            }
            .navigationTitle("Add Allergy")
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

    private func presetCard(_ preset: String) -> some View {
        let isSelected = selectedPreset == preset && !isCustomEntry
        let icon = presetIcons[preset] ?? "allergens"

        return Button {
            isCustomEntry = false
            customAllergen = ""
            selectedPreset = isSelected ? nil : preset
        } label: {
            VStack(spacing: VCSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .white : VCColors.watch)

                Text(preset)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : VCColors.onSurface)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80)
            .padding(VCSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .fill(isSelected
                          ? LinearGradient(colors: [VCColors.watch, VCColors.alertOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [VCColors.watch.opacity(0.08), VCColors.watch.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .strokeBorder(isSelected ? VCColors.watch : VCColors.outlineVariant, lineWidth: isSelected ? 2 : 1)
            )
        }
        .frame(minHeight: 44)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(VCColors.outline)
    }
}
