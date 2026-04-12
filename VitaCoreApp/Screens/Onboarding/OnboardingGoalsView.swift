// OnboardingGoalsView.swift
// VitaCoreApp — OB-04: Health Goals
//
// Step 4 of 8 — choose 1-3 goals from all 14 GoalType values.
// Each selected goal reveals an inline target-value slider with a
// sensible range and unit label. Optional (can be skipped).

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - GoalInfo

/// Display metadata for each GoalType, including slider config.
private struct GoalInfo {
    let type: GoalType
    let displayName: String
    let unit: String
    let icon: String
    let color: Color
    let sliderMin: Double
    let sliderMax: Double
    let defaultValue: Double
    let step: Double
    let format: String     // e.g. "%.1f" or "%.0f"

    /// Formatted string for the current slider value.
    func formatted(_ value: Double) -> String {
        String(format: format, value) + " " + unit
    }

    static let all: [GoalInfo] = [
        GoalInfo(type: .glucoseA1C,       displayName: "Glucose A1C",        unit: "%",     icon: "drop.fill",              color: VCColors.tertiary,   sliderMin: 5.0,  sliderMax: 9.0,   defaultValue: 7.0,   step: 0.1, format: "%.1f"),
        GoalInfo(type: .bpSystolic,       displayName: "Blood Pressure",      unit: "mmHg",  icon: "heart.circle.fill",      color: VCColors.secondary,  sliderMin: 110,  sliderMax: 140,   defaultValue: 120,   step: 1,   format: "%.0f"),
        GoalInfo(type: .bpDiastolic,      displayName: "Diastolic BP",        unit: "mmHg",  icon: "heart.circle",           color: VCColors.secondary,  sliderMin: 60,   sliderMax: 95,    defaultValue: 80,    step: 1,   format: "%.0f"),
        GoalInfo(type: .stepsDaily,       displayName: "Daily Steps",         unit: "steps", icon: "figure.walk",            color: VCColors.safe,       sliderMin: 3000, sliderMax: 15000, defaultValue: 10000, step: 500, format: "%.0f"),
        GoalInfo(type: .weightTarget,     displayName: "Weight Target",       unit: "kg",    icon: "scalemass.fill",         color: VCColors.primary,    sliderMin: 40,   sliderMax: 150,   defaultValue: 75,    step: 0.5, format: "%.1f"),
        GoalInfo(type: .sleepDuration,    displayName: "Sleep Duration",      unit: "hrs",   icon: "moon.stars.fill",        color: VCColors.primaryDim, sliderMin: 5,    sliderMax: 10,    defaultValue: 8,     step: 0.5, format: "%.1f"),
        GoalInfo(type: .fluidDaily,       displayName: "Daily Hydration",     unit: "mL",    icon: "drop.triangle.fill",     color: VCColors.tertiary,   sliderMin: 1000, sliderMax: 4000,  defaultValue: 2500,  step: 250, format: "%.0f"),
        GoalInfo(type: .caloriesDaily,    displayName: "Daily Calories",      unit: "kcal",  icon: "flame.fill",             color: VCColors.watch,      sliderMin: 1200, sliderMax: 3500,  defaultValue: 2000,  step: 50,  format: "%.0f"),
        GoalInfo(type: .carbsDaily,       displayName: "Daily Carbs",         unit: "g",     icon: "leaf.fill",              color: VCColors.safe,       sliderMin: 20,   sliderMax: 300,   defaultValue: 130,   step: 5,   format: "%.0f"),
        GoalInfo(type: .proteinDaily,     displayName: "Daily Protein",       unit: "g",     icon: "fish.fill",              color: VCColors.secondary,  sliderMin: 40,   sliderMax: 200,   defaultValue: 80,    step: 5,   format: "%.0f"),
        GoalInfo(type: .exerciseMinutes,  displayName: "Exercise / Day",      unit: "min",   icon: "figure.run",             color: VCColors.safe,       sliderMin: 15,   sliderMax: 120,   defaultValue: 30,    step: 5,   format: "%.0f"),
        GoalInfo(type: .timeInRange,      displayName: "Glucose Time in Range", unit: "%",   icon: "chart.line.uptrend.xyaxis", color: VCColors.tertiary, sliderMin: 50,   sliderMax: 100,   defaultValue: 70,    step: 1,   format: "%.0f"),
        GoalInfo(type: .restingHR,        displayName: "Resting Heart Rate",  unit: "bpm",   icon: "waveform.path.ecg",      color: VCColors.secondary,  sliderMin: 45,   sliderMax: 90,    defaultValue: 60,    step: 1,   format: "%.0f"),
        GoalInfo(type: .hrvTarget,        displayName: "Heart Rate Variability", unit: "ms", icon: "waveform",               color: VCColors.primary,    sliderMin: 20,   sliderMax: 100,   defaultValue: 50,    step: 1,   format: "%.0f"),
    ]
}

