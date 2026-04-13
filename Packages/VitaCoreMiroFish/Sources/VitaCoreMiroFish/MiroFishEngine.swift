// MiroFishEngine.swift
// VitaCoreMiroFish — C18 MiroFish MVP.
//
// Sprint 3.B. Single MetabolismAgent that combines:
//   1. CofactorAnalyser output (root causes)
//   2. PersonaContext (conditions, goals, meds, allergies)
//   3. ThresholdSet (current safe/watch/alert/critical bands)
//   4. InferenceProvider (Gemma streaming, when loaded)
//
// Produces a PrescriptionCard with ranked actionable interventions.
// When the LLM is not loaded, uses a deterministic rule-based engine
// that maps cofactors → prescriptions directly.

import Foundation
import VitaCoreContracts

// MARK: - MiroFishEngine

public final class MiroFishEngine: @unchecked Sendable {

    private let analyser: CofactorAnalyser

    public init(analyser: CofactorAnalyser = CofactorAnalyser()) {
        self.analyser = analyser
    }

    // -------------------------------------------------------------------------
    // MARK: Analyse + Prescribe (main entry point)
    // -------------------------------------------------------------------------

    /// End-to-end pipeline: detect anomaly → RCA → prescriptions.
    /// This is what HeartbeatEngine calls on a threshold crossing.
    public func analyseAndPrescribe(
        trigger: Reading,
        graphStore: GraphStoreProtocol,
        persona: PersonaContext,
        thresholdSet: ThresholdSet
    ) async throws -> (analysis: AnalysisResult, card: PrescriptionCard) {

        // 1. Run multi-cofactor RCA.
        let analysis = try await analyser.analyse(
            trigger: trigger,
            graphStore: graphStore,
            lookbackHours: 4
        )

        // 2. Generate prescriptions from cofactors + persona.
        let card = generatePrescriptionCard(
            analysis: analysis,
            persona: persona,
            thresholdSet: thresholdSet
        )

        return (analysis, card)
    }

    // -------------------------------------------------------------------------
    // MARK: Rule-Based Prescription Generator
    // -------------------------------------------------------------------------

