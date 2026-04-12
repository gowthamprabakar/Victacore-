// OnboardingMedicationsView.swift
// VitaCoreApp — OB-05: Medications onboarding screen

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Draft Medication (local form state)

private struct DraftMedication: Identifiable {
    let id: UUID = UUID()
    var name: String = ""
    var medicationClass: MedicationClass = .other
    var dose: String = ""
    var frequency: String = "Once daily"
}

// MARK: - MedicationClass onboarding display name (scoped to avoid module-wide duplicate)

private extension MedicationClass {
    var onboardingDisplayName: String {
        switch self {
        case .metformin:              return "Metformin"
        case .insulin:                return "Insulin"
        case .sulfonylurea:           return "Sulfonylurea"
        case .sglt2Inhibitor:         return "SGLT2 Inhibitor"
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
}

// MARK: - OnboardingMedicationsView

struct OnboardingMedicationsView: View {

    // -------------------------------------------------------------------------
    // MARK: External
    // -------------------------------------------------------------------------

    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    @Environment(\.personaEngine) private var personaEngine

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var addedMedications: [DraftMedication] = []
    @State private var isFormExpanded: Bool = false
    @State private var draft: DraftMedication = DraftMedication()
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private let frequencyOptions = [
        "Once daily",
        "Twice daily",
        "Three times daily",
        "As needed",
        "Weekly"
    ]

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 5,
            totalSteps: 8,
            title: "Medications",
            subtitle: "Add any medications you take regularly. This helps us check food interactions.",
            showSkip: true,
            showBack: true,
            onNext: handleContinue,
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(spacing: VCSpacing.xxl) {

                // ── Added medications list ────────────────────────────────────
                if !addedMedications.isEmpty {
                    VStack(spacing: VCSpacing.md) {
                        ForEach(Array(addedMedications.enumerated()), id: \.element.id) { index, med in
                            MedicationRow(medication: med) {
                                removeMedication(id: med.id)
                            }
                            .fadeUpEntrance(delay: VCAnimation.staggerDelay(index: index))
                        }
                    }
                }

                // ── Add Medication Button / Form ──────────────────────────────
                VStack(spacing: VCSpacing.md) {
                    if !isFormExpanded {
                        Button(action: { withAnimation(VCAnimation.cardEntrance) { isFormExpanded = true } }) {
                            HStack(spacing: VCSpacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(VCColors.primary)
                                Text("Add Medication")
                                    .vcFont(.headline)
                                    .foregroundStyle(VCColors.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: VCSpacing.tapTarget)
                            .background(
                                RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                                    .strokeBorder(VCColors.primary.opacity(0.4), lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                                            .fill(VCColors.primaryContainer.opacity(0.12))
                                    )
                            )
                        }
                        .fadeUpEntrance(delay: 0.1)
                    } else {
                        MedicationFormCard(
                            draft: $draft,
                            frequencyOptions: frequencyOptions,
                            onAdd: addDraft,
                            onCancel: {
                                withAnimation(VCAnimation.cardEntrance) {
                                    isFormExpanded = false
                                    draft = DraftMedication()
                                }
                            }
                        )
                        .fadeUpEntrance(delay: 0)
                    }
                }

                // ── Error ─────────────────────────────────────────────────────
                if let error = errorMessage {
                    Text(error)
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.critical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, VCSpacing.xs)
                }

                // ── Skip hint ─────────────────────────────────────────────────
                if addedMedications.isEmpty && !isFormExpanded {
                    Text("No medications? Tap Skip to continue.")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fadeUpEntrance(delay: 0.2)
                }
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.bottom, VCSpacing.xxl)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func addDraft() {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(VCAnimation.cardEntrance) {
            addedMedications.append(draft)
            draft = DraftMedication()
            isFormExpanded = false
        }
    }

    private func removeMedication(id: UUID) {
        withAnimation(VCAnimation.cardEntrance) {
            addedMedications.removeAll { $0.id == id }
        }
    }

    private func handleContinue() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                for med in addedMedications {
                    let summary = MedicationSummary(
                        classKey: med.medicationClass,
                        name: med.name,
                        dose: med.dose,
                        frequency: med.frequency
                    )
                    try await personaEngine.addMedication(summary)
                }
                await MainActor.run {
                    isSaving = false
                    onNext()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save medications. Please try again."
                }
            }
        }
    }
}

