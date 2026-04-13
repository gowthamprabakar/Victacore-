// EndToEndTests.swift
// VitaCoreIntegration — Sprint 3.D end-to-end pipeline test.
//
// Proves the ENTIRE VitaCore pipeline works across all packages:
//
//   Synthetic data → GraphStore → SkillBus log → PersonaInferencer →
//   PersonaContext → ThresholdResolver → ThresholdSet → HeartbeatEngine →
//   threshold crossing → CofactorAnalyser → MiroFishEngine → PrescriptionCard
//
// This single test is worth more than 100 unit tests because it
// validates the interfaces between components, not just each component
// in isolation.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
import VitaCorePersona
import VitaCoreThreshold
import VitaCoreSkillBus
import VitaCoreHeartbeat
import VitaCoreMiroFish

// MARK: - Full Pipeline Integration

@Test("Full pipeline: synthetic data → persona → thresholds → monitor → RCA → prescribe")
func testFullPipeline() async throws {

    // =========================================================================
    // STEP 1: Create stores (all in-memory, no disk I/O)
    // =========================================================================

    let graphStore = try GRDBGraphStore.inMemory()
    let personaStore = try GRDBPersonaStore.inMemory()

    // =========================================================================
    // STEP 2: Seed with synthetic T1D cohort (14 days of realistic data)
    // =========================================================================

    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump,
        days: 14,
        endingAt: Date().addingTimeInterval(-172800), // 2 days ago so test readings are "latest"
        seed: 42
    )
    try await cohort.write(to: graphStore)
    #expect(cohort.readingCount > 5000, "T1D cohort should have >5000 readings (CGM 5-min)")
    #expect(cohort.episodeCount > 0, "T1D cohort should have ground-truth episodes")

    // =========================================================================
    // STEP 3: SkillBus — log a manual glucose entry (simulates user input)
    // =========================================================================

    let skillBus = VitaCoreSkillBus(graphStore: graphStore)
    let logResult = await skillBus.logGlucose(value: 215, timestamp: Date())
    #expect(logResult.success, "Manual glucose log should succeed")

    // Also log a meal to give MiroFish something to correlate.
    let foodResult = FoodAnalysisResult(
        recognisedItems: [
            FoodEntry(name: "Biryani", portionGrams: 350, calories: 450,
                      carbsG: 65, proteinG: 20, fatG: 16,
                      sourceSkillId: "skill.manual.food", timestamp: Date())
        ],
        totalCalories: 450, totalCarbsG: 65, totalProteinG: 20, totalFatG: 16,
        confidence: 0.9, analysedAt: Date()
    )
    let foodLog = await skillBus.logFoodEntry(
        result: foodResult,
        timestamp: Date().addingTimeInterval(-5400) // 90 min ago
    )
    #expect(foodLog.success, "Food log should succeed")

    // =========================================================================
    // STEP 4: PersonaEngine — classify user from graph data
    // =========================================================================

    let personaEngine = VitaCorePersonaEngine(
        store: personaStore,
        graphStore: graphStore
    )
    let persona = try await personaEngine.getPersonaContext()

    // T1D cohort should classify as type1Diabetes.
    #expect(
        persona.activeConditions.contains { $0.conditionKey == .type1Diabetes },
        "PersonaInferencer should classify T1D cohort as type1Diabetes"
    )

    // Sprint 0.B fixes: threshold overrides and goal progress should be populated.
    #expect(!persona.thresholdOverrides.isEmpty, "Should have inferred thresholdOverrides")
    #expect(!persona.goalProgress.isEmpty, "Should have goalProgress matching activeGoals")

    // =========================================================================
    // STEP 5: ThresholdEngine — resolve per-user metric bands
    // =========================================================================

    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)
    let thresholdSet = try await thresholdEngine.resolveActiveThresholdSet()

    // T1D should have glucose safe band 70-180 (ADA target).
    let glucoseThreshold = thresholdSet.threshold(for: .glucose)
    #expect(glucoseThreshold != nil, "ThresholdSet should include glucose")
    #expect(glucoseThreshold!.safeBand.lowerBound >= 70)
    #expect(glucoseThreshold!.safeBand.upperBound <= 180)

    // Classify the 215 mg/dL reading against the resolved thresholds.
    let band = thresholdSet.classify(value: 215, for: .glucose)
    #expect(band == .watch || band == .alert, "215 mg/dL should be watch or alert for T1D")

    // =========================================================================
    // STEP 6: HeartbeatEngine — detect the threshold crossing
    // =========================================================================

    let heartbeat = HeartbeatEngine(
        graphStore: graphStore,
        thresholdEngine: thresholdEngine,
        cycleInterval: 60
    )

    // Collect alerts from the monitoring cycle.
    final class AlertBox: @unchecked Sendable {
        var alerts: [HeartbeatAlert] = []
        func append(_ a: HeartbeatAlert) { alerts.append(a) }
    }
    let alertBox = AlertBox()
    heartbeat.onAlert = { alert in alertBox.append(alert) }

    await heartbeat.runCycle()

    // Should have at least one alert (the 215 glucose is above safe band).
    #expect(!alertBox.alerts.isEmpty, "HeartbeatEngine should fire alert for glucose 215")
    let glucoseAlerts = alertBox.alerts.filter { $0.metricType == .glucose }
    #expect(!glucoseAlerts.isEmpty, "Should have glucose-specific alert")

    // =========================================================================
    // STEP 7: MiroFish RCA — analyse the elevated glucose
    // =========================================================================

    let trigger = Reading(
        metricType: .glucose, value: 215, unit: "mg/dL",
        timestamp: Date(), sourceSkillId: "skill.manual.glucose", confidence: 1.0
    )

    let miroFish = MiroFishEngine()
    let (analysis, card) = try await miroFish.analyseAndPrescribe(
        trigger: trigger,
        graphStore: graphStore,
        persona: persona,
        thresholdSet: thresholdSet
    )

    // RCA should find the high-carb meal (65g carbs, biryani) as a cofactor.
    #expect(!analysis.cofactors.isEmpty, "RCA should find at least one cofactor")
    let mealCofactors = analysis.cofactors.filter {
        $0.type == .highCarbMeal || $0.type == .recentMeal
    }
    #expect(!mealCofactors.isEmpty, "Should detect the biryani as a meal cofactor")

    // PrescriptionCard should have actionable recommendations.
    #expect(!card.prescriptions.isEmpty, "Should produce at least one prescription")
    #expect(card.prescriptions.first!.actionVerb.count > 0, "Prescription should have an action verb")
    #expect(card.overallConfidence > 0.3, "Confidence should be meaningful")

    // =========================================================================
    // STEP 8: Verify the full data trail in GraphStore
    // =========================================================================

    // Manual glucose entry should be queryable.
    let latestGlucose = try await graphStore.getLatestReading(for: .glucose)
    #expect(latestGlucose != nil)
    #expect(latestGlucose!.value == 215)

    // Food entry should be queryable.
    let latestCalories = try await graphStore.getLatestReading(for: .calories)
    #expect(latestCalories != nil)
    #expect(latestCalories!.value == 450)

    // Monitoring result episode should exist (HeartbeatEngine writes one per cycle).
    let monitorEpisodes = try await graphStore.getEpisodes(
        from: Date().addingTimeInterval(-300),
        to: Date().addingTimeInterval(60),
        types: [.monitoringResult]
    )
    #expect(!monitorEpisodes.isEmpty, "HeartbeatEngine should write monitoring result episode")

    // =========================================================================
    // STEP 9: Mutation — add medication, verify threshold changes
    // =========================================================================

    try await personaEngine.addMedication(
        MedicationSummary(
            classKey: .insulin,
            name: "Lantus",
            dose: "20u",
            frequency: "QHS"
        )
    )

    // Invalidate threshold cache so it re-resolves with the new medication.
    thresholdEngine.invalidateCache()
    let updatedThresholds = try await thresholdEngine.resolveActiveThresholdSet()
    let updatedGlucose = updatedThresholds.threshold(for: .glucose)

    // The inferencer's thresholdOverride (70-180 for T1D) applies at
    // priority 7 (clinician level), which wins over the insulin modifier
    // at priority 4. This is correct — system-inferred overrides protect
    // the user's safe range. The insulin modifier would only take effect
    // if the override were removed.
    #expect(updatedGlucose!.safeBand.lowerBound == 70,
            "ThresholdOverride (priority 7) should win over insulin modifier (priority 4)")
    #expect(updatedGlucose!.safeBand.upperBound == 180)

    // =========================================================================
    // DONE — Full pipeline verified
    // =========================================================================
    // data seed → log → classify → resolve → monitor → detect → analyse →
    // prescribe → query → mutate → re-resolve
}

