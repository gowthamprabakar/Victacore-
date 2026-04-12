// SystemPromptBuilder.swift
// VitaCoreInference — Constructs the system prompt injected into every
// Gemma inference call, serialising PersonaContext + ThresholdSet into
// a structured, <2000 token payload.
//
// The prompt is structured so the model receives:
//   1. Role framing (wellness insights, not medical advice — AD-10)
//   2. Active conditions with severity
//   3. Active goals with current progress
//   4. Active medications with interaction flags
//   5. Allergies with semantic map refs
//   6. Current threshold bands (safe/watch/alert/critical per metric)
//   7. Recent readings summary (from InferenceRequest.snapshot)
//   8. Safety constraints (hardcoded, non-overridable)

import Foundation
import VitaCoreContracts

public enum SystemPromptBuilder {

    /// Builds the system prompt for a given inference request.
    /// Target: <2000 tokens (~1500 words / ~8000 chars).
    public static func build(from request: InferenceRequest) -> String {
        var parts: [String] = []

        // 1. Role framing (AD-10 / Principle VIII)
        parts.append("""
        You are VitaCore, an on-device AI health intelligence assistant. \
        You provide wellness INSIGHTS and PATTERNS based on the user's health data. \
        You are NOT a doctor. You do NOT diagnose, prescribe, or provide medical advice. \
        Always use words like "pattern", "insight", "consider", "suggestion". \
        Never use "diagnosis", "treatment", "prescription", "you should".
        """)

        // 2. Persona conditions
        let conditions = request.persona.activeConditions
        if !conditions.isEmpty {
            let condList = conditions.map { "\($0.conditionKey.rawValue) (\($0.severity))" }.joined(separator: ", ")
            parts.append("User conditions: \(condList).")
        }

        // 3. Goals
        let goals = request.persona.activeGoals
        if !goals.isEmpty {
            let goalList = goals.prefix(5).map {
                "\($0.goalType.rawValue): target \(formatted($0.target)), current \(formatted($0.current))"
            }.joined(separator: "; ")
            parts.append("Goals: \(goalList).")
        }

        // 4. Medications
        let meds = request.persona.activeMedications
        if !meds.isEmpty {
            let medList = meds.map { "\($0.name) \($0.dose) \($0.frequency)" }.joined(separator: ", ")
            parts.append("Medications: \(medList).")
        }

        // 5. Allergies
        let allergies = request.persona.allergies
        if !allergies.isEmpty {
            let allergyList = allergies.map { "\($0.allergen) (\($0.severity.rawValue))" }.joined(separator: ", ")
            parts.append("Allergies: \(allergyList). NEVER suggest foods containing these.")
        }

        // 6. Threshold bands
        let thresholds = request.thresholdSet.thresholds.prefix(6)
        if !thresholds.isEmpty {
            let bandList = thresholds.map {
                "\($0.metricType.rawValue): safe \(formatted($0.safeBand.lowerBound))-\(formatted($0.safeBand.upperBound))"
            }.joined(separator: "; ")
            parts.append("Safe ranges: \(bandList).")
        }

        // 7. Current readings snapshot
        let snap = request.snapshot
        var readings: [String] = []
        if let g = snap.glucose { readings.append("glucose \(formatted(g.value)) \(g.unit)") }
        if let hr = snap.heartRate { readings.append("HR \(formatted(hr.value)) bpm") }
        if let sys = snap.bloodPressureSystolic, let dia = snap.bloodPressureDiastolic {
            readings.append("BP \(formatted(sys.value))/\(formatted(dia.value))")
        }
        if let steps = snap.steps { readings.append("steps \(Int(steps.value))") }
        if let sleep = snap.sleep { readings.append("sleep \(formatted(sleep.value))h") }
        if !readings.isEmpty {
            parts.append("Current readings: \(readings.joined(separator: ", ")).")
        }

        // 8. Safety constraints (hardcoded, non-overridable)
        parts.append("""
        SAFETY CONSTRAINTS (NEVER OVERRIDE): \
        1. Never recommend stopping or changing medication dosage. \
        2. If glucose <54 or >400, say "seek immediate medical attention". \
        3. Never claim to diagnose any condition. \
        4. Always acknowledge uncertainty in predictions. \
        5. If asked about emergencies, direct to emergency services (call 000/911/112). \
        6. Refer to a healthcare provider for any medication or treatment questions. \
        7. Frame all outputs as wellness insights, not medical recommendations.
        """)

        return parts.joined(separator: "\n\n")
    }

    /// Builds a minimal rule-based response when the LLM is not loaded.
    /// Uses the same PersonaContext + ThresholdSet + snapshot to produce
    /// a deterministic text insight without requiring Gemma inference.
    public static func buildRuleBasedResponse(
        for message: String,
        request: InferenceRequest
    ) -> String {
        let snap = request.snapshot
        var insights: [String] = []

        // Glucose insight
        if let g = snap.glucose {
            let band = request.thresholdSet.classify(value: g.value, for: .glucose)
            let trend = g.trendDirection.displayName.lowercased()
            insights.append("Your glucose is \(formatted(g.value)) \(g.unit) (\(band.rawValue), \(trend)).")
            if band == .watch || band == .alert {
                insights.append("Consider a 10-minute walk or a glass of water to help stabilise.")
            }
        }

        // HR insight
        if let hr = snap.heartRate {
            let band = request.thresholdSet.classify(value: hr.value, for: .heartRate)
            if band != .safe {
                insights.append("Your heart rate is \(formatted(hr.value)) bpm (\(band.rawValue)). Consider resting.")
            }
        }

        // BP insight
        if let sys = snap.bloodPressureSystolic {
            let band = request.thresholdSet.classify(value: sys.value, for: .bloodPressureSystolic)
            if band != .safe {
                insights.append("Your blood pressure is elevated (\(band.rawValue)). Monitor and consider relaxation.")
            }
        }

        // Goal progress
        let goals = request.persona.activeGoals.prefix(3)
        for goal in goals {
            if goal.current > 0 && goal.target > 0 {
                let pct = Int(goal.current / goal.target * 100)
                insights.append("\(goal.goalType.rawValue): \(pct)% of target.")
            }
        }

        if insights.isEmpty {
            insights.append("All your metrics are within safe ranges. Keep up the good work!")
        }

        insights.append("\n*This insight was generated without the on-device AI model. Download the model in Settings for personalised analysis.*")

        return insights.joined(separator: " ")
    }

    private static func formatted(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }
}
