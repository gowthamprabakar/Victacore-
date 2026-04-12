import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - MedicationClass display names

extension MedicationClass {
    var displayName: String {
        switch self {
        case .metformin:              return "Metformin"
        case .insulin:                return "Insulin"
        case .sulfonylurea:           return "Sulfonylurea"
        case .sglt2Inhibitor:         return "SGLT-2 Inhibitor"
        case .glp1Agonist:            return "GLP-1 Agonist"
        case .betaBlocker:            return "Beta Blocker"
        case .aceInhibitor:           return "ACE Inhibitor"
        case .calciumChannelBlocker:  return "Calcium Channel Blocker"
        case .diuretic:               return "Diuretic"
        case .statin:                 return "Statin"
        case .warfarin:               return "Warfarin"
        case .levothyroxine:          return "Levothyroxine"
        case .maoi:                   return "MAOI"
        case .other:                  return "Other"
        }
    }

    var interactionWarning: String? {
        switch self {
        case .calciumChannelBlocker: return "Avoid grapefruit juice — may increase drug levels."
        case .warfarin:              return "Avoid high-vitamin K foods; monitor INR closely."
        case .maoi:                  return "Strict dietary restrictions required (tyramine)."
        case .metformin:             return "Take with food to reduce GI side effects."
        default:                     return nil
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class MedicationsSettingsViewModel {
    var medications: [MedicationSummary] = []
    var viewState: ViewState<Void> = .loading
    var isPresentingAddSheet: Bool = false

    private let personaEngine: PersonaEngineProtocol

    init(personaEngine: PersonaEngineProtocol) {
        self.personaEngine = personaEngine
    }

    func load() async {
        viewState = .loading
        do {
            self.medications = try await personaEngine.getActiveMedications()
            viewState = medications.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func addMedication(_ medication: MedicationSummary) async {
        do {
            try await personaEngine.addMedication(medication)
            await load()
        } catch {
            viewState = .error(error)
        }
    }

    func removeMedication(id: UUID) async {
        do {
            try await personaEngine.removeMedication(id: id)
            await load()
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - Main View

struct MedicationsSettingsView: View {
    @Environment(\.personaEngine) var personaEngine
    @State private var viewModel: MedicationsSettingsViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            Group {
                if let vm = viewModel {
                    medicationsBody(vm: vm)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Medications")
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
            let vm = MedicationsSettingsViewModel(personaEngine: personaEngine)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isPresentingAddSheet ?? false },
            set: { viewModel?.isPresentingAddSheet = $0 }
        )) {
            if let vm = viewModel {
                AddMedicationSheet(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func medicationsBody(vm: MedicationsSettingsViewModel) -> some View {
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
            medicationsList(vm: vm)
        }
    }

    private func emptyState(vm: MedicationsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.xxl) {
            Spacer()
            GlassCard(style: .standard) {
                VStack(spacing: VCSpacing.lg) {
                    Image(systemName: "pills")
                        .font(.system(size: 48))
                        .foregroundStyle(VCColors.primary.opacity(0.5))
                    Text("No medications tracked")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Add your medications so VitaCore can account for interactions and timing in its recommendations.")
                        .font(.system(size: 14))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)

                    Button {
                        vm.isPresentingAddSheet = true
                    } label: {
                        Text("Add Your First Medication")
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

    private func errorState(_ error: Error, vm: MedicationsSettingsViewModel) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(VCColors.alertOrange)
            Text("Could not load medications")
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

    private func medicationsList(vm: MedicationsSettingsViewModel) -> some View {
        ScrollView {
            VStack(spacing: VCSpacing.md) {
                ForEach(vm.medications) { medication in
                    medicationRow(medication: medication, vm: vm)
                }

                Button {
                    vm.isPresentingAddSheet = true
                } label: {
                    Label("Add Another Medication", systemImage: "plus")
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

    private func medicationRow(medication: MedicationSummary, vm: MedicationsSettingsViewModel) -> some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VCColors.primary.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(VCColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(medication.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VCColors.onSurface)
                        Text(medication.classKey.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(medication.dose)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VCColors.primary)
                        Text(medication.frequency)
                            .font(.system(size: 11))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }

                    Button {
                        Task { await vm.removeMedication(id: medication.id) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(VCColors.critical.opacity(0.8))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                // Interaction warnings
                let classWarning = medication.classKey.interactionWarning
                let hasFlags = !medication.interactionFlags.isEmpty

                if classWarning != nil || hasFlags {
                    VStack(alignment: .leading, spacing: VCSpacing.xs) {
                        if let warning = classWarning {
                            interactionChip(warning)
                        }
                        ForEach(medication.interactionFlags, id: \.self) { flag in
                            interactionChip(flag)
                        }
                    }
                }
            }
        }
    }

    private func interactionChip(_ text: String) -> some View {
        Label {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VCColors.watch)
                .lineLimit(2)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(VCColors.watch)
        }
        .padding(.horizontal, VCSpacing.sm)
        .padding(.vertical, VCSpacing.xs)
        .background(VCColors.watch.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: VCRadius.sm))
    }
}

// MARK: - Add Medication Sheet

private struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: MedicationsSettingsViewModel

    @State private var medicationName: String = ""
    @State private var selectedClass: MedicationClass = .other
    @State private var dose: String = ""
    @State private var frequency: String = "Once daily"
    @State private var isAdding: Bool = false
    @State private var validationError: String? = nil

    private let frequencyOptions = [
        "Once daily",
        "Twice daily",
        "Three times daily",
        "With meals",
        "Before meals",
        "At bedtime",
        "As needed"
    ]

    private var canAdd: Bool {
        !medicationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dose.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundMesh().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VCSpacing.lg) {
                        // Name
                        GlassCard(style: .standard) {
                            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                                fieldLabel("MEDICATION NAME")
                                TextField("e.g. Metformin, Lisinopril", text: $medicationName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(VCColors.onSurface)
                                    .padding(VCSpacing.md)
                                    .background(VCColors.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                            }
                        }

                        // Class picker
                        GlassCard(style: .standard) {
                            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                                fieldLabel("MEDICATION CLASS")
                                Picker("Class", selection: $selectedClass) {
                                    ForEach(MedicationClass.allCases, id: \.self) { cls in
                                        Text(cls.displayName).tag(cls)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(VCColors.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, VCSpacing.sm)

                                // Show class warning if applicable
                                if let warning = selectedClass.interactionWarning {
                                    Label {
                                        Text(warning)
                                            .font(.system(size: 12))
                                            .foregroundStyle(VCColors.watch)
                                    } icon: {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(VCColors.watch)
                                    }
                                    .padding(.horizontal, VCSpacing.sm)
                                    .padding(.top, VCSpacing.xs)
                                }
                            }
                        }

                        // Dose
                        GlassCard(style: .standard) {
                            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                                fieldLabel("DOSE")
                                TextField("e.g. 500 mg, 10 units", text: $dose)
                                    .font(.system(size: 16))
                                    .foregroundStyle(VCColors.onSurface)
                                    .padding(VCSpacing.md)
                                    .background(VCColors.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                            }
                        }

                        // Frequency
                        GlassCard(style: .standard) {
                            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                                fieldLabel("FREQUENCY")
                                Picker("Frequency", selection: $frequency) {
                                    ForEach(frequencyOptions, id: \.self) { opt in
                                        Text(opt).tag(opt)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(VCColors.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, VCSpacing.sm)
                            }
                        }

                        if let err = validationError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(VCColors.critical)
                                .multilineTextAlignment(.center)
                        }

                        // Save button
                        Button {
                            guard canAdd else {
                                validationError = "Please fill in the medication name and dose."
                                return
                            }
                            validationError = nil
                            let newMed = MedicationSummary(
                                classKey: selectedClass,
                                name: medicationName.trimmingCharacters(in: .whitespaces),
                                dose: dose.trimmingCharacters(in: .whitespaces),
                                frequency: frequency
                            )
                            Task {
                                isAdding = true
                                await viewModel.addMedication(newMed)
                                isAdding = false
                                dismiss()
                            }
                        } label: {
                            ZStack {
                                if isAdding {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save Medication")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: canAdd ? [VCColors.primary, VCColors.secondary] : [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
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
            .navigationTitle("Add Medication")
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

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(VCColors.outline)
    }
}
