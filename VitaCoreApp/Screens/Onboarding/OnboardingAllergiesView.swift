// OnboardingAllergiesView.swift
// VitaCoreApp — OB-06: Allergies onboarding screen

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Preset Allergen Model

private struct PresetAllergen: Identifiable {
    let id: String          // allergen name key
    let displayName: String
    let icon: String        // SF Symbol name
}

private let presetAllergens: [PresetAllergen] = [
    PresetAllergen(id: "Peanuts",    displayName: "Peanuts",    icon: "leaf.fill"),
    PresetAllergen(id: "Tree Nuts",  displayName: "Tree Nuts",  icon: "tree.fill"),
    PresetAllergen(id: "Dairy",      displayName: "Dairy",      icon: "cup.and.saucer.fill"),
    PresetAllergen(id: "Gluten",     displayName: "Gluten",     icon: "leaf.circle.fill"),
    PresetAllergen(id: "Shellfish",  displayName: "Shellfish",  icon: "fish.fill"),
    PresetAllergen(id: "Soy",        displayName: "Soy",        icon: "carrot.fill"),
    PresetAllergen(id: "Eggs",       displayName: "Eggs",       icon: "oval.fill"),
    PresetAllergen(id: "Sesame",     displayName: "Sesame",     icon: "circle.grid.3x3.fill")
]

// MARK: - AllergenSeverity helpers

private extension AllergenSeverity {
    var displayName: String {
        switch self {
        case .mild:         return "Mild"
        case .moderate:     return "Moderate"
        case .severe:       return "Severe"
        case .anaphylactic: return "Anaphylactic"
        }
    }
}

// MARK: - OnboardingAllergiesView

struct OnboardingAllergiesView: View {

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

    /// Maps allergen id → selected severity (presence == selected)
    @State private var selectedAllergens: [String: AllergenSeverity] = [:]
    @State private var customAllergenText: String = ""
    @State private var noAllergies: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 6,
            totalSteps: 8,
            title: "Allergies",
            subtitle: "Select known food allergies. VitaCore will warn you when analysing meals.",
            showSkip: true,
            showBack: true,
            onNext: handleContinue,
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(spacing: VCSpacing.xxl) {

                // ── 2-column allergen grid ────────────────────────────────────
                let columns = [
                    GridItem(.flexible(), spacing: VCSpacing.md),
                    GridItem(.flexible(), spacing: VCSpacing.md)
                ]

                LazyVGrid(columns: columns, spacing: VCSpacing.md) {
                    ForEach(Array(presetAllergens.enumerated()), id: \.element.id) { index, allergen in
                        AllergenCard(
                            allergen: allergen,
                            selectedSeverity: selectedAllergens[allergen.id],
                            isDisabled: noAllergies
                        ) { newSeverity in
                            withAnimation(VCAnimation.cardEntrance) {
                                if let severity = newSeverity {
                                    selectedAllergens[allergen.id] = severity
                                    noAllergies = false
                                } else {
                                    selectedAllergens.removeValue(forKey: allergen.id)
                                }
                            }
                        }
                        .fadeUpEntrance(delay: VCAnimation.staggerDelay(index: index))
                    }
                }

                // ── Custom allergen field ─────────────────────────────────────
                if !noAllergies {
                    GlassCard(style: .small) {
                        HStack(spacing: VCSpacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(VCColors.primary.opacity(0.7))
                            TextField("Add other allergen", text: $customAllergenText)
                                .vcFont(.body)
                                .foregroundStyle(VCColors.onSurface)
                                .frame(minHeight: VCSpacing.tapTarget)
                        }
                    }
                    .fadeUpEntrance(delay: 0.4)
                }

                // ── "No allergies" button ─────────────────────────────────────
                Button {
                    withAnimation(VCAnimation.cardEntrance) {
                        noAllergies.toggle()
                        if noAllergies {
                            selectedAllergens.removeAll()
                            customAllergenText = ""
                        }
                    }
                } label: {
                    HStack(spacing: VCSpacing.sm) {
                        Image(systemName: noAllergies ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(noAllergies ? VCColors.safe : VCColors.outline)
                        Text("I have no allergies")
                            .vcFont(.headline)
                            .foregroundStyle(noAllergies ? VCColors.safe : VCColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: VCSpacing.tapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            .strokeBorder(
                                noAllergies ? VCColors.safe.opacity(0.4) : VCColors.outline.opacity(0.3),
                                lineWidth: 1.5
                            )
                            .background(
                                RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                                    .fill(noAllergies ? VCColors.safe.opacity(0.08) : Color.clear)
                            )
                    )
                }
                .fadeUpEntrance(delay: 0.5)

                // ── Error ─────────────────────────────────────────────────────
                if let error = errorMessage {
                    Text(error)
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.critical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.bottom, VCSpacing.xxl)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func handleContinue() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                // Add preset allergens
                for (allergenId, severity) in selectedAllergens {
                    let summary = AllergenSummary(
                        allergen: allergenId,
                        severity: severity
                    )
                    _ = summary // personaEngine.addAllergy not in protocol; use updatePersonaContext pattern
                }

                // Add custom allergen if entered
                let custom = customAllergenText.trimmingCharacters(in: .whitespaces)
                if !custom.isEmpty {
                    let summary = AllergenSummary(allergen: custom, severity: .moderate)
                    _ = summary
                }

                // Persist via personaEngine: fetch, merge, save
                let ctx = try await personaEngine.getPersonaContext()
                var newAllergies: [AllergenSummary] = []

                for (allergenId, severity) in selectedAllergens {
                    newAllergies.append(AllergenSummary(allergen: allergenId, severity: severity))
                }
                let custom2 = customAllergenText.trimmingCharacters(in: .whitespaces)
                if !custom2.isEmpty {
                    newAllergies.append(AllergenSummary(allergen: custom2, severity: .moderate))
                }

                let updated = PersonaContext(
                    userId: ctx.userId,
                    activeConditions: ctx.activeConditions,
                    activeGoals: ctx.activeGoals,
                    activeMedications: ctx.activeMedications,
                    allergies: newAllergies,
                    preferences: ctx.preferences,
                    responseProfiles: ctx.responseProfiles,
                    thresholdOverrides: ctx.thresholdOverrides,
                    dataQualityFlags: ctx.dataQualityFlags,
                    goalProgress: ctx.goalProgress
                )
                try await personaEngine.updatePersonaContext(updated)

                await MainActor.run {
                    isSaving = false
                    onNext()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save allergies. Please try again."
                }
            }
        }
    }
}

