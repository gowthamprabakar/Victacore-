// OnboardingBasicProfileView.swift
// VitaCoreApp — OB-02: Basic Profile
//
// Step 2 of 8 — collects name, date of birth, biological sex,
// height, and weight. All fields except name and DOB are optional
// for form progress purposes, but the Continue button is gated on
// the two required fields (name + DOB) being non-empty.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - HeightUnit / WeightUnit

private enum HeightUnit: String, CaseIterable {
    case metric = "cm"
    case imperial = "ft / in"
}

private enum WeightUnit: String, CaseIterable {
    case kg = "kg"
    case lb = "lb"
}

// MARK: - OnboardingBasicProfileView

struct OnboardingBasicProfileView: View {

    // -------------------------------------------------------------------------
    // MARK: Callbacks
    // -------------------------------------------------------------------------

    let onNext: () -> Void
    let onBack: () -> Void

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    @Environment(\.personaEngine) private var personaEngine

    // -------------------------------------------------------------------------
    // MARK: Form State
    // -------------------------------------------------------------------------

    @State private var fullName: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(
        byAdding: .year, value: -30, to: Date()
    ) ?? Date()
    @State private var biologicalSex: BiologicalSex = .notSpecified
    @State private var heightCm: String = ""
    @State private var heightFt: String = ""
    @State private var heightIn: String = ""
    @State private var weightKg: String = ""
    @State private var weightLb: String = ""
    @State private var heightUnit: HeightUnit = .metric
    @State private var weightUnit: WeightUnit = .kg

    @State private var isSaving: Bool = false
    @State private var showDOBPicker: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Computed Validation
    // -------------------------------------------------------------------------

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var resolvedHeightCm: Double? {
        switch heightUnit {
        case .metric:
            return Double(heightCm)
        case .imperial:
            let ft = Double(heightFt) ?? 0
            let inches = Double(heightIn) ?? 0
            let total = ft * 30.48 + inches * 2.54
            return total > 0 ? total : nil
        }
    }