// MARK: - MedicationRow

private struct MedicationRow: View {

    let medication: DraftMedication
    let onRemove: () -> Void

    var body: some View {
        GlassCard(style: .small) {
            HStack(spacing: VCSpacing.md) {
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text(medication.name.isEmpty ? "Unnamed medication" : medication.name)
                        .vcFont(.headline)
                        .foregroundStyle(VCColors.onSurface)

                    HStack(spacing: VCSpacing.sm) {
                        if !medication.dose.isEmpty {
                            Label(medication.dose, systemImage: "pills.fill")
                                .vcFont(.caption)
                                .foregroundStyle(VCColors.onSurfaceVariant)
                        }
                        Text(medication.frequency)
                            .vcFont(.caption)
                            .foregroundStyle(VCColors.outline)
                    }

                    Text(medication.medicationClass.onboardingDisplayName)
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.primary.opacity(0.8))
                        .padding(.horizontal, VCSpacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(VCColors.primaryContainer.opacity(0.25))
                        )
                }

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(VCColors.critical.opacity(0.7))
                        .frame(width: VCSpacing.tapTarget, height: VCSpacing.tapTarget)
                }
            }
        }
    }
}

// MARK: - MedicationFormCard

private struct MedicationFormCard: View {

    @Binding var draft: DraftMedication
    let frequencyOptions: [String]
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.lg) {

                Text("New Medication")
                    .vcFont(.headline)
                    .foregroundStyle(VCColors.onSurface)

                // Medication name
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Medication Name")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                    TextField("e.g. Metformin 500mg", text: $draft.name)
                        .vcFont(.body)
                        .foregroundStyle(VCColors.onSurface)
                        .padding(VCSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                                .fill(VCColors.surfaceLow)
                        )
                        .frame(minHeight: VCSpacing.tapTarget)
                }

                // Medication class
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Medication Class")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                    Picker("Class", selection: $draft.medicationClass) {
                        ForEach(MedicationClass.allCases, id: \.self) { cls in
                            Text(cls.onboardingDisplayName).tag(cls)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(VCSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                            .fill(VCColors.surfaceLow)
                    )
                    .frame(minHeight: VCSpacing.tapTarget)
                }

                // Dose
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Dose")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                    TextField("e.g. 500mg", text: $draft.dose)
                        .vcFont(.body)
                        .foregroundStyle(VCColors.onSurface)
                        .padding(VCSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                                .fill(VCColors.surfaceLow)
                        )
                        .frame(minHeight: VCSpacing.tapTarget)
                }

                // Frequency
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text("Frequency")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                    Picker("Frequency", selection: $draft.frequency) {
                        ForEach(frequencyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(VCSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                            .fill(VCColors.surfaceLow)
                    )
                    .frame(minHeight: VCSpacing.tapTarget)
                }

                // Actions
                HStack(spacing: VCSpacing.md) {
                    Button("Cancel", action: onCancel)
                        .vcFont(.headline)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(height: VCSpacing.tapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                                .fill(VCColors.surfaceLow)
                        )

                    Button("Add", action: onAdd)
                        .vcFont(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: VCSpacing.tapTarget)
                        .background(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.primaryDim],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous))
                        .opacity(draft.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        BackgroundMesh().ignoresSafeArea()
        OnboardingMedicationsView(
            onNext: {},
            onBack: {},
            onSkip: {}
        )
    }
}
#endif
