import SwiftUI
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation

struct SettingsMainView: View {
    @Environment(\.personaEngine) var personaEngine
    @State private var personaContext: PersonaContext?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    // Profile header card
                    profileHeader

                    // Persona section
                    sectionGroup(title: "PERSONAL") {
                        navigationRow(icon: "person.fill", iconColor: VCColors.primary, title: "Profile", subtitle: "Name, age, sex", destination: "profile")
                        navigationRow(icon: "heart.text.square.fill", iconColor: VCColors.secondary, title: "Conditions", subtitle: subtitleForConditions(), destination: "conditions")
                        navigationRow(icon: "target", iconColor: VCColors.tertiary, title: "Goals", subtitle: subtitleForGoals(), destination: "goals")
                        navigationRow(icon: "pills.fill", iconColor: VCColors.primary, title: "Medications", subtitle: subtitleForMedications(), destination: "medications")
                        navigationRow(icon: "exclamationmark.triangle.fill", iconColor: VCColors.watch, title: "Allergies", subtitle: subtitleForAllergies(), destination: "allergies")
                    }

                    // Connections section
                    sectionGroup(title: "DATA & DEVICES") {
                        navigationRow(icon: "antenna.radiowaves.left.and.right", iconColor: VCColors.tertiary, title: "Connections", subtitle: "Devices and data sources", destination: "connections")
                        navigationRow(icon: "bell.fill", iconColor: VCColors.watch, title: "Notifications", subtitle: "Alerts, reminders, quiet hours", destination: "notifications")
                    }

                    // Data ops section
                    sectionGroup(title: "DATA OPERATIONS") {
                        navigationRow(icon: "lock.shield.fill", iconColor: VCColors.safe, title: "Privacy", subtitle: "Data retention and deletion", destination: "privacy")
                        navigationRow(icon: "icloud.fill", iconColor: VCColors.tertiary, title: "Backup & Restore", subtitle: "iCloud encrypted backup", destination: "backup")
                        navigationRow(icon: "square.and.arrow.up.fill", iconColor: VCColors.primary, title: "Export", subtitle: "PDF, JSON-LD, clinician summary", destination: "export")
                    }

                    // About section
                    sectionGroup(title: "ABOUT") {
                        navigationRow(icon: "info.circle.fill", iconColor: VCColors.outline, title: "About VitaCore", subtitle: "Version, licenses, policies", destination: "about")
                    }

                    // Footer
                    Text("VitaCore v1.0 · On-device AI")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VCColors.outline)
                        .padding(.top, VCSpacing.lg)
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.vertical, VCSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: String.self) { destination in
            destinationView(for: destination)
        }
        .task {
            await loadPersona()
        }
    }

    @ViewBuilder
    func destinationView(for key: String) -> some View {
        switch key {
        case "profile":       ProfileSettingsView()
        case "conditions":    ConditionsSettingsView()
        case "goals":         GoalsSettingsView()
        case "medications":   MedicationsSettingsView()
        case "allergies":     AllergiesSettingsView()
        case "connections":   ConnectionsSettingsView()
        case "notifications": NotificationsSettingsView()
        case "privacy":       PrivacySettingsView()
        case "backup":        BackupRestoreSettingsView()
        case "export":        ExportSettingsView()
        case "about":         AboutSettingsView()
        default:              Text("Unknown")
        }
    }

    var profileHeader: some View {
        GlassCard(style: .hero) {
            HStack(spacing: VCSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [VCColors.primary, VCColors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    Text(personaContext != nil ? "P" : "?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Praba")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Member since 2026")
                        .font(.system(size: 13))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                    if let p = personaContext, !p.activeConditions.isEmpty {
                        Text(p.activeConditions.prefix(2).map { $0.conditionKey.displayName }.joined(separator: " · "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VCColors.tertiary)
                            .lineLimit(1)
                    } else {
                        Text("No conditions added")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }
                }

                Spacer()
            }
        }
    }

    func sectionGroup<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(VCColors.outline)
                .padding(.leading, VCSpacing.md)

            GlassCard(style: .standard) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    func navigationRow(icon: String, iconColor: Color, title: String, subtitle: String, destination: String) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VCColors.outline)
            }
            .padding(.vertical, VCSpacing.sm)
            .frame(minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }

    func subtitleForConditions() -> String {
        guard let p = personaContext else { return "Loading..." }
        return p.activeConditions.isEmpty ? "None active" : "\(p.activeConditions.count) active"
    }

    func subtitleForGoals() -> String {
        guard let p = personaContext else { return "Loading..." }
        return p.activeGoals.isEmpty ? "None set" : "\(p.activeGoals.count) tracked"
    }

    func subtitleForMedications() -> String {
        guard let p = personaContext else { return "Loading..." }
        return p.activeMedications.isEmpty ? "None" : "\(p.activeMedications.count) tracked"
    }

    func subtitleForAllergies() -> String {
        guard let p = personaContext else { return "Loading..." }
        return p.allergies.isEmpty ? "None" : "\(p.allergies.count) registered"
    }

    func loadPersona() async {
        do {
            personaContext = try await personaEngine.getPersonaContext()
        } catch {
            // Silent fail; persona stays nil
        }
        isLoading = false
    }
}

// MARK: - ConditionKey display name (shared extension)

extension ConditionKey {
    var displayName: String {
        switch self {
        case .type2Diabetes:      return "Type 2 Diabetes"
        case .type1Diabetes:      return "Type 1 Diabetes"
        case .prediabetes:        return "Prediabetes"
        case .hypertension:       return "Hypertension"
        case .hypertensionS2:     return "Hypertension Stage 2"
        case .cardiacRisk:        return "Cardiac Risk"
        case .heartFailure:       return "Heart Failure"
        case .elderly65Plus:      return "Age 65+"
        case .hypothyroidism:     return "Hypothyroidism"
        case .hyperthyroidism:    return "Hyperthyroidism"
        case .ckd:                return "Chronic Kidney Disease"
        case .copd:               return "COPD"
        case .obesity:            return "Obesity"
        case .pcos:               return "PCOS"
        case .ironDeficiency:     return "Iron Deficiency"
        case .vitaminDDeficiency: return "Vitamin D Deficiency"
        case .healthyBaseline:    return "Healthy Baseline"
        }
    }
}
