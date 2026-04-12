// VitaCorePersonaEngineTests.swift
// VitaCorePersona — Tests for C01. Covers:
//
//   1. GRDBPersonaStore round-trip (save → load → matches).
//   2. PersonaInferencer classification against the four Sprint 0.3
//      synthetic cohorts (T1D pump, T2D oral/basal, prediabetic,
//      healthy optimizer).
//   3. Empty-graph path → healthy baseline with no hypertension.
//   4. VitaCorePersonaEngine bootstrap-on-first-read → persistence on
//      second read.
//   5. updateGoal / addMedication / removeMedication mutations.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
@testable import VitaCorePersona

// MARK: - 1. Store round-trip

@Test("GRDBPersonaStore saves and loads a context")
func testStoreRoundTrip() async throws {
    let store = try GRDBPersonaStore.inMemory()
    let uid = UUID()
    let ctx = PersonaContext(
        userId: uid,
        activeConditions: [
            ConditionSummary(conditionKey: .type1Diabetes, severity: "moderate", daysActive: 10)
        ],
        activeGoals: [
            GoalSummary(goalType: .timeInRange, target: 70, current: 60, direction: 1)
        ]
    )
    try await store.saveContext(ctx)
    let loaded = try await store.loadContext()
    #expect(loaded != nil)
    #expect(loaded?.userId == uid)
    #expect(loaded?.activeConditions.first?.conditionKey == .type1Diabetes)
    #expect(loaded?.activeGoals.first?.goalType == .timeInRange)
}

@Test("Empty store returns nil")
func testEmptyStoreReturnsNil() async throws {
    let store = try GRDBPersonaStore.inMemory()
    let loaded = try await store.loadContext()
    #expect(loaded == nil)
}

// MARK: - 2. Inferencer classification against synthetic cohorts

/// Helper: builds a 14-day cohort for the given archetype, writes it
/// into a fresh in-memory graph store, runs the inferencer, and
/// returns the classified archetype.
private func classify(
    _ archetype: PersonaArchetype,
    seed: UInt64 = 42
) async throws -> InferredArchetype {
    // Use a stable reference date so all synthetic cohorts land inside
    // the inferencer's 14-day window (the window is relative to `now`
    // which we pass explicitly).
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let cohort = CohortBuilder().buildCohort(
        archetype: archetype,
        days: 14,
        endingAt: now,
        seed: seed
    )
    let graph = try GRDBGraphStore.inMemory()
    try await cohort.write(to: graph)

    let inferencer = PersonaInferencer()
    let decision = try await inferencer.inferContext(
        from: graph,
        windowDays: 14,
        now: now
    )
    // All 4 synthetic cohorts cross the data-adequacy gate (CGM source
    // or >=21 glucose readings), so they MUST return `.confident`.
    guard case let .confident(inferred, _) = decision else {
        Issue.record("Expected .confident decision for \(archetype); got \(decision)")
        return .healthy
    }
    return inferred
}

@Test("T1D pump cohort classifies as likelyT1D")
func testClassifyT1D() async throws {
    let inferred = try await classify(.t1dPump)
    #expect(inferred == .likelyT1D)
}

@Test("T2D oral/basal cohort classifies as likelyT2D")
func testClassifyT2D() async throws {
    let inferred = try await classify(.t2dOralOrBasal)
    #expect(inferred == .likelyT2D)
}

@Test("Prediabetic cohort classifies as prediabetic")
func testClassifyPrediabetic() async throws {
    let inferred = try await classify(.prediabetic)
    #expect(inferred == .prediabetic)
}

@Test("Healthy optimizer cohort classifies as healthy")
func testClassifyHealthy() async throws {
    let inferred = try await classify(.healthyOptimizer)
    #expect(inferred == .healthy)
}

// MARK: - 3. Empty-graph baseline

@Test("Empty graph store returns provisional healthy baseline (T030)")
func testEmptyGraphHealthyBaseline() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let inferencer = PersonaInferencer()
    let decision = try await inferencer.inferContext(from: graph)

    // T030 / FR-014: empty graph MUST return a provisional decision,
    // NOT a confident one, so the engine won't persist it.
    guard case let .provisional(ctx) = decision else {
        Issue.record("Expected .provisional for empty graph; got \(decision)")
        return
    }
    #expect(ctx.activeConditions.contains { $0.conditionKey == .healthyBaseline })
    #expect(!ctx.activeConditions.contains { $0.conditionKey == .hypertension })
}

