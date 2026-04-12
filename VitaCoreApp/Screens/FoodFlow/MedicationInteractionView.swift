// MedicationInteractionView.swift
// VitaCore — Food Flow Stage 5b: Medication Interaction Warning
//
// Full-screen gate using BackgroundMesh + GlassCard surfaces.
// More nuanced than the allergen barrier — allows "Log Anyway" for non-severe.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - MedicationInteractionView

struct MedicationInteractionView: View {

    // MARK: Props
    let interaction: MedicationInteraction
    let onAcknowledge: () -> Void  // "Log Anyway"
    let onDiscard: () -> Void       // "Discard This Food"

    // MARK: Computed helpers

    var severityColor: Color {
        switch interaction.severity {
        case .caution:  return VCColors.watch
        case .moderate: return VCColors.alertOrange
        case .severe:   return VCColors.critical
        }
    }

    var severityLabel: String {
        switch interaction.severity {
        case .caution:  return "CAUTION"
        case .moderate: return "MODERATE INTERACTION"
        case .severe:   return "SEVERE INTERACTION"
        }
    }

    var severityIcon: String {
        switch interaction.severity {
        case .caution:  return "exclamationmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe:   return "xmark.octagon.fill"
        }
    }

    var medicationClassName: String {
        switch interaction.medicationClass {
        case .warfarin:             return "Anticoagulant"
        case .maoi:                 return "MAO Inhibitor (MAOI)"
        case .statin:               return "Statin"
        case .aceInhibitor:         return "Antihypertensive"
        case .metformin:            return "Antidiabetic"
        case .levothyroxine:        return "Thyroid Medication"
        case .other:                return "Prescription Medication"
        default:                    return "Prescription Medication"
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VCSpacing.xl) {

                    // ── Header: Icon + Title + Severity ─────────────────────
                    headerSection

                    // ── Medication card ──────────────────────────────────────
                    GlassCard(style: .standard) {
                        VStack(alignment: .leading, spacing: VCSpacing.sm) {
                            sectionLabel("YOUR MEDICATION")

                            Text(interaction.medication)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(VCColors.onSurface)

                            Text(medicationClassName)
                                .font(.system(size: 13))
                                .foregroundColor(VCColors.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── Food card ────────────────────────────────────────────
                    GlassCard(style: .standard) {
                        VStack(alignment: .leading, spacing: VCSpacing.sm) {
                            sectionLabel("DETECTED IN MEAL")

                            Text(interaction.food)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(VCColors.onSurface)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── Description + Recommendation card ────────────────────
                    GlassCard(style: .enhanced) {
                        VStack(alignment: .leading, spacing: VCSpacing.md) {
                            Label("What this means", systemImage: "info.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(severityColor)

                            Text(interaction.description)
                                .font(.system(size: 14))
                                .foregroundColor(VCColors.onSurface)
                                .lineSpacing(3)

                            Divider()

                            Label("Recommendation", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VCColors.safe)

                            Text(interaction.recommendation)
                                .font(.system(size: 14))
                                .foregroundColor(VCColors.onSurface)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── Disclaimer ───────────────────────────────────────────
                    Text("Always consult your healthcare provider about food-drug interactions.")
                        .font(.system(size: 11))
                        .foregroundColor(VCColors.outline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VCSpacing.xl)

                    // ── Action buttons ───────────────────────────────────────
                    actionButtons
                        .padding(.bottom, VCSpacing.xxxl)
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, VCSpacing.xxxl)
            }
        }
    }

    // MARK: Sub-views

    private var headerSection: some View {
        VStack(spacing: VCSpacing.md) {
            Image(systemName: severityIcon)
                .font(.system(size: 48))
                .foregroundColor(severityColor)
                .shadow(color: severityColor.opacity(0.3), radius: 12)

            Text("Medication Interaction")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(VCColors.onSurface)
                .multilineTextAlignment(.center)

            Text(severityLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(severityColor)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(severityColor.opacity(0.15))
                )
        }
    }

    private var actionButtons: some View {
        VStack(spacing: VCSpacing.md) {
            // Primary: Discard (gradient fill)
            Button(action: onDiscard) {
                Text("Discard This Food")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .accessibilityHint(Text("Removes this food from your log"))

            // Secondary: Log Anyway (outlined)
            Button(action: onAcknowledge) {
                Text("Log Anyway")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(VCColors.outlineVariant, lineWidth: 1.5)
                    )
            }
            .accessibilityHint(Text("Acknowledges the interaction warning and logs the meal anyway"))
        }
        .padding(.horizontal, VCSpacing.xxl)
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundColor(VCColors.outline)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Severe Interaction") {
    MedicationInteractionView(
        interaction: MedicationInteraction(
            medication: "Warfarin",
            medicationClass: .warfarin,
            food: "Kale",
            severity: .severe,
            description: "Vitamin K-rich foods significantly reduce the effectiveness of Warfarin, increasing clot risk.",
            recommendation: "Avoid large amounts of leafy greens. Maintain consistent intake if already consuming them regularly."
        ),
        onAcknowledge: {},
        onDiscard: {}
    )
}

#Preview("Caution") {
    MedicationInteractionView(
        interaction: MedicationInteraction(
            medication: "Metformin",
            medicationClass: .metformin,
            food: "Alcohol (Beer)",
            severity: .caution,
            description: "Alcohol can enhance the glucose-lowering effect of Metformin, potentially causing hypoglycemia.",
            recommendation: "Limit alcohol intake. Monitor blood glucose levels if consuming alcohol."
        ),
        onAcknowledge: {},
        onDiscard: {}
    )
}
#endif