    /// Deterministic prescription generation from cofactors. No LLM
    /// needed. When the LLM IS loaded, the InferenceProvider can refine
    /// these with natural language via the system prompt.
    public func generatePrescriptionCard(
        analysis: AnalysisResult,
        persona: PersonaContext,
        thresholdSet: ThresholdSet
    ) -> PrescriptionCard {

        var prescriptions: [Prescription] = []
        let allergens = Set(persona.allergies.map { $0.allergen.lowercased() })

        for (rank, cofactor) in analysis.cofactors.prefix(3).enumerated() {
            let rx = prescriptionFor(
                cofactor: cofactor,
                triggerMetric: analysis.triggerMetric,
                triggerValue: analysis.triggerValue,
                allergens: allergens,
                rank: rank + 1
            )
            prescriptions.append(rx)
        }

        // If no cofactors produced prescriptions, add a generic one.
        if prescriptions.isEmpty {
            prescriptions.append(Prescription(
                rank: 1,
                actionVerb: "Monitor",
                actionDetail: "Continue monitoring your \(analysis.triggerMetric.displayName). No specific action needed right now.",
                actionQuantity: 0,
                actionUnit: "",
                primaryBenefit: "Awareness of your health patterns",
                timeWindow: "ongoing",
                closingTime: nil,
                trajectoryScore: 0.5,
                baselineDelta: 0,
                contraindications: []
            ))
        }

        return PrescriptionCard(
            prescriptions: prescriptions,
            baselineOutcome: "No action: \(analysis.triggerMetric.displayName) likely remains at \(Int(analysis.triggerValue)) \(analysis.triggerMetric.unit)",
            overallConfidence: analysis.cofactors.first?.confidence ?? 0.3,
            dataCoverage: 1.0,
            sourceRequestId: UUID(),
            generatedAt: Date()
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Cofactor → Prescription mapping
    // -------------------------------------------------------------------------

    private func prescriptionFor(
        cofactor: Cofactor,
        triggerMetric: MetricType,
        triggerValue: Double,
        allergens: Set<String>,
        rank: Int
    ) -> Prescription {

        switch cofactor.type {

        case .highCarbMeal, .recentMeal:
            return Prescription(
                rank: rank,
                actionVerb: "Walk",
                actionDetail: "Take a brisk 10-15 minute walk to improve glucose uptake after your meal.",
                actionQuantity: 10,
                actionUnit: "minutes",
                primaryBenefit: "Post-meal walking lowers glucose by 15-25 mg/dL within 30 minutes",
                timeWindow: "within 30 minutes",
                closingTime: Date().addingTimeInterval(1800),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -20,
                contraindications: []
            )

        case .poorSleep:
            return Prescription(
                rank: rank,
                actionVerb: "Rest",
                actionDetail: "Prioritise sleep tonight. Aim for 7-8 hours. Avoid screens 1 hour before bed.",
                actionQuantity: 7.5,
                actionUnit: "hours",
                primaryBenefit: "Better sleep improves insulin sensitivity and lowers fasting glucose by 10-15 mg/dL",
                timeWindow: "tonight",
                closingTime: nil,
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -12,
                contraindications: []
            )

        case .lowActivity:
            return Prescription(
                rank: rank,
                actionVerb: "Move",
                actionDetail: "Take a short walk or do light stretching. Even 5 minutes helps.",
                actionQuantity: 5,
                actionUnit: "minutes",
                primaryBenefit: "Any movement improves glucose uptake and insulin sensitivity",
                timeWindow: "within 20 minutes",
                closingTime: Date().addingTimeInterval(1200),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -10,
                contraindications: []
            )

        case .postExerciseDrop:
            let snack = allergens.contains("peanut")
                ? "Have 15g of fast-acting carbs (juice, glucose tabs, or a banana)."
                : "Have 15g of fast-acting carbs (juice, glucose tabs, or a peanut butter cracker)."
            return Prescription(
                rank: rank,
                actionVerb: "Eat",
                actionDetail: snack,
                actionQuantity: 15,
                actionUnit: "grams carbs",
                primaryBenefit: "Raises glucose by 30-50 mg/dL within 15 minutes",
                timeWindow: "immediately",
                closingTime: Date().addingTimeInterval(900),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: 40,
                contraindications: allergens.contains("peanut") ? ["Peanut allergy — alternative snack suggested"] : []
            )

        case .dehydration:
            return Prescription(
                rank: rank,
                actionVerb: "Drink",
                actionDetail: "Drink 250-500 mL of water. Dehydration concentrates blood glucose.",
                actionQuantity: 350,
                actionUnit: "mL",
                primaryBenefit: "Rehydration can lower glucose by 5-10 mg/dL and supports kidney function",
                timeWindow: "within 15 minutes",
                closingTime: Date().addingTimeInterval(900),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -8,
                contraindications: []
            )

        case .dawnPhenomenon:
            return Prescription(
                rank: rank,
                actionVerb: "Note",
                actionDetail: "This is a dawn phenomenon pattern — your liver releases glucose before waking. This is common and usually resolves within 1-2 hours.",
                actionQuantity: 0,
                actionUnit: "",
                primaryBenefit: "Understanding reduces anxiety. If persistent, discuss with your healthcare provider.",
                timeWindow: "informational",
                closingTime: nil,
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: 0,
                contraindications: []
            )

        case .stressIndicator:
            return Prescription(
                rank: rank,
                actionVerb: "Breathe",
                actionDetail: "Try 5 minutes of deep breathing or a short meditation. Stress raises cortisol which elevates glucose.",
                actionQuantity: 5,
                actionUnit: "minutes",
                primaryBenefit: "Relaxation techniques can lower cortisol and reduce stress-related glucose elevation by 10-20 mg/dL",
                timeWindow: "within 10 minutes",
                closingTime: Date().addingTimeInterval(600),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -15,
                contraindications: []
            )

        case .missedMedication:
            return Prescription(
                rank: rank,
                actionVerb: "Check",
                actionDetail: "Review whether you took your scheduled medication. If missed, follow your healthcare provider's guidance on late doses.",
                actionQuantity: 0,
                actionUnit: "",
                primaryBenefit: "Medication adherence is the strongest modifiable factor for glucose control",
                timeWindow: "now",
                closingTime: nil,
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: -30,
                contraindications: ["Never double-dose without medical guidance"]
            )

        case .highActivity:
            return Prescription(
                rank: rank,
                actionVerb: "Refuel",
                actionDetail: "After intense exercise, have a balanced snack with carbs and protein within 30 minutes.",
                actionQuantity: 20,
                actionUnit: "grams carbs",
                primaryBenefit: "Post-exercise nutrition prevents delayed hypoglycaemia and supports recovery",
                timeWindow: "within 30 minutes",
                closingTime: Date().addingTimeInterval(1800),
                trajectoryScore: Float(cofactor.confidence),
                baselineDelta: 25,
                contraindications: []
            )

        case .unknown:
            return Prescription(
                rank: rank,
                actionVerb: "Monitor",
                actionDetail: "Keep tracking your \(triggerMetric.displayName). If this pattern repeats, VitaCore will build a response profile to identify the cause.",
                actionQuantity: 0,
                actionUnit: "",
                primaryBenefit: "Pattern recognition improves with more data",
                timeWindow: "ongoing",
                closingTime: nil,
                trajectoryScore: 0.3,
                baselineDelta: 0,
                contraindications: []
            )
        }
    }
}