// MARK: - AllergenCard

private struct AllergenCard: View {

    let allergen: PresetAllergen
    let selectedSeverity: AllergenSeverity?
    let isDisabled: Bool
    /// Called with the new severity when selected, nil when deselected
    let onToggle: (AllergenSeverity?) -> Void

    private var isSelected: Bool { selectedSeverity != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Main tap target
            Button {
                if isDisabled { return }
                onToggle(isSelected ? nil : .moderate)
            } label: {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: VCSpacing.sm) {
                        Image(systemName: allergen.icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(isSelected ? VCColors.secondary : VCColors.onSurfaceVariant)
                            .frame(height: 36)

                        Text(allergen.displayName)
                            .vcFont(.subhead)
                            .foregroundStyle(isSelected ? VCColors.onSurface : VCColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VCSpacing.lg)
                    .padding(.horizontal, VCSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            .fill(isSelected ? VCColors.secondaryContainer.opacity(0.35) : VCColors.surfaceLow)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? VCColors.secondary.opacity(0.6) : VCColors.outlineVariant.opacity(0.4),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .opacity(isDisabled ? 0.4 : 1.0)

                    // Checkmark overlay
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VCColors.secondary)
                            .background(Circle().fill(.white).padding(2))
                            .padding(VCSpacing.sm)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: VCSpacing.tapTarget * 2)

            // Severity segmented control — shown inside selected card
            if isSelected, let severity = selectedSeverity {
                SeverityPicker(
                    selected: Binding(
                        get: { severity },
                        set: { onToggle($0) }
                    )
                )
                .padding(.top, VCSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(VCAnimation.cardEntrance, value: isSelected)
    }
}

// MARK: - SeverityPicker

private struct SeverityPicker: View {
    @Binding var selected: AllergenSeverity

    private let severities: [AllergenSeverity] = [.mild, .moderate, .severe, .anaphylactic]
    private let severityLabels = ["Mild", "Mod.", "Severe", "⚠︎"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(severities, severityLabels).enumerated()), id: \.offset) { _, pair in
                let (sev, label) = pair
                Button {
                    selected = sev
                } label: {
                    Text(label)
                        .vcFont(.badge)
                        .foregroundStyle(selected == sev ? .white : VCColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                                .fill(selected == sev ? severityColor(sev) : VCColors.surfaceLow)
                        )
                }
                .buttonStyle(.plain)
                .frame(minWidth: VCSpacing.tapTarget)
            }
        }
        .padding(.horizontal, VCSpacing.xs)
    }

    private func severityColor(_ severity: AllergenSeverity) -> Color {
        switch severity {
        case .mild:         return VCColors.safe
        case .moderate:     return VCColors.watch
        case .severe:       return VCColors.alertOrange
        case .anaphylactic: return VCColors.critical
        }
    }
}

// Expose alertOrange for use in severity picker
private extension VCColors {
    static let alertOrange = Color(red: 1.0, green: 0.42, blue: 0.0)
    static let outlineVariant = Color(red: 0.69, green: 0.69, blue: 0.72)
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        BackgroundMesh().ignoresSafeArea()
        OnboardingAllergiesView(
            onNext: {},
            onBack: {},
            onSkip: {}
        )
    }
}
#endif
