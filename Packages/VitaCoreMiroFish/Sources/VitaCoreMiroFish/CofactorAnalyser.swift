// CofactorAnalyser.swift
// VitaCoreMiroFish — C19 Analytics Core: Multi-cofactor RCA engine.
//
// The core analytical engine of VitaCore. Given an anomalous reading
// (e.g., glucose spike to 210 mg/dL), this engine searches the
// preceding time window for contributing factors across ALL available
// metrics and produces a ranked list of likely causes.
//
// Four correlation detectors:
//   1. PostMealSpike — meal within 2h before glucose elevation
//   2. SleepGlucose — poor sleep correlates with higher fasting glucose
//   3. ExerciseGlucose — activity level affects glucose trend
//   4. MultiCofactor RCA — 4h backward search for any contributing factor

import Foundation
import VitaCoreContracts

// MARK: - CofactorType

/// The type of contributing factor detected in an RCA analysis.
public enum CofactorType: String, Sendable, Hashable, CaseIterable, Codable {
    case recentMeal          // Meal within 2h before anomaly
    case highCarbMeal        // Carbs > 60g in the preceding meal
    case missedMedication    // No medication event in expected window
    case poorSleep           // Sleep < 6h or quality below threshold
    case lowActivity         // Steps < 3000 in preceding 8h
    case highActivity        // Steps > 12000 (exercise-induced hypo risk)
    case dehydration         // Fluid < 1000mL in 8h
    case stressIndicator     // Elevated resting HR without activity
    case dawnPhenomenon      // Glucose rise between 04:00-08:00
    case postExerciseDrop    // Glucose drop 1-3h after intense activity
    case unknown             // No clear cofactor identified
}

// MARK: - Cofactor

/// A single detected contributing factor with confidence and evidence.
public struct Cofactor: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let type: CofactorType
    /// How strongly this cofactor contributed (0.0 = unlikely, 1.0 = very likely).
    public let confidence: Float
    /// Human-readable explanation of the evidence.
    public let explanation: String
    /// The reading or episode that serves as evidence.
    public let evidenceTimestamp: Date
    /// The metric value that constitutes evidence (e.g., carbs=85g).
    public let evidenceValue: Double?

    public init(
        type: CofactorType, confidence: Float, explanation: String,
        evidenceTimestamp: Date, evidenceValue: Double? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.confidence = confidence
        self.explanation = explanation
        self.evidenceTimestamp = evidenceTimestamp
        self.evidenceValue = evidenceValue
    }
}

// MARK: - AnalysisResult

/// The output of a multi-cofactor RCA analysis.
public struct AnalysisResult: Sendable, Hashable, Codable {
    /// The anomalous reading that triggered the analysis.
    public let triggerMetric: MetricType
    public let triggerValue: Double
    public let triggerTimestamp: Date
    /// Ranked list of contributing factors (highest confidence first).
    public let cofactors: [Cofactor]
    /// Summary suitable for display in the UI or as MiroFish context.
    public let summary: String
    public let analysedAt: Date

    public init(
        triggerMetric: MetricType, triggerValue: Double, triggerTimestamp: Date,
        cofactors: [Cofactor], summary: String
    ) {
        self.triggerMetric = triggerMetric
        self.triggerValue = triggerValue
        self.triggerTimestamp = triggerTimestamp
        self.cofactors = cofactors.sorted { $0.confidence > $1.confidence }
        self.summary = summary
        self.analysedAt = Date()
    }
}

// MARK: - CofactorAnalyser

public struct CofactorAnalyser: Sendable {

    public init() {}