@Test("Empty-graph bootstrap does NOT persist (T030 / FR-014 regression guard)")
func testEmptyGraphBootstrapDoesNotPersist() async throws {
    // Core T030 regression guard: the engine MUST NOT lock a user
    // into `healthyBaseline` by persisting an empty-graph classification.
    let graph = try GRDBGraphStore.inMemory()
    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)

    // First read: returns the transient in-memory default.
    let first = try await engine.getPersonaContext()
    #expect(first.activeConditions.contains { $0.conditionKey == .healthyBaseline })

    // Store MUST still be empty.
    let stored = try await store.loadContext()
    #expect(stored == nil, "Empty-graph bootstrap must not persist — violates Principle VI")

    // Now seed the graph with a real T1D cohort. The next call MUST
    // re-run the inferencer (because the store is still empty) and
    // classify as T1D this time.
    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump,
        days: 14,
        endingAt: Date(),
        seed: 2026
    )
    try await cohort.write(to: graph)

    let second = try await engine.getPersonaContext()
    #expect(second.activeConditions.contains { $0.conditionKey == .type1Diabetes },
            "After graph has data, bootstrap must re-run and classify correctly")

    // Store MUST now contain a row.
    let storedAfter = try await store.loadContext()
    #expect(storedAfter != nil)
    #expect(storedAfter?.activeConditions.contains { $0.conditionKey == .type1Diabetes } == true)
}

// MARK: - 4. Engine bootstrap + persistence

@Test("Engine bootstraps from graph on first read, persists on second")
func testEngineBootstrapsAndPersists() async throws {
    let graph = try GRDBGraphStore.inMemory()
    // Engine.getPersonaContext() uses a `Date()`-relative 14-day window
    // internally, so the cohort must end at real "now" for the window
    // to overlap the synthesised timestamps.
    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump, days: 14,
        endingAt: Date(),
        seed: 11
    )
    try await cohort.write(to: graph)

    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)

    // 1st read — should bootstrap.
    let first = try await engine.getPersonaContext()
    #expect(first.activeConditions.contains { $0.conditionKey == .type1Diabetes })

    // Store should now contain a row.
    let stored = try await store.loadContext()
    #expect(stored != nil)
    #expect(stored?.userId == first.userId)

    // 2nd read — should come from store (same userId, same conditions).
    let second = try await engine.getPersonaContext()
    #expect(second.userId == first.userId)
    #expect(second.activeConditions == first.activeConditions)
}

// MARK: - 5. Mutation APIs

@Test("updateGoal patches only the targeted goal")
func testUpdateGoal() async throws {
    // Use a graph with real data so bootstrap persists (confident).
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .healthyOptimizer, days: 14,
        endingAt: Date(), seed: 77
    )
    try await cohort.write(to: graph)

    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)
    _ = try await engine.getPersonaContext()  // bootstraps as healthy (confident, persisted)

    try await engine.updateGoal(type: .stepsDaily, newTarget: 15_000)
    let after = try await engine.getPersonaContext()
    let steps = after.activeGoals.first { $0.goalType == .stepsDaily }
    #expect(steps?.target == 15_000)
    // Other goals unchanged.
    let untouched = after.activeGoals.filter { $0.goalType != .stepsDaily }
    for goal in untouched {
        #expect(goal.target != 15_000)
    }
}

@Test("addMedication appends; removeMedication deletes by id")
func testMedicationMutations() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .healthyOptimizer, days: 14,
        endingAt: Date(), seed: 88
    )
    try await cohort.write(to: graph)

    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)
    _ = try await engine.getPersonaContext()

    let med = MedicationSummary(
        classKey: .metformin,
        name: "Metformin",
        dose: "500mg",
        frequency: "BID"
    )
    try await engine.addMedication(med)
    var meds = try await engine.getActiveMedications()
    #expect(meds.count == 1)
    #expect(meds.first?.name == "Metformin")

    try await engine.removeMedication(id: med.id)
    meds = try await engine.getActiveMedications()
    #expect(meds.isEmpty)
}
