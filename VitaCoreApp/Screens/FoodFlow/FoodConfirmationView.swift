// FoodConfirmationView.swift
// VitaCore — Food Flow Stage 7: Meal Logged Confirmation
//
// Spring-animated checkmark, macro summary, daily budget progress bars,
// and staggered card entrance animation.

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - FoodConfirmationView

struct FoodConfirmationView: View {

    // MARK: Props
    let result: FoodAnalysisResult
    let onDone: () -> Void

    // Provided externally or use default stub
    var onLogAnother: (() -> Void)? = nil

    // MARK: State
    @State private var checkmarkScale: CGFloat = 0
    @State private var cardsVisible: Bool = false

    // MARK: Meal time

    var mealTimeName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "Breakfast"
        case 11..<15: return "Lunch"
        case 15..<18: return "Snack"
        case 18..<22: return "Dinner"
        default:       return "Late Meal"
        }
    }

    // MARK: Computed macros — use totals from FoodAnalysisResult directly

    fileprivate var totalMacros: ConfirmationMacros {
        ConfirmationMacros(
            calories: result.totalCalories,
            carbs:    result.totalCarbsG,
            protein:  result.totalProteinG,
            fat:      result.totalFatG
        )
    }

    // MARK: Mock daily totals (pre-meal, before this log)
    // In production these would come from HealthKit / NutritionStore
    fileprivate static let dailyGoal = DailyGoal(calories: 2000, carbs: 250, protein: 100, fat: 65)
    fileprivate static let priorTotals = ConfirmationMacros(calories: 1200, carbs: 140, protein: 65, fat: 35)

    fileprivate var postMealTotals: ConfirmationMacros {
        ConfirmationMacros(
            calories: Self.priorTotals.calories + totalMacros.calories,
            carbs:    Self.priorTotals.carbs    + totalMacros.carbs,
            protein:  Self.priorTotals.protein  + totalMacros.protein,
            fat:      Self.priorTotals.fat      + totalMacros.fat
        )
    }

    fileprivate var dailyGoal: DailyGoal { Self.dailyGoal }
    fileprivate var priorTotals: ConfirmationMacros { Self.priorTotals }

    // MARK: Body

    var body: some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VCSpacing.xl) {

                    // ── Animated checkmark ────────────────────────────────────
                    checkmarkBadge
                        .padding(.top, VCSpacing.xxxl + VCSpacing.xl)

                    // ── Title + subtitle ──────────────────────────────────────
                    VStack(spacing: VCSpacing.sm) {
                        Text("Meal Logged!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(VCColors.onSurface)

                        Text("Added to your daily nutrition")
                            .font(.system(size: 15))
                            .foregroundColor(VCColors.onSurfaceVariant)
                    }
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 10)

                    // ── Meal summary card ─────────────────────────────────────
                    GlassCard(style: .standard) {
                        mealSummaryContent
                    }
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: cardsVisible)

                    // ── Daily totals card ─────────────────────────────────────
                    GlassCard(style: .enhanced) {
                        dailyTotalsContent
                    }
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: cardsVisible)

                    // ── Action buttons ────────────────────────────────────────
                    actionButtons
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.65), value: cardsVisible)
                        .padding(.bottom, VCSpacing.xxxl)
                }
                .padding(.horizontal, VCSpacing.xxl)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: cardsVisible)
            }
        }
        .onAppear {
            // Spring checkmark scale-in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
            }
            // Staggered card reveal
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                cardsVisible = true
            }
        }
    }

    // MARK: Checkmark badge

    private var checkmarkBadge: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VCColors.primary.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Filled circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VCColors.primary, VCColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: VCColors.primary.opacity(0.4), radius: 20, y: 8)

            // White checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(checkmarkScale)
    }

    // MARK: Meal summary

    private var mealSummaryContent: some View {
        VStack(alignment: .leading, spacing: VCSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mealTimeName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(VCColors.onSurface)

                    Text("\(result.recognisedItems.count) item\(result.recognisedItems.count == 1 ? "" : "s") detected")
                        .font(.system(size: 12))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: mealTimeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(VCColors.primary)
            }

            Divider()

            // 4-column macro grid
            HStack(spacing: 0) {
                confirmMacroCell(icon: "flame.fill",  color: VCColors.alertOrange, label: "Cal",     value: totalMacros.calories, unit: "kcal", isLast: false)
                confirmMacroCell(icon: "leaf.fill",   color: VCColors.safe,        label: "Carbs",   value: totalMacros.carbs,    unit: "g",    isLast: false)
                confirmMacroCell(icon: "bolt.fill",   color: VCColors.tertiary,    label: "Protein", value: totalMacros.protein,  unit: "g",    isLast: false)
                confirmMacroCell(icon: "drop.fill",   color: VCColors.watch,       label: "Fat",     value: totalMacros.fat,      unit: "g",    isLast: true)
            }
        }
    }

    // MARK: Daily totals

    private var dailyTotalsContent: some View {
        VStack(alignment: .leading, spacing: VCSpacing.lg) {
            HStack {
                Text("Daily Budget")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(VCColors.onSurface)
                Spacer()
                Text("Updated")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(VCColors.safe)
                    .padding(.horizontal, VCSpacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(VCColors.safe.opacity(0.12)))
            }

            budgetRow(
                icon: "flame.fill",
                color: VCColors.alertOrange,
                label: "Calories",
                current: postMealTotals.calories,
                goal: dailyGoal.calories,
                unit: "kcal"
            )
            budgetRow(
                icon: "leaf.fill",
                color: VCColors.safe,
                label: "Carbs",
                current: postMealTotals.carbs,
                goal: dailyGoal.carbs,
                unit: "g"
            )
            budgetRow(
                icon: "bolt.fill",
                color: VCColors.tertiary,
                label: "Protein",
                current: postMealTotals.protein,
                goal: dailyGoal.protein,
                unit: "g"
            )
            budgetRow(
                icon: "drop.fill",
                color: VCColors.watch,
                label: "Fat",
                current: postMealTotals.fat,
                goal: dailyGoal.fat,
                unit: "g"
            )
        }
    }

    private func budgetRow(icon: String, color: Color, label: String, current: Double, goal: Double, unit: String) -> some View {
        let progress = min(current / goal, 1.0)
        let isOver = current > goal

        return VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VCColors.onSurface)
                Spacer()
                Text("\(Int(current.rounded())) / \(Int(goal)) \(unit)")
                    .font(.system(size: 12))
                    .foregroundColor(isOver ? VCColors.critical : VCColors.onSurfaceVariant)
                    .fontWeight(isOver ? .semibold : .regular)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOver ? VCColors.critical : color)
                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: cardsVisible)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: Action buttons

    private var actionButtons: some View {
        VStack(spacing: VCSpacing.md) {
            Button(action: onDone) {
                Text("Done")
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

            Button {
                onLogAnother?()
            } label: {
                HStack(spacing: VCSpacing.xs) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15))
                    Text("Log Another")
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
    }

    // MARK: Helpers

    private var mealTimeIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "sunrise.fill"
        case 11..<15: return "sun.max.fill"
        case 15..<18: return "sun.haze.fill"
        case 18..<22: return "moon.stars.fill"
        default:       return "moon.zzz.fill"
        }
    }

    private func confirmMacroCell(icon: String, color: Color, label: String, value: Double, unit: String, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)

                Text(value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded())))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(VCColors.onSurface)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(VCColors.onSurfaceVariant)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VCColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)

            if !isLast {
                Divider()
                    .frame(height: 40)
            }
        }
    }
}

