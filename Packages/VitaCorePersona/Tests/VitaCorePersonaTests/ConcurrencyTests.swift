// ConcurrencyTests.swift — Sprint 5 Q-02
// Stress test: concurrent bootstrap + concurrent mutations.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
@testable import VitaCorePersona

@Test("N concurrent getPersonaContext on empty store → exactly one row")
func testConcurrentBootstrap() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 500)
    try await cohort.write(to: graph)

    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)

    // Fire 10 concurrent getPersonaContext calls.
    await withTaskGroup(of: PersonaContext?.self) { group in
        for _ in 0..<10 {
            group.addTask { try? await engine.getPersonaContext() }
        }
        var results: [PersonaContext] = []
        for await ctx in group {
            if let c = ctx { results.append(c) }
        }
        // All should return the same userId.
        let ids = Set(results.map(\.userId))
        #expect(ids.count == 1, "All concurrent bootstraps should produce the same userId, got \(ids.count)")
    }
}

@Test("Concurrent addMedication calls → all medications present")
func testConcurrentMutations() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .healthyOptimizer, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 501)
    try await cohort.write(to: graph)

    let store = try GRDBPersonaStore.inMemory()
    let engine = VitaCorePersonaEngine(store: store, graphStore: graph)
    _ = try await engine.getPersonaContext() // bootstrap

    let meds = [
        MedicationSummary(classKey: .metformin, name: "Metformin", dose: "500mg", frequency: "BID"),
        MedicationSummary(classKey: .insulin, name: "Lantus", dose: "20u", frequency: "QHS"),
        MedicationSummary(classKey: .aceInhibitor, name: "Lisinopril", dose: "10mg", frequency: "QD"),
    ]

    // Add all 3 medications concurrently.
    await withTaskGroup(of: Void.self) { group in
        for med in meds {
            group.addTask { try? await engine.addMedication(med) }
        }
    }

    let final = try await engine.getActiveMedications()
    #expect(final.count == 3, "All 3 concurrent medications should be present, got \(final.count)")
}
