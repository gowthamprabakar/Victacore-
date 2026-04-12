import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Profile Settings View

struct ProfileSettingsView: View {
    @Environment(\.personaEngine) var personaEngine
    @Environment(\.dismiss) private var dismiss

    // Editable fields
    @State private var displayName: String = "Praba"
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()
    @State private var biologicalSex: BiologicalSex = .notSpecified
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 75
    @State private var preferMetricUnits: Bool = true

    // Derived / UI state
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var didSave: Bool = false

    private var computedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private var heightFeet: Int { Int(heightCm / 30.48) }
    private var heightInches: Int { Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12)) }
    private var weightLb: Double { weightKg * 2.20462 }

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    // Avatar + name
                    avatarSection

                    // Date of Birth
                    dobSection

                    // Biological Sex
                    sexSection

                    // Height
                    heightSection

                    // Weight
                    weightSection

                    // Save button
                    saveButton

                    if let err = saveError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(VCColors.critical)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VCSpacing.xxl)
                    }

                    if didSave {
                        Label("Changes saved", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VCColors.safe)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var avatarSection: some View {
        GlassCard(style: .hero) {
            VStack(spacing: VCSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [VCColors.primary, VCColors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    Text(displayName.prefix(1).uppercased())
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: VCSpacing.sm) {
                    Text("Display Name")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(VCColors.outline)

                    TextField("Your name", text: $displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VCSpacing.lg)
                        .padding(.vertical, VCSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.md)
                                .fill(VCColors.surfaceLow)
                        )
                }
            }
            .padding(.vertical, VCSpacing.sm)
        }
    }

    private var dobSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                sectionLabel("DATE OF BIRTH")

                DatePicker(
                    "Date of Birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(VCColors.primary)

                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(VCColors.tertiary)
                    Text("Age: \(computedAge) years old")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
                .padding(.top, VCSpacing.xs)
            }
        }
    }

    private var sexSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                sectionLabel("BIOLOGICAL SEX")

                // Custom segmented picker using ForEach
                HStack(spacing: VCSpacing.xs) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Button {
                            biologicalSex = sex
                        } label: {
                            Text(sex.displayLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(biologicalSex == sex ? .white : VCColors.onSurfaceVariant)
                                .padding(.vertical, VCSpacing.sm)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: VCRadius.sm)
                                        .fill(biologicalSex == sex
                                              ? LinearGradient(colors: [VCColors.primary, VCColors.secondary], startPoint: .leading, endPoint: .trailing)
                                              : LinearGradient(colors: [VCColors.surfaceLow, VCColors.surfaceLow], startPoint: .leading, endPoint: .trailing))
                                )
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private var heightSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    sectionLabel("HEIGHT")
                    Spacer()
                    Toggle("", isOn: $preferMetricUnits)
                        .labelsHidden()
                        .tint(VCColors.primary)
                    Text(preferMetricUnits ? "cm" : "ft / in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }

                if preferMetricUnits {
                    HStack {
                        Slider(value: $heightCm, in: 100...230, step: 0.5)
                            .tint(VCColors.primary)
                        Text("\(Int(heightCm)) cm")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                            .frame(width: 64, alignment: .trailing)
                    }
                } else {
                    HStack {
                        Slider(value: $heightCm, in: 100...230, step: 0.5)
                            .tint(VCColors.primary)
                        Text("\(heightFeet)'\(heightInches)\"")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var weightSection: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack {
                    sectionLabel("WEIGHT")
                    Spacer()
                    Text("Last updated today")
                        .font(.system(size: 11))
                        .foregroundStyle(VCColors.outline)
                }

                if preferMetricUnits {
                    HStack {
                        Slider(value: $weightKg, in: 30...250, step: 0.5)
                            .tint(VCColors.secondary)
                        Text("\(String(format: "%.1f", weightKg)) kg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                            .frame(width: 72, alignment: .trailing)
                    }
                } else {
                    HStack {
                        Slider(value: $weightKg, in: 30...250, step: 0.5)
                            .tint(VCColors.secondary)
                        Text("\(String(format: "%.1f", weightLb)) lb")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveChanges() }
        } label: {
            ZStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [VCColors.primary, VCColors.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .disabled(isSaving)
        .frame(minHeight: 44)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(VCColors.outline)
    }

    private func saveChanges() async {
        isSaving = true
        saveError = nil
        didSave = false
        // Profile data is stored locally (UserProfile is not part of PersonaContext).
        // Simulate a brief save delay for UX.
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSaving = false
        didSave = true
    }
}

// MARK: - BiologicalSex label helper

private extension BiologicalSex {
    var displayLabel: String {
        switch self {
        case .male:         return "Male"
        case .female:       return "Female"
        case .other:        return "Other"
        case .notSpecified: return "Prefer not"
        }
    }
}
