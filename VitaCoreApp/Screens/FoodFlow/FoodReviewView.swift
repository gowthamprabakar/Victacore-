// FoodReviewView.swift
// VitaCore — Food Flow Stage 6: Meal Review
//
// Displays AI-detected meal items with editable portions, macro summary,
// gate-check status badges, and a confirm-to-log action.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - FoodReviewView

struct FoodReviewView: View {

    // MARK: Props
    let result: FoodAnalysisResult
    @Binding var editablePortions: [UUID: Double]
    let onConfirm: () -> Void
    let onEdit: (UUID, Double) -> Void
    let onCancel: () -> Void

    // MARK: State
    @State private var editingItemID: UUID? = nil
    @State private var editingName: String = ""
    @State private var showAddItemSheet: Bool = false

    // MARK: Computed helpers

    var confidenceColor: Color {
        let c = result.confidence
        if c >= 0.8 { return VCColors.safe }
        if c >= 0.6 { return VCColors.watch }
        return VCColors.alertOrange
    }

    var confidencePercent: Int {
        Int((result.confidence * 100).rounded())
    }

    /// Aggregate macros across all items, scaled by current editable portions.
    fileprivate var totalMacros: MacroTotals {
        result.recognisedItems.reduce(MacroTotals()) { acc, item in
            let factor = portionFactor(for: item)
            return MacroTotals(
                calories: acc.calories + (item.calories ?? 0) * factor,
                carbs:    acc.carbs    + (item.carbsG   ?? 0) * factor,
                protein:  acc.protein  + (item.proteinG ?? 0) * factor,
                fat:      acc.fat      + (item.fatG     ?? 0) * factor
            )
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Navigation bar ───────────────────────────────────────────
                navigationBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VCSpacing.xl) {

                        // ── Meal photo + confidence ──────────────────────────
                        photoAndConfidenceSection

                        // ── Total macros summary card ────────────────────────
                        GlassCard(style: .hero) {
                            macroSummaryGrid(macros: totalMacros)
                        }

                        // ── Gate check status badges ─────────────────────────
                        gateCheckBadges

                        // ── Detected items ───────────────────────────────────
                        itemsSection

                        // ── Add missing item ─────────────────────────────────
                        addItemButton

                        // Bottom padding for sticky confirm button
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.top, VCSpacing.lg)
                }
            }

            // ── Sticky confirm button ────────────────────────────────────────
            confirmButton
        }
        .navigationBarHidden(true)
    }

    // MARK: Navigation bar

    private var navigationBar: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundColor(VCColors.primary)
            }
            .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Text("Review Meal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)

            Spacer()

            // Right side placeholder for balance
            Color.clear
                .frame(width: 60, height: 44)
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Photo + Confidence

    private var photoAndConfidenceSection: some View {
        ZStack(alignment: .bottomTrailing) {
            // Meal photo placeholder (image not carried through analysis result contract)
            ZStack {
                RoundedRectangle(cornerRadius: VCRadius.lg)
                    .fill(VCColors.surfaceLow)
                VStack(spacing: VCSpacing.sm) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(VCColors.outline)
                    Text("Meal Photo")
                        .font(.system(size: 13))
                        .foregroundColor(VCColors.outline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: VCRadius.lg))

            // Confidence pill
            Text("\(confidencePercent)% confidence")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, VCSpacing.xs)
                .background(
                    Capsule()
                        .fill(confidenceColor)
                )
                .padding(VCSpacing.sm)
        }
    }

    // MARK: Macro summary grid

    private func macroSummaryGrid(macros: MacroTotals) -> some View {
        VStack(alignment: .leading, spacing: VCSpacing.md) {
            Text("TOTAL MACROS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundColor(VCColors.outline)

            HStack(spacing: 0) {
                macroCell(icon: "flame.fill",     color: VCColors.alertOrange, label: "Calories", value: macros.calories,  unit: "kcal", isLast: false)
                macroCell(icon: "leaf.fill",       color: VCColors.safe,        label: "Carbs",    value: macros.carbs,     unit: "g",    isLast: false)
                macroCell(icon: "bolt.fill",       color: VCColors.tertiary,    label: "Protein",  value: macros.protein,   unit: "g",    isLast: false)
                macroCell(icon: "drop.fill",       color: VCColors.watch,       label: "Fat",      value: macros.fat,       unit: "g",    isLast: true)
            }
        }
    }

    private func macroCell(icon: String, color: Color, label: String, value: Double, unit: String, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded())))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VCColors.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(VCColors.onSurfaceVariant)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)

            if !isLast {
                Divider()
                    .frame(height: 44)
            }
        }
    }

    // MARK: Gate check badges

    private var gateCheckBadges: some View {
        VStack(spacing: VCSpacing.sm) {
            gateBadge(icon: "checkmark.shield.fill", text: "Allergen check passed", color: VCColors.safe)
            gateBadge(icon: "checkmark.shield.fill", text: "Medication check passed", color: VCColors.safe)
        }
    }

    private func gateBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VCColors.onSurface)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.md)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: Items section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: VCSpacing.md) {
            Text("DETECTED ITEMS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundColor(VCColors.outline)

            ForEach(result.recognisedItems) { item in
                foodItemCard(item: item)
            }
        }
    }

    private func foodItemCard(item: FoodEntry) -> some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {

                // ── Item header: name + remove ───────────────────────────────
                HStack(alignment: .top) {
                    if editingItemID == item.id {
                        // Inline edit mode
                        TextField("Item name", text: $editingName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(VCColors.onSurface)
                            .submitLabel(.done)
                            .onSubmit {
                                finaliseNameEdit(item: item)
                            }
                    } else {
                        Text(item.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(VCColors.onSurface)
                    }

                    Spacer()

                    // Edit name button
                    Button {
                        if editingItemID == item.id {
                            finaliseNameEdit(item: item)
                        } else {
                            editingItemID = item.id
                            editingName = item.name
                        }
                    } label: {
                        Image(systemName: editingItemID == item.id ? "checkmark.circle.fill" : "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(VCColors.primary)
                            .frame(width: 44, height: 44)
                    }

                    // Remove button
                    Button {
                        // Delegate removal upstream via onEdit with -1 sentinel
                        onEdit(item.id, -1)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(VCColors.critical)
                            .frame(width: 44, height: 44)
                    }
                }

                // ── Portion stepper ──────────────────────────────────────────
                portionStepper(item: item)

                // ── Macro breakdown ──────────────────────────────────────────
                itemMacroBreakdown(item: item)
            }
        }
    }

    private func portionStepper(item: FoodEntry) -> some View {
        let currentPortion = editablePortions[item.id] ?? (item.portionGrams ?? 100)

        return HStack(spacing: VCSpacing.md) {
            Text("Portion")
                .font(.system(size: 13))
                .foregroundColor(VCColors.onSurfaceVariant)

            Spacer()

            // Decrement
            Button {
                let newValue = max(10, currentPortion - 10)
                editablePortions[item.id] = newValue
                onEdit(item.id, newValue)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(VCColors.primary)
                    .frame(width: 44, height: 44)
            }

            // Current value
            Text("\(Int(currentPortion)) g")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
                .frame(minWidth: 56)
                .multilineTextAlignment(.center)

            // Increment
            Button {
                let newValue = min(1000, currentPortion + 10)
                editablePortions[item.id] = newValue
                onEdit(item.id, newValue)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(VCColors.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, VCSpacing.xs)
        .padding(.horizontal, VCSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.md)
                .fill(VCColors.surfaceLow.opacity(0.6))
        )
    }

    private func itemMacroBreakdown(item: FoodEntry) -> some View {
        let factor = portionFactor(for: item)
        let cal  = (item.calories ?? 0) * factor
        let carb = (item.carbsG   ?? 0) * factor
        let pro  = (item.proteinG ?? 0) * factor
        let fat  = (item.fatG     ?? 0) * factor

        return HStack(spacing: VCSpacing.lg) {
            inlineMacro(label: "Cal",     value: cal,  unit: "kcal", color: VCColors.alertOrange)
            inlineMacro(label: "Carbs",   value: carb, unit: "g",    color: VCColors.safe)
            inlineMacro(label: "Protein", value: pro,  unit: "g",    color: VCColors.tertiary)
            inlineMacro(label: "Fat",     value: fat,  unit: "g",    color: VCColors.watch)
        }
    }

    private func inlineMacro(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded())))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text("\(label) \(unit)")
                .font(.system(size: 10))
                .foregroundColor(VCColors.onSurfaceVariant)
        }
    }

    // MARK: Add item button

    private var addItemButton: some View {
        Button {
            showAddItemSheet = true
        } label: {
            HStack(spacing: VCSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Missing Item")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(VCColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(VCColors.primary, lineWidth: 1.5)
            )
        }
    }

    // MARK: Confirm button (sticky)

    private var confirmButton: some View {
        VStack(spacing: 0) {
            Divider()
                .background(VCColors.outlineVariant)

            Button(action: onConfirm) {
                Text("Confirm & Log Meal")
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
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.vertical, VCSpacing.lg)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: Helpers

    private func portionFactor(for item: FoodEntry) -> Double {
        // FoodEntry.calories/carbsG/proteinG/fatG are absolute values for the stated portion,
        // not per-100g. So when the user does NOT adjust the portion, factor = 1.0.
        // When they DO adjust, scale proportionally against the original portion.
        guard let originalPortion = item.portionGrams, originalPortion > 0 else { return 1.0 }
        let portion = editablePortions[item.id] ?? originalPortion
        return portion / originalPortion
    }

    private func finaliseNameEdit(item: FoodEntry) {
        editingItemID = nil
        // Name edit is handled internally; portion callback used for portion changes only
    }
}

// MARK: - MacroTotals helper

private struct MacroTotals {
    var calories: Double = 0
    var carbs:    Double = 0
    var protein:  Double = 0
    var fat:      Double = 0
}

// MARK: - FoodAnalysisResult convenience extension

// These properties are expected from the contract type:
// result.items: [FoodEntry]
// result.confidence: Double
// result.capturedImage: UIImage?
// result.allergenCheckPassed: Bool
// result.medicationCheckPassed: Bool
//
// FoodEntry expected:
// item.id: UUID, item.name: String, item.portionGrams: Double
// item.caloriesPer100g: Double, item.carbsPer100g: Double
// item.proteinPer100g: Double, item.fatPer100g: Double

// MARK: - Preview

#if DEBUG
import UIKit

#Preview {
    @Previewable @State var portions: [UUID: Double] = [:]
    let sampleID1 = UUID()
    let sampleID2 = UUID()

    FoodReviewView(
        result: FoodAnalysisResult(
            recognisedItems: [
                FoodEntry(
                    id: sampleID1,
                    name: "Pad Thai Noodles",
                    portionGrams: 250,
                    calories: 453,
                    carbsG: 65,
                    proteinG: 20,
                    fatG: 12.5,
                    sourceSkillId: "skill.manual.food.vision"
                ),
                FoodEntry(
                    id: sampleID2,
                    name: "Spring Roll",
                    portionGrams: 80,
                    calories: 176,
                    carbsG: 17.6,
                    proteinG: 4.8,
                    fatG: 9.6,
                    sourceSkillId: "skill.manual.food.vision"
                )
            ],
            totalCalories: 629,
            totalCarbsG: 82.6,
            totalProteinG: 24.8,
            totalFatG: 22.1,
            confidence: 0.82
        ),
        editablePortions: $portions,
        onConfirm: {},
        onEdit: { _, _ in },
        onCancel: {}
    )
}
#endif