    /// Performs multi-cofactor root cause analysis on an anomalous reading.
    /// Searches the `lookbackHours` window before the trigger for
    /// contributing factors across all available metrics.
    public func analyse(
        trigger: Reading,
        graphStore: GraphStoreProtocol,
        lookbackHours: Double = 4
    ) async throws -> AnalysisResult {

        let windowStart = trigger.timestamp.addingTimeInterval(-lookbackHours * 3600)
        let windowEnd = trigger.timestamp

        // Pull all relevant readings from the lookback window.
        async let glucoseTask = graphStore.getRangeReadings(for: .glucose, from: windowStart, to: windowEnd)
        async let carbsTask = graphStore.getRangeReadings(for: .carbs, from: windowStart, to: windowEnd)
        async let caloriesTask = graphStore.getRangeReadings(for: .calories, from: windowStart, to: windowEnd)
        async let stepsTask = graphStore.getRangeReadings(for: .steps, from: windowStart.addingTimeInterval(-4 * 3600), to: windowEnd)
        async let sleepTask = graphStore.getRangeReadings(for: .sleep, from: windowStart.addingTimeInterval(-12 * 3600), to: windowEnd)
        async let fluidTask = graphStore.getRangeReadings(for: .fluidIntake, from: windowStart.addingTimeInterval(-8 * 3600), to: windowEnd)
        async let hrTask = graphStore.getRangeReadings(for: .heartRate, from: windowStart, to: windowEnd)

        let (glucose, carbs, calories, steps, sleep, fluid, hr) =
            try await (glucoseTask, carbsTask, caloriesTask, stepsTask, sleepTask, fluidTask, hrTask)

        var cofactors: [Cofactor] = []

        // --- 1. Post-meal spike detection ---
        if trigger.metricType == .glucose && trigger.value > 160 {
            let recentMeals = calories.filter {
                trigger.timestamp.timeIntervalSince($0.timestamp) > 0 &&
                trigger.timestamp.timeIntervalSince($0.timestamp) < 7200 // 2h
            }
            if !recentMeals.isEmpty {
                let mealCals = recentMeals.map(\.value).reduce(0, +)
                let recentCarbs = carbs.filter {
                    trigger.timestamp.timeIntervalSince($0.timestamp) > 0 &&
                    trigger.timestamp.timeIntervalSince($0.timestamp) < 7200
                }
                let totalCarbs = recentCarbs.map(\.value).reduce(0, +)

                if totalCarbs > 60 {
                    cofactors.append(Cofactor(
                        type: .highCarbMeal,
                        confidence: min(Float(totalCarbs) / 100.0, 0.95),
                        explanation: "High-carb meal (\(Int(totalCarbs))g carbs, \(Int(mealCals)) kcal) within 2 hours before this glucose reading.",
                        evidenceTimestamp: recentMeals.last?.timestamp ?? trigger.timestamp,
                        evidenceValue: totalCarbs
                    ))
                } else {
                    cofactors.append(Cofactor(
                        type: .recentMeal,
                        confidence: 0.6,
                        explanation: "Meal (\(Int(mealCals)) kcal) within 2 hours. Normal post-meal rise.",
                        evidenceTimestamp: recentMeals.last?.timestamp ?? trigger.timestamp,
                        evidenceValue: mealCals
                    ))
                }
            }
        }

        // --- 2. Sleep-glucose correlation ---
        let recentSleep = sleep.last
        if let sleepReading = recentSleep, sleepReading.value < 6.0 {
            let confidence: Float = sleepReading.value < 5.0 ? 0.8 : 0.6
            cofactors.append(Cofactor(
                type: .poorSleep,
                confidence: confidence,
                explanation: "Only \(String(format: "%.1f", sleepReading.value))h sleep. Poor sleep increases insulin resistance and elevates fasting glucose.",
                evidenceTimestamp: sleepReading.timestamp,
                evidenceValue: sleepReading.value
            ))
        }

        // --- 3. Exercise-glucose correlation ---
        let totalSteps = steps.map(\.value).reduce(0, +)
        if trigger.metricType == .glucose {
            if trigger.value > 160 && totalSteps < 3000 {
                cofactors.append(Cofactor(
                    type: .lowActivity,
                    confidence: 0.5,
                    explanation: "Low activity (\(Int(totalSteps)) steps in 8h). Walking improves glucose uptake.",
                    evidenceTimestamp: steps.last?.timestamp ?? trigger.timestamp,
                    evidenceValue: totalSteps
                ))
            } else if trigger.value < 80 && totalSteps > 10000 {
                cofactors.append(Cofactor(
                    type: .postExerciseDrop,
                    confidence: 0.7,
                    explanation: "High activity (\(Int(totalSteps)) steps) may have caused post-exercise glucose drop.",
                    evidenceTimestamp: steps.last?.timestamp ?? trigger.timestamp,
                    evidenceValue: totalSteps
                ))
            }
        }

        // --- 4. Dehydration check ---
        let totalFluid = fluid.map(\.value).reduce(0, +)
        if totalFluid < 1000 && trigger.metricType == .glucose && trigger.value > 160 {
            cofactors.append(Cofactor(
                type: .dehydration,
                confidence: 0.4,
                explanation: "Low fluid intake (\(Int(totalFluid)) mL in 8h). Dehydration concentrates blood glucose.",
                evidenceTimestamp: fluid.last?.timestamp ?? trigger.timestamp,
                evidenceValue: totalFluid
            ))
        }

        // --- 5. Dawn phenomenon ---
        let cal = Calendar(identifier: .gregorian)
        let hour = cal.component(.hour, from: trigger.timestamp)
        if trigger.metricType == .glucose && trigger.value > 140 && (hour >= 4 && hour <= 8) {
            // Check if glucose was lower before 04:00
            let overnightGlucose = glucose.filter {
                cal.component(.hour, from: $0.timestamp) < 4
            }
            if let overnight = overnightGlucose.last, overnight.value < trigger.value - 20 {
                cofactors.append(Cofactor(
                    type: .dawnPhenomenon,
                    confidence: 0.75,
                    explanation: "Glucose rose from \(Int(overnight.value)) to \(Int(trigger.value)) between 4-8 AM. Dawn phenomenon: liver releases glucose before waking.",
                    evidenceTimestamp: overnight.timestamp,
                    evidenceValue: trigger.value - overnight.value
                ))
            }
        }

        // --- 6. Stress indicator (elevated resting HR) ---
        let restingHR = hr.filter { $0.value > 90 }
        if !restingHR.isEmpty && trigger.metricType == .glucose && trigger.value > 160 {
            let avgElevatedHR = restingHR.map(\.value).reduce(0, +) / Double(restingHR.count)
            cofactors.append(Cofactor(
                type: .stressIndicator,
                confidence: 0.45,
                explanation: "Elevated resting HR (\(Int(avgElevatedHR)) bpm avg) suggests stress, which raises cortisol and glucose.",
                evidenceTimestamp: restingHR.last?.timestamp ?? trigger.timestamp,
                evidenceValue: avgElevatedHR
            ))
        }

        // --- Build summary ---
        let summary: String
        if cofactors.isEmpty {
            cofactors.append(Cofactor(
                type: .unknown,
                confidence: 0.2,
                explanation: "No clear contributing factor identified in the \(Int(lookbackHours))h window.",
                evidenceTimestamp: trigger.timestamp
            ))
            summary = "\(trigger.metricType.displayName) at \(Int(trigger.value)) \(trigger.unit) — no clear cause identified in the preceding \(Int(lookbackHours)) hours."
        } else {
            let topCofactor = cofactors.sorted { $0.confidence > $1.confidence }.first!
            summary = "\(trigger.metricType.displayName) at \(Int(trigger.value)) \(trigger.unit) — most likely cause: \(topCofactor.type.rawValue) (\(Int(topCofactor.confidence * 100))% confidence). \(topCofactor.explanation)"
        }

        return AnalysisResult(
            triggerMetric: trigger.metricType,
            triggerValue: trigger.value,
            triggerTimestamp: trigger.timestamp,
            cofactors: cofactors,
            summary: summary
        )
    }
}