// MARK: - GoalSelection

/// Holds a goal's selection state and current target value.
private struct GoalSelection {
    var isSelected: Bool = false
    var targetValue: Double
}

// MARK: - OnboardingGoalsView

struct OnboardingGoalsView: View {

    // -------------------------------------------------------------------------
    // MARK: Constants
    // -------------------------------------------------------------------------

    private let maxGoals = 3

    // -------------------------------------------------------------------------
    // MARK: Callbacks
    // -------------------------------------------------------------------------

    let onNext: () -> Void   // called by "Save & Continue" or "Skip for Now"
    let onBack: () -> Void   // called by back chevron
    let onSkip: () -> Void   // called by "Skip" button

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    @Environment(\.personaEngine) private var personaEngine

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var selections: [GoalType: GoalSelection] = {
        var dict: [GoalType: GoalSelection] = [:]
        for info in GoalInfo.all {
            dict[info.type] = GoalSelection(targetValue: info.defaultValue)
        }
        return dict
    }()

    @State private var isSaving: Bool = false
    @State private var showMaxWarning: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Derived
    // -------------------------------------------------------------------------

    private var selectedCount: Int {
        selections.values.filter(\.isSelected).count
    }

    private var atMax: Bool { selectedCount >= maxGoals }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 4,
            totalSteps: 8,
            title: "Your Goals",
            subtitle: "Choose 1-3 goals. We'll track your progress daily.",
            showSkip: true,
            showBack: true,
            onNext: handleContinue,
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(spacing: VCSpacing.md) {
                // Selection counter + max warning
                statusBar
                    .padding(.horizontal, VCSpacing.xxl)
                    .fadeUpEntrance(delay: 0.1)

                // Goal list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: VCSpacing.md) {
                        ForEach(Array(GoalInfo.all.enumerated()), id: \.element.type) { idx, info in
                            GoalCard(
                                info: info,
                                selection: binding(for: info.type),
                                isDisabled: atMax && !(selections[info.type]?.isSelected ?? false),
                                onTap: { handleTap(info) }
                            )
                            .fadeUpEntrance(delay: VCAnimation.staggerDelay(index: idx))
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.bottom, VCSpacing.xxl)
                }