// MARK: - Supporting types

fileprivate struct ConfirmationMacros {
    var calories: Double = 0
    var carbs:    Double = 0
    var protein:  Double = 0
    var fat:      Double = 0
}

fileprivate struct DailyGoal {
    let calories: Double
    let carbs:    Double
    let protein:  Double
    let fat:      Double
}

// MARK: - Preview

#if DEBUG
#Preview {
    let sampleItems = [
        FoodEntry(
            name: "Grilled Chicken Breast",
            portionGrams: 180,
            calories: 297,
            carbsG: 0,
            proteinG: 55.8,
            fatG: 6.5,
            sourceSkillId: "skill.manual.food.vision"
        ),
        FoodEntry(
            name: "Brown Rice",
            portionGrams: 150,
            calories: 168,
            carbsG: 36,
            proteinG: 3.9,
            fatG: 1.35,
            sourceSkillId: "skill.manual.food.vision"
        ),
        FoodEntry(
            name: "Steamed Broccoli",
            portionGrams: 120,
            calories: 41,
            carbsG: 8.4,
            proteinG: 3.36,
            fatG: 0.48,
            sourceSkillId: "skill.manual.food.vision"
        )
    ]

    FoodConfirmationView(
        result: FoodAnalysisResult(
            recognisedItems: sampleItems,
            totalCalories: 506,
            totalCarbsG: 44.4,
            totalProteinG: 63.06,
            totalFatG: 8.33,
            confidence: 0.91
        ),
        onDone: {},
        onLogAnother: {}
    )
}
#endif
