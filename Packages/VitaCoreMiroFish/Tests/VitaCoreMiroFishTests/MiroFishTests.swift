// MiroFishTests.swift
// VitaCoreMiroFish — Sprint 3.B tests.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
import VitaCorePersona
import VitaCoreThreshold
@testable import VitaCoreMiroFish

// MARK: - CofactorAnalyser Tests

@Test("Post-meal spike detected when glucose > 160 with recent meal")
func testPostMealSpikeDetection() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    // Write a meal 90 minutes ago.
    try await graph.writeReadings([
        Reading(metricType: .calories, value: 650, unit: "kcal",
                timestamp: now.addingTimeInterval(-5400), sourceSkillId: "skill.manual.food", confidence: 0.9),
        Reading(metricType: .carbs, value: 85, unit: "g",
                timestamp: now.addingTimeInterval(-5400), sourceSkillId: "skill.manual.food", confidence: 0.9)
    ])

    // Glucose spike now.
    let trigger = Reading(metricType: .glucose, value: 215, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)
    try await graph.writeReading(trigger)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    let mealCofactors = result.cofactors.filter { $0.type == .highCarbMeal || $0.type == .recentMeal }
    #expect(!mealCofactors.isEmpty, "Should detect recent high-carb meal as cofactor")
    #expect(mealCofactors.first!.confidence >= 0.6)
    #expect(result.summary.contains("most likely cause"))
}

@Test("Poor sleep detected when sleep < 6h")
func testPoorSleepDetection() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    // Write poor sleep from last night.
    try await graph.writeReading(Reading(
        metricType: .sleep, value: 4.5, unit: "hr",
        timestamp: now.addingTimeInterval(-3600 * 6), sourceSkillId: "skill.healthKitSleep", confidence: 0.9
    ))

    let trigger = Reading(metricType: .glucose, value: 165, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    let sleepCofactors = result.cofactors.filter { $0.type == .poorSleep }
    #expect(!sleepCofactors.isEmpty, "Should detect poor sleep as cofactor")
    #expect(sleepCofactors.first!.confidence >= 0.6)
}

@Test("Low activity detected when steps < 3000 and glucose elevated")
func testLowActivityDetection() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    try await graph.writeReading(Reading(
        metricType: .steps, value: 1500, unit: "steps",
        timestamp: now.addingTimeInterval(-3600 * 4), sourceSkillId: "skill.healthKitSteps", confidence: 0.98
    ))

    let trigger = Reading(metricType: .glucose, value: 180, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    let activityCofactors = result.cofactors.filter { $0.type == .lowActivity }
    #expect(!activityCofactors.isEmpty, "Should detect low activity as cofactor")
}

@Test("Dehydration detected when fluid < 1000mL and glucose elevated")
func testDehydrationDetection() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    try await graph.writeReading(Reading(
        metricType: .fluidIntake, value: 500, unit: "mL",
        timestamp: now.addingTimeInterval(-3600 * 5), sourceSkillId: "skill.manual.fluid", confidence: 1.0
    ))

    let trigger = Reading(metricType: .glucose, value: 190, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    let dehydrationCofactors = result.cofactors.filter { $0.type == .dehydration }
    #expect(!dehydrationCofactors.isEmpty, "Should detect dehydration as cofactor")
}

@Test("Multiple cofactors ranked by confidence")
func testMultiCofactorRanking() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    // High-carb meal + poor sleep + low activity = multi-cofactor
    try await graph.writeReadings([
        Reading(metricType: .carbs, value: 90, unit: "g",
                timestamp: now.addingTimeInterval(-3600), sourceSkillId: "skill.manual.food", confidence: 0.9),
        Reading(metricType: .calories, value: 700, unit: "kcal",
                timestamp: now.addingTimeInterval(-3600), sourceSkillId: "skill.manual.food", confidence: 0.9),
        Reading(metricType: .sleep, value: 4.0, unit: "hr",
                timestamp: now.addingTimeInterval(-3600 * 8), sourceSkillId: "skill.healthKitSleep", confidence: 0.9),
        Reading(metricType: .steps, value: 800, unit: "steps",
                timestamp: now.addingTimeInterval(-3600 * 6), sourceSkillId: "skill.healthKitSteps", confidence: 0.98)
    ])

    let trigger = Reading(metricType: .glucose, value: 230, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    #expect(result.cofactors.count >= 3, "Should detect at least 3 cofactors")
    // Highest confidence first.
    for i in 0..<(result.cofactors.count - 1) {
        #expect(result.cofactors[i].confidence >= result.cofactors[i + 1].confidence)
    }
}

