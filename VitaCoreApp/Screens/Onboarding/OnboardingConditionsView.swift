// OnboardingConditionsView.swift
// VitaCoreApp — OB-03: Health Conditions
//
// Step 3 of 8 — multi-select grid of all 17 ConditionKey values.
// Optional step (user can skip). Search bar filters visible cards.
// Selected conditions are persisted via personaEngine.updatePersonaContext().

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - ConditionInfo

/// Display metadata for each ConditionKey.
private struct ConditionInfo {
    let key: ConditionKey
    let displayName: String
    let description: String
    let icon: String

    static let all: [ConditionInfo] = [
        ConditionInfo(key: .type2Diabetes,      displayName: "Type 2 Diabetes",        description: "Insulin resistance and elevated blood glucose",        icon: "drop.fill"),
        ConditionInfo(key: .type1Diabetes,      displayName: "Type 1 Diabetes",         description: "Autoimmune condition requiring insulin therapy",        icon: "drop.halffull"),
        ConditionInfo(key: .prediabetes,        displayName: "Prediabetes",             description: "Blood glucose above normal but below diabetes range",   icon: "drop"),
        ConditionInfo(key: .hypertension,       displayName: "Hypertension",            description: "Stage 1 elevated blood pressure (130-139 / 80-89)",    icon: "heart.circle"),
        ConditionInfo(key: .hypertensionS2,     displayName: "Hypertension Stage 2",    description: "Stage 2 elevated blood pressure (≥140 / ≥90)",          icon: "heart.circle.fill"),
        ConditionInfo(key: .cardiacRisk,        displayName: "Cardiac Risk",            description: "Elevated risk of cardiovascular events",               icon: "waveform.path.ecg"),
        ConditionInfo(key: .heartFailure,       displayName: "Heart Failure",           description: "Reduced cardiac output requiring management",          icon: "heart.slash"),
        ConditionInfo(key: .elderly65Plus,      displayName: "Age 65+",                 description: "Age-related adjustments to thresholds and alerts",     icon: "person.fill.badge.plus"),
        ConditionInfo(key: .hypothyroidism,     displayName: "Hypothyroidism",          description: "Underactive thyroid affecting metabolism",             icon: "thermometer.low"),
        ConditionInfo(key: .hyperthyroidism,    displayName: "Hyperthyroidism",         description: "Overactive thyroid causing elevated metabolism",       icon: "thermometer.high"),
        ConditionInfo(key: .ckd,                displayName: "Chronic Kidney Disease",  description: "Reduced kidney function requiring dietary monitoring", icon: "kidneys"),
        ConditionInfo(key: .copd,               displayName: "COPD",                    description: "Chronic obstructive pulmonary disease",               icon: "lungs.fill"),
        ConditionInfo(key: .obesity,            displayName: "Obesity",                 description: "BMI ≥30, increased cardiometabolic risk",              icon: "scalemass.fill"),
        ConditionInfo(key: .pcos,               displayName: "PCOS",                    description: "Polycystic ovary syndrome affecting hormones",        icon: "circle.hexagongrid"),
        ConditionInfo(key: .ironDeficiency,     displayName: "Iron Deficiency",         description: "Low iron affecting energy and red blood cells",        icon: "bolt.slash"),
        ConditionInfo(key: .vitaminDDeficiency, displayName: "Vitamin D Deficiency",    description: "Insufficient vitamin D affecting bone and immunity",  icon: "sun.min"),
        ConditionInfo(key: .healthyBaseline,    displayName: "Healthy Baseline",        description: "No current diagnosed conditions to manage",           icon: "checkmark.seal.fill"),
    ]
}

// MARK: - OnboardingConditionsView

struct OnboardingConditionsView: View {

    // -------------------------------------------------------------------------
    // MARK: Callbacks
    // -------------------------------------------------------------------------

    let onNext: () -> Void   // called by "Save & Continue" or "Continue"
    let onBack: () -> Void   // called by back chevron
    let onSkip: () -> Void   // called by "Skip" button

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    @Environment(\.personaEngine) private var personaEngine

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var selectedKeys: Set<ConditionKey> = []
    @State private var searchText: String = ""
    @State private var isSaving: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Filtering
    // -------------------------------------------------------------------------

