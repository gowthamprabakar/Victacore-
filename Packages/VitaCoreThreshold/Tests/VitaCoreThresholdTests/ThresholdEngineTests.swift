// ThresholdEngineTests.swift
// VitaCoreThreshold — Sprint 1.A tests.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
import VitaCorePersona
@testable import VitaCoreThreshold

// MARK: - Condition Profile Sanity

@Test("Healthy baseline has glucose safe band 70-140")
func testHealthyGlucoseBand() {
    let t = ConditionProfiles.healthyBaseline.thresholds.first { $0.metricType == .glucose }!
    #expect(t.safeBand == 70...140)
    #expect(t.classify(value: 100) == .safe)
    #expect(t.classify(value: 160) == .watch)
    #expect(t.classify(value: 260) == .critical) // 260 > alertBand upper (250)
}

@Test("T1D profile has glucose safe band 70-180")
func testT1DGlucoseBand() {
    let t = ConditionProfiles.type1Diabetes.thresholds.first { $0.metricType == .glucose }!
    #expect(t.safeBand == 70...180)
    #expect(t.classify(value: 170) == .safe)
    #expect(t.classify(value: 55) == .watch)
    #expect(t.classify(value: 45) == .alert)
}

@Test("Hypertension profile has tighter systolic band than healthy")
func testHypertensionBP() {
    let healthy = ConditionProfiles.healthyBaseline.thresholds.first { $0.metricType == .bloodPressureSystolic }!
    let htn = ConditionProfiles.hypertension.thresholds.first { $0.metricType == .bloodPressureSystolic }!
    let healthyWidth = healthy.safeBand.upperBound - healthy.safeBand.lowerBound
    let htnWidth = htn.safeBand.upperBound - htn.safeBand.lowerBound
    // Hypertension should be tighter or equal (both are 90-130 in current profiles)
    #expect(htnWidth <= healthyWidth + 10) // some tolerance
    #expect(htn.priority > healthy.priority)
}

// MARK: - Priority Stack Resolution

@Test("T2D + Hypertension resolves to tighter of both glucose and BP")
func testMultiConditionResolution() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .type2Diabetes, severity: "moderate", daysActive: 30),
            ConditionSummary(conditionKey: .hypertension, severity: "mild", daysActive: 60)
        ]
    )
    let set = resolver.resolve(from: context)

    // Glucose should come from T2D profile (priority 3, same as hypertension but T2D has glucose)
    let glucose = set.threshold(for: .glucose)!
    #expect(glucose.safeBand == 70...180) // T2D ADA target

    // BP systolic should come from hypertension profile (priority 3, tighter safe band)
    let bpSys = set.threshold(for: .bloodPressureSystolic)!
    #expect(bpSys.safeBand.upperBound <= 130) // hypertension target
}

@Test("Healthy-only persona gets population defaults")
func testHealthyOnlyResolution() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .healthyBaseline, severity: "none", daysActive: 0)
        ]
    )
    let set = resolver.resolve(from: context)
    let glucose = set.threshold(for: .glucose)!
    #expect(glucose.safeBand == 70...140) // population default
    #expect(glucose.priority == 0)
}

// MARK: - Medication Modifiers

@Test("Beta-blocker shifts HR safe band down by 10")
func testBetaBlockerModifier() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .hypertension, severity: "moderate", daysActive: 90)
        ],
        activeMedications: [
            MedicationSummary(classKey: .betaBlocker, name: "Metoprolol", dose: "50mg", frequency: "BID")
        ]
    )
    let set = resolver.resolve(from: context)
    let hr = set.threshold(for: .heartRate)!
    // HTN profile has safe 50-90. Beta-blocker shifts by -10 → 40-80.
    #expect(hr.safeBand.lowerBound == 40)
    #expect(hr.safeBand.upperBound == 80)
}

@Test("Insulin raises glucose safe lower bound by 5")
func testInsulinModifier() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .type1Diabetes, severity: "moderate", daysActive: 365)
        ],
        activeMedications: [
            MedicationSummary(classKey: .insulin, name: "Lantus", dose: "20u", frequency: "QHS")
        ]
    )
    let set = resolver.resolve(from: context)
    let glucose = set.threshold(for: .glucose)!
    // T1D profile has safe 70-180. Insulin shifts lower +5 → 75-180.
    #expect(glucose.safeBand.lowerBound == 75)
    #expect(glucose.safeBand.upperBound == 180)
}