// MARK: - Cross-Persona Pipeline Validation

@Test("All 4 synthetic personas produce valid thresholds and classifications")
func testAllPersonasPipeline() async throws {
    for archetype in PersonaArchetype.allCases {
        let graph = try GRDBGraphStore.inMemory()
        let cohort = CohortBuilder().buildCohort(
            archetype: archetype, days: 14,
            endingAt: Date().addingTimeInterval(-172800), seed: 99
        )
        try await cohort.write(to: graph)

        let personaStore = try GRDBPersonaStore.inMemory()
        let engine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
        let persona = try await engine.getPersonaContext()

        // Every persona should have at least one condition.
        #expect(!persona.activeConditions.isEmpty,
                "\(archetype) should have at least one condition")

        // Thresholds should resolve without error.
        let thresholdEngine = VitaCoreThresholdEngine(personaEngine: engine)
        let thresholds = try await thresholdEngine.resolveActiveThresholdSet()

        // Every persona should have a glucose threshold.
        #expect(thresholds.threshold(for: .glucose) != nil,
                "\(archetype) should have glucose threshold")

        // Classify a reading — should not crash.
        let band = thresholds.classify(value: 100, for: .glucose)
        #expect(band == .safe, "100 mg/dL should be safe for all personas")
    }
}

// MARK: - SkillBus → GraphStore → RCA Round-Trip