    private var formattedDOB: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: dateOfBirth)
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 2,
            totalSteps: 8,
            title: "About You",
            subtitle: "Tell us a bit about yourself so we can personalise your health experience.",
            showSkip: false,
            showBack: true,
            onNext: handleContinue,
            onSkip: nil,
            onBack: onBack
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: VCSpacing.lg) {
                    // Required fields group
                    requiredFieldsCard
                        .fadeUpEntrance(delay: 0.1)

                    // Body metrics group
                    bodyMetricsCard
                        .fadeUpEntrance(delay: 0.22)

                    // Continue button
                    VCPrimaryButton(
                        title: isSaving ? "Saving..." : "Continue",
                        isDisabled: !isValid || isSaving,
                        action: handleContinue
                    )
                    .fadeUpEntrance(delay: 0.34)
                    .padding(.top, VCSpacing.sm)
                    .padding(.bottom, VCSpacing.xxl)
                }
                .padding(.horizontal, VCSpacing.xxl)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Required Fields Card
    // -------------------------------------------------------------------------

    private var requiredFieldsCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.lg) {
                sectionHeader(icon: "person.fill", title: "Identity", required: true)

                // Full name
                VCTextField(
                    icon: "person",
                    placeholder: "Full Name",
                    text: $fullName,
                    required: true
                )

                OBDivider()

                // Date of birth — tappable row that expands the picker
                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    Button {
                        withAnimation(VCAnimation.cardEntrance) {
                            showDOBPicker.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(VCColors.primary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Date of Birth")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(VCColors.outline)
                                    Text("Required")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(VCColors.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(VCColors.secondaryContainer.opacity(0.6))
                                        )
                                }
                                Text(formattedDOB)
                                    .font(.system(size: 15))
                                    .foregroundColor(VCColors.onSurface)
                            }

                            Spacer()

                            Image(systemName: showDOBPicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VCColors.outline)
                        }
                    }
                    .buttonStyle(.plain)

                    if showDOBPicker {
                        DatePicker(
                            "",
                            selection: $dateOfBirth,
                            in: ...Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(VCColors.primary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                OBDivider()

                // Biological sex segmented picker
                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(VCColors.primary)
                            .frame(width: 20)
                        Text("Biological Sex")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(VCColors.outline)
                        Text("Required")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(VCColors.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VCColors.secondaryContainer.opacity(0.6)))
                    }

                    HStack(spacing: VCSpacing.xs) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            SexSegmentButton(
                                title: sex.displayName,
                                isSelected: biologicalSex == sex,
                                action: { biologicalSex = sex }
                            )
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Body Metrics Card
    // -------------------------------------------------------------------------

    private var bodyMetricsCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.lg) {
                sectionHeader(icon: "ruler", title: "Body Metrics", required: false)

                // Height row
                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    unitRowHeader(
                        icon: "arrow.up.and.down",
                        label: "Height",
                        unitOptions: HeightUnit.allCases.map(\.rawValue),
                        selectedIndex: heightUnit == .metric ? 0 : 1,
                        onUnitChange: { idx in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                heightUnit = idx == 0 ? .metric : .imperial
                            }
                        }
                    )

                    if heightUnit == .metric {
                        VCNumericField(placeholder: "Height (cm)", value: $heightCm, unit: "cm")
                    } else {
                        HStack(spacing: VCSpacing.sm) {
                            VCNumericField(placeholder: "Feet", value: $heightFt, unit: "ft")
                            VCNumericField(placeholder: "Inches", value: $heightIn, unit: "in")
                        }
                    }
                }

                OBDivider()

                // Weight row
                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    unitRowHeader(
                        icon: "scalemass",
                        label: "Weight",
                        unitOptions: WeightUnit.allCases.map(\.rawValue),
                        selectedIndex: weightUnit == .kg ? 0 : 1,
                        onUnitChange: { idx in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                weightUnit = idx == 0 ? .kg : .lb
                            }
                        }
                    )

                    VCNumericField(
                        placeholder: "Weight",
                        value: weightUnit == .kg ? $weightKg : $weightLb,
                        unit: weightUnit.rawValue
                    )
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helper Views
    // -------------------------------------------------------------------------

    private func sectionHeader(icon: String, title: String, required: Bool) -> some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VCColors.primary)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(VCColors.outline)
                .tracking(1.5)

            if !required {
                Spacer()
                Text("OPTIONAL")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(VCColors.outline)
                    .tracking(1)
            }
        }
    }

    private func unitRowHeader(
        icon: String,
        label: String,
        unitOptions: [String],
        selectedIndex: Int,
        onUnitChange: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VCColors.primary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.onSurfaceVariant)

            Spacer()

            // Compact unit toggle
            HStack(spacing: 2) {
                ForEach(Array(unitOptions.enumerated()), id: \.offset) { idx, unit in
                    Button {
                        onUnitChange(idx)
                    } label: {
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(idx == selectedIndex ? .white : VCColors.outline)
                            .padding(.horizontal, VCSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(idx == selectedIndex ? VCColors.primary : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(VCColors.surfaceLow)
            )
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Save Logic
    // -------------------------------------------------------------------------

    private func handleContinue() {
        guard isValid else { return }
        isSaving = true

        Task {
            do {
                // Build a new PersonaContext incorporating the entered profile
                let currentContext = try await personaEngine.getPersonaContext()
                let updatedContext = PersonaContext(
                    userId: currentContext.userId,
                    activeConditions: currentContext.activeConditions,
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
                // Non-fatal: profile can be set later in Settings
            }

            await MainActor.run {
                isSaving = false
                onNext()
            }
        }
    }
}

// MARK: - SexSegmentButton

private struct SexSegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? VCColors.primary : VCColors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                        .fill(isSelected ? VCColors.primaryContainer.opacity(0.5) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                        .strokeBorder(
                            isSelected ? VCColors.primary.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(VCAnimation.cardPress, value: isSelected)
    }
}

// MARK: - VCTextField

/// Labelled text field styled for onboarding glass cards.
private struct VCTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let required: Bool

    var body: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(VCColors.primary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(placeholder)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(VCColors.outline)
                    if required {
                        Text("Required")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(VCColors.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VCColors.secondaryContainer.opacity(0.6)))
                    }
                }
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(VCColors.onSurface)
                    .tint(VCColors.primary)
                    .submitLabel(.done)
            }
        }
    }
}

// MARK: - VCNumericField

/// Numeric input field with inline unit label.
private struct VCNumericField: View {
    let placeholder: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack(spacing: VCSpacing.xs) {
            TextField(placeholder, text: $value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(VCColors.onSurface)
                .tint(VCColors.primary)
                .keyboardType(.decimalPad)
                .frame(maxWidth: .infinity)

            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.outline)
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                .fill(VCColors.surfaceLow)
        )
    }
}

// MARK: - OBDivider

private struct OBDivider: View {
    var body: some View {
        Rectangle()
            .fill(VCColors.outlineVariant.opacity(0.4))
            .frame(height: 0.5)
    }
}

// MARK: - BiologicalSex + Display Name

private extension BiologicalSex {
    var displayName: String {
        switch self {
        case .male:         return "Male"
        case .female:       return "Female"
        case .other:        return "Other"
        case .notSpecified: return "Prefer not to say"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("OB-02 Basic Profile") {
    OnboardingBasicProfileView(onNext: {}, onBack: {})
}
#endif