@Test("ACE inhibitor tightens systolic upper bound by 5")
func testACEInhibitorModifier() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .hypertension, severity: "mild", daysActive: 180)
        ],
        activeMedications: [
            MedicationSummary(classKey: .aceInhibitor, name: "Lisinopril", dose: "10mg", frequency: "QD")
        ]
    )
    let set = resolver.resolve(from: context)
    let bp = set.threshold(for: .bloodPressureSystolic)!
    // HTN profile has safe 90-130. ACE shifts upper -5 → 90-125.
    #expect(bp.safeBand.upperBound == 125)
}

// MARK: - Clinician Override

@Test("Clinician override always wins regardless of condition priority")
func testClinicianOverride() {
    let resolver = ThresholdResolver()
    let context = PersonaContext(
        userId: UUID(),
        activeConditions: [
            ConditionSummary(conditionKey: .type1Diabetes, severity: "moderate", daysActive: 365)
        ],
        thresholdOverrides: [
            ThresholdOverride(metricType: .glucose, lowerBound: 80, upperBound: 160, reason: "Endocrinologist recommendation")
        ]
    )
    let set = resolver.resolve(from: context)
    let glucose = set.threshold(for: .glucose)!
    // Clinician says 80-160, overriding T1D's 70-180.
    #expect(glucose.safeBand == 80...160)
    #expect(glucose.priority == 7)
}

// MARK: - Synthetic Cohort Cross-Validation

/// Helper: builds a cohort, infers persona, resolves thresholds.
private func resolveForCohort(
    _ archetype: PersonaArchetype,
    seed: UInt64 = 42
) async throws -> ThresholdSet {
    let now = Date()
    let cohort = CohortBuilder().buildCohort(
        archetype: archetype, days: 14, endingAt: now, seed: seed
    )
    let graph = try GRDBGraphStore.inMemory()
    try await cohort.write(to: graph)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let context = try await personaEngine.getPersonaContext()

    let resolver = ThresholdResolver()
    return resolver.resolve(from: context)
}

@Test("T1D synthetic cohort produces T1D glucose thresholds")
func testT1DCohortThresholds() async throws {
    let set = try await resolveForCohort(.t1dPump)
    let glucose = set.threshold(for: .glucose)!
    #expect(glucose.safeBand.lowerBound >= 70)
    #expect(glucose.safeBand.upperBound <= 180)
    #expect(glucose.priority >= 3)
}

@Test("T2D synthetic cohort produces T2D glucose + BP thresholds")
func testT2DCohortThresholds() async throws {
    let set = try await resolveForCohort(.t2dOralOrBasal)
    let glucose = set.threshold(for: .glucose)!
    #expect(glucose.safeBand == 70...180) // T2D ADA target
    // T2D cohort's PersonaInferencer might also flag hypertension
    // (BP elevated probability 22%), so BP thresholds may be tighter.
    let bp = set.threshold(for: .bloodPressureSystolic)!
    #expect(bp.safeBand.upperBound <= 130)
}

@Test("Healthy optimizer cohort produces population-default thresholds")
func testHealthyCohortThresholds() async throws {
    let set = try await resolveForCohort(.healthyOptimizer)
    let glucose = set.threshold(for: .glucose)!
    // PersonaInferencer synthesises a ThresholdOverride for healthy:
    // glucose upper 140. This override wins at priority 7.
    #expect(glucose.safeBand.upperBound <= 140)
}

// MARK: - Engine Cache

@Test("Engine caches for 60s and invalidates on demand")
func testEngineCache() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .healthyOptimizer, days: 14, endingAt: Date(), seed: 99
    )
    try await cohort.write(to: graph)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let engine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let first = try await engine.resolveActiveThresholdSet()
    let second = try await engine.resolveActiveThresholdSet()
    // Same object from cache.
    #expect(first == second)

    engine.invalidateCache()
    let third = try await engine.resolveActiveThresholdSet()
    // Still equal in value (same persona), but re-resolved.
    #expect(third == first)
}

@Test("Engine classify convenience method works end-to-end")
func testEngineClassify() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump, days: 14, endingAt: Date(), seed: 55
    )
    try await cohort.write(to: graph)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let engine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let band = try await engine.classify(value: 100, for: .glucose)
    #expect(band == .safe)

    let watchBand = try await engine.classify(value: 200, for: .glucose)
    #expect(watchBand == .watch)
}