                // Continue button
                VCPrimaryButton(
                    title: isSaving ? "Saving..." : (selectedCount == 0 ? "Skip for Now" : "Save & Continue"),
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

    private var statusBar: some View {
        HStack {
            // Selection counter pill
            HStack(spacing: VCSpacing.xs) {
                ForEach(0..<maxGoals, id: \.self) { i in
                    Circle()
                        .fill(i < selectedCount ? VCColors.primary : VCColors.outlineVariant.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .animation(VCAnimation.valueSpring, value: selectedCount)
                }

                Text("\(selectedCount) of \(maxGoals) selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selectedCount > 0 ? VCColors.primary : VCColors.outline)
            }
            .padding(.horizontal, VCSpacing.md)
            .padding(.vertical, VCSpacing.xs)
            .background(
                Capsule()
                    .fill(selectedCount > 0 ? VCColors.primaryContainer.opacity(0.3) : VCColors.surfaceLow)
            )

            Spacer()

            if showMaxWarning {
                Text("Maximum 3 goals")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VCColors.watch)
                    .transition(.opacity)
            }
        }
        .animation(VCAnimation.valueSpring, value: showMaxWarning)
    }

    // -------------------------------------------------------------------------
    // MARK: Interaction
    // -------------------------------------------------------------------------

    private func binding(for type: GoalType) -> Binding<GoalSelection> {
        Binding(
            get: { selections[type] ?? GoalSelection(targetValue: GoalInfo.all.first(where: { $0.type == type })?.defaultValue ?? 0) },
            set: { selections[type] = $0 }
        )
    }

    private func handleTap(_ info: GoalInfo) {
        let isCurrentlySelected = selections[info.type]?.isSelected ?? false

        if !isCurrentlySelected && atMax {
            // Flash the max warning
            withAnimation(VCAnimation.valueSpring) { showMaxWarning = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(VCAnimation.valueSpring) { showMaxWarning = false }
            }
            return
        }

        withAnimation(VCAnimation.cardEntrance) {
            selections[info.type]?.isSelected.toggle()
        }
    }

    private func handleContinue() {
        isSaving = true

        Task {
            do {
                let currentContext = try await personaEngine.getPersonaContext()

                let newGoals: [GoalSummary] = GoalInfo.all.compactMap { info in
                    guard let sel = selections[info.type], sel.isSelected else { return nil }
                    return GoalSummary(
                        goalType: info.type,
                        target: sel.targetValue,
                        current: 0,
                        direction: 1
                    )
                }

                let updatedContext = PersonaContext(
                    userId: currentContext.userId,
                    activeConditions: currentContext.activeConditions,
                    activeGoals: newGoals,
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
                // Non-fatal: goals can be set later in Settings
            }

            await MainActor.run {
                isSaving = false
                onNext()
            }
        }
    }
}

// MARK: - GoalCard

private struct GoalCard: View {
    let info: GoalInfo
    @Binding var selection: GoalSelection
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button(action: onTap) {
                HStack(spacing: VCSpacing.md) {
                    // Coloured icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                            .fill(selection.isSelected ? info.color : VCColors.surfaceLow)
                            .frame(width: 40, height: 40)

                        Image(systemName: info.icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(selection.isSelected ? .white : VCColors.onSurfaceVariant)
                    }
                    .animation(VCAnimation.cardPress, value: selection.isSelected)

                    // Name + unit hint
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isDisabled && !selection.isSelected ? VCColors.outline : VCColors.onSurface)

                        Text(info.unit)
                            .font(.system(size: 12))
                            .foregroundColor(VCColors.onSurfaceVariant)
                    }

                    Spacer()

                    // Target value chip (when selected)
                    if selection.isSelected {
                        Text(info.formatted(selection.targetValue))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(info.color)
                            .padding(.horizontal, VCSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(info.color.opacity(0.12))
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }

                    // Selection indicator
                    ZStack {
                        Circle()
                            .fill(selection.isSelected ? info.color : VCColors.outlineVariant.opacity(0.4))
                            .frame(width: 24, height: 24)

                        if selection.isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(VCAnimation.cardPress, value: selection.isSelected)
                }
                .padding(VCSpacing.md)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled && !selection.isSelected)

            // Inline slider — only when selected
            if selection.isSelected {
                VStack(spacing: VCSpacing.sm) {
                    // Hairline divider
                    Rectangle()
                        .fill(info.color.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, VCSpacing.md)

                    VStack(alignment: .leading, spacing: VCSpacing.xs) {
                        HStack {
                            Text("Target")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(VCColors.outline)
                            Spacer()
                            Text(info.formatted(selection.targetValue))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(info.color)
                        }
                        .padding(.horizontal, VCSpacing.md)

                        Slider(
                            value: Binding(
                                get: { selection.targetValue },
                                set: { newVal in
                                    // Snap to step
                                    let stepped = (newVal / info.step).rounded() * info.step
                                    selection.targetValue = min(info.sliderMax, max(info.sliderMin, stepped))
                                }
                            ),
                            in: info.sliderMin...info.sliderMax
                        )
                        .tint(info.color)
                        .padding(.horizontal, VCSpacing.md)

                        HStack {
                            Text(info.formatted(info.sliderMin))
                                .font(.system(size: 10))
                                .foregroundColor(VCColors.outline)
                            Spacer()
                            Text(info.formatted(info.sliderMax))
                                .font(.system(size: 10))
                                .foregroundColor(VCColors.outline)
                        }
                        .padding(.horizontal, VCSpacing.md)
                    }
                    .padding(.bottom, VCSpacing.md)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                .fill(selection.isSelected ? VCColors.primaryContainer.opacity(0.20) : VCColors.surfaceLowest)
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                        .strokeBorder(
                            selection.isSelected ? info.color.opacity(0.35) : VCColors.outlineVariant.opacity(0.25),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(
            color: selection.isSelected ? info.color.opacity(0.10) : VCColors.glassShadow.opacity(0.4),
            radius: selection.isSelected ? 10 : 4,
            x: 0, y: 2
        )
        .opacity(isDisabled && !selection.isSelected ? 0.45 : 1)
        .animation(VCAnimation.cardEntrance, value: selection.isSelected)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("OB-04 Goals") {
    OnboardingGoalsView(onNext: {}, onBack: {}, onSkip: {})
}
#endif