    private var filteredConditions: [ConditionInfo] {
        guard !searchText.isEmpty else { return ConditionInfo.all }
        return ConditionInfo.all.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 3,
            totalSteps: 8,
            title: "Health Conditions",
            subtitle: "Select any conditions you manage. This personalises your thresholds and alerts.",
            showSkip: true,
            showBack: true,
            onNext: handleContinue,
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(spacing: VCSpacing.lg) {
                // Search bar
                searchBar
                    .padding(.horizontal, VCSpacing.xxl)
                    .fadeUpEntrance(delay: 0.1)

                // Selection counter
                if !selectedKeys.isEmpty {
                    selectionCounter
                        .padding(.horizontal, VCSpacing.xxl)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // Condition grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: VCSpacing.md),
                            GridItem(.flexible(), spacing: VCSpacing.md)
                        ],
                        spacing: VCSpacing.md
                    ) {
                        ForEach(Array(filteredConditions.enumerated()), id: \.element.key) { idx, info in
                            ConditionCard(
                                info: info,
                                isSelected: selectedKeys.contains(info.key),
                                onTap: { toggleCondition(info.key) }
                            )
                            .fadeUpEntrance(delay: VCAnimation.staggerDelay(index: idx))
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.xxl)
                }

                // Continue button (outside scroll)
                VCPrimaryButton(
                    title: isSaving ? "Saving..." : (selectedKeys.isEmpty ? "Continue" : "Save & Continue"),
                    isDisabled: isSaving,
                    action: handleContinue
                )
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.bottom, VCSpacing.xxl)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Sub-views
    // -------------------------------------------------------------------------

    private var searchBar: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(VCColors.outline)

            TextField("Search conditions…", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(VCColors.onSurface)
                .tint(VCColors.primary)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(VCColors.outline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VCSpacing.md)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                        .strokeBorder(VCColors.glassBorder, lineWidth: 1)
                )
        )
    }

    private var selectionCounter: some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.primary)

            Text("\(selectedKeys.count) condition\(selectedKeys.count == 1 ? "" : "s") selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.primary)
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.xs)
        .background(
            Capsule()
                .fill(VCColors.primaryContainer.opacity(0.3))
        )
        .animation(VCAnimation.valueSpring, value: selectedKeys.count)
    }

    // -------------------------------------------------------------------------
    // MARK: Interaction
    // -------------------------------------------------------------------------

    private func toggleCondition(_ key: ConditionKey) {
        withAnimation(VCAnimation.cardPress) {
            if selectedKeys.contains(key) {
                selectedKeys.remove(key)
            } else {
                // Selecting "Healthy Baseline" clears all other selections
                if key == .healthyBaseline {
                    selectedKeys = [key]
                } else {
                    // Selecting any condition clears healthyBaseline
                    selectedKeys.remove(.healthyBaseline)
                    selectedKeys.insert(key)
                }
            }
        }
    }

    private func handleContinue() {
        isSaving = true

        Task {
            do {
                let currentContext = try await personaEngine.getPersonaContext()

                let newConditions = selectedKeys.map { key in
                    ConditionSummary(conditionKey: key, severity: "moderate", daysActive: 0)
                }

                let updatedContext = PersonaContext(
                    userId: currentContext.userId,
                    activeConditions: newConditions,
                    activeGoals: currentContext.activeGoals,
                    activeMedications: currentContext.activeMedications,
                    allergies: currentContext.allergies,
                    preferences: currentContext.preferences,
                    responseProfiles: currentContext.responseProfiles,
                    thresholdOverrides: currentContext.thresholdOverrides,
                    dataQualityFlags: currentContext.dataQualityFlags,
                    goalProgress: currentContext.goalProgress
                )

                try await personaEngine.updatePersonaContext(updatedContext)
            } catch {
                // Non-fatal: conditions can be set later in Settings
            }

            await MainActor.run {
                isSaving = false
                onNext()
            }
        }
    }
}

// MARK: - ConditionCard

private struct ConditionCard: View {
    let info: ConditionInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                // Icon + checkmark row
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? VCColors.primary : VCColors.surfaceLow)
                            .frame(width: 36, height: 36)

                        Image(systemName: info.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isSelected ? .white : VCColors.onSurfaceVariant)
                    }

                    Spacer()

                    // Checkmark
                    ZStack {
                        Circle()
                            .fill(isSelected ? VCColors.primary : VCColors.outlineVariant.opacity(0.4))
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(VCAnimation.cardPress, value: isSelected)
                }

                // Name
                Text(info.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Description
                Text(info.description)
                    .font(.system(size: 11))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(VCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                    .fill(isSelected ? VCColors.primaryContainer.opacity(0.35) : VCColors.surfaceLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? VCColors.primary.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(
                color: isSelected ? VCColors.primary.opacity(0.12) : VCColors.glassShadow.opacity(0.5),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .pressEffect()
        .animation(VCAnimation.cardPress, value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("OB-03 Conditions") {
    OnboardingConditionsView(onNext: {}, onBack: {}, onSkip: {})
}
#endif