// MARK: - MiroFishEngine Tests

@Test("MiroFishEngine produces PrescriptionCard from T1D synthetic cohort")
func testMiroFishE2E() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump, days: 14,
        endingAt: Date().addingTimeInterval(-172800), seed: 42
    )
    try await cohort.write(to: graph)

    // Write an elevated glucose trigger after cohort.
    let trigger = Reading(metricType: .glucose, value: 220, unit: "mg/dL",
                          timestamp: Date(), sourceSkillId: "skill.cgmDexcom", confidence: 0.95)
    try await graph.writeReading(trigger)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let persona = try await personaEngine.getPersonaContext()
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)
    let thresholdSet = try await thresholdEngine.resolveActiveThresholdSet()

    let miroFish = MiroFishEngine()
    let (analysis, card) = try await miroFish.analyseAndPrescribe(
        trigger: trigger,
        graphStore: graph,
        persona: persona,
        thresholdSet: thresholdSet
    )

    #expect(analysis.triggerValue == 220)
    #expect(!analysis.cofactors.isEmpty)
    #expect(!card.prescriptions.isEmpty)
    #expect(card.prescriptions.first!.actionVerb.count > 0)
    #expect(card.overallConfidence > 0)
}

@Test("PrescriptionCard respects peanut allergy in post-exercise snack")
func testAllergyRespected() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    // High activity causing hypo risk.
    try await graph.writeReading(Reading(
        metricType: .steps, value: 15000, unit: "steps",
        timestamp: now.addingTimeInterval(-7200), sourceSkillId: "skill.healthKitSteps", confidence: 0.98
    ))

    let trigger = Reading(metricType: .glucose, value: 65, unit: "mg/dL",
                          timestamp: now, sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let persona = PersonaContext(
        userId: UUID(),
        activeConditions: [ConditionSummary(conditionKey: .type1Diabetes, severity: "moderate", daysActive: 365)],
        allergies: [AllergenSummary(allergen: "Peanut", severity: .severe, semanticMapRefs: ["groundnut"])]
    )

    let thresholdSet = ThresholdSet(thresholds: [
        MetricThreshold(metricType: .glucose, safeBand: 70...180, watchBand: 54...250,
                        alertBand: 40...300, criticalBand: 0...400, priority: 3)
    ])

    let miroFish = MiroFishEngine()
    let card = miroFish.generatePrescriptionCard(
        analysis: try await CofactorAnalyser().analyse(trigger: trigger, graphStore: graph),
        persona: persona,
        thresholdSet: thresholdSet
    )

    // Check that no prescription suggests peanut butter.
    for rx in card.prescriptions {
        #expect(!rx.actionDetail.lowercased().contains("peanut butter"),
                "Should not suggest peanut butter to a user with peanut allergy")
    }
}

@Test("Empty graph still finds cofactors from zero-valued signals")
func testEmptyGraphAnalysis() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let trigger = Reading(metricType: .glucose, value: 180, unit: "mg/dL",
                          timestamp: Date(), sourceSkillId: "skill.cgmDexcom", confidence: 0.95)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    // Even with empty graph, zero steps = lowActivity is detected.
    // The analyser correctly identifies absence of data as a signal.
    #expect(!result.cofactors.isEmpty)
    #expect(result.cofactors.first!.confidence > 0)
}