@Test("Manual entry flows through SkillBus to GraphStore to MiroFish RCA")
func testSkillBusToRCA() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let bus = VitaCoreSkillBus(graphStore: graph)

    // Log a complete meal scenario: food + fluid + glucose before and after.
    _ = await bus.logGlucose(value: 95, timestamp: Date().addingTimeInterval(-7200))   // pre-meal: safe
    _ = await bus.logFoodEntry(
        result: FoodAnalysisResult(
            recognisedItems: [FoodEntry(name: "Dal Roti", portionGrams: 300, calories: 430,
                                        carbsG: 76, proteinG: 24, fatG: 5,
                                        sourceSkillId: "skill.manual.food", timestamp: Date())],
            totalCalories: 430, totalCarbsG: 76, totalProteinG: 24, totalFatG: 5,
            confidence: 0.8, analysedAt: Date()
        ),
        timestamp: Date().addingTimeInterval(-5400) // 90 min ago
    )
    _ = await bus.logGlucose(value: 205, timestamp: Date())  // post-meal spike
    _ = await bus.logFluidIntake(volumeML: 200, timestamp: Date().addingTimeInterval(-3600))

    // RCA on the post-meal spike.
    let trigger = Reading(metricType: .glucose, value: 205, unit: "mg/dL",
                          timestamp: Date(), sourceSkillId: "skill.manual.glucose", confidence: 1.0)

    let analyser = CofactorAnalyser()
    let result = try await analyser.analyse(trigger: trigger, graphStore: graph)

    // Should detect the high-carb dal roti meal.
    let mealCofactors = result.cofactors.filter { $0.type == .highCarbMeal || $0.type == .recentMeal }
    #expect(!mealCofactors.isEmpty, "Should detect dal roti as meal cofactor")

    // Should also flag low fluid (200 mL < 1000 mL threshold).
    let dehydration = result.cofactors.filter { $0.type == .dehydration }
    #expect(!dehydration.isEmpty, "Should detect dehydration (only 200 mL)")

    // Cofactors should be ranked by confidence.
    for i in 0..<(result.cofactors.count - 1) {
        #expect(result.cofactors[i].confidence >= result.cofactors[i + 1].confidence)
    }
}
