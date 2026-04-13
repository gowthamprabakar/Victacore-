// LatencyTests.swift — Sprint 5 Q-06
// Performance benchmarks: ThresholdEngine < 50ms, GraphStore < 20ms.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
import VitaCorePersona
@testable import VitaCoreThreshold

@Test("ThresholdEngine resolve < 200ms uncached")
func testThresholdResolveLatency() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 800)
    try await cohort.write(to: graph)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let engine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    engine.invalidateCache()

    let start = Date()
    _ = try await engine.resolveActiveThresholdSet()
    let elapsed = Date().timeIntervalSince(start) * 1000

    #expect(elapsed < 200, "ThresholdEngine resolve should be < 200ms, was \(String(format: "%.1f", elapsed))ms")
}

@Test("ThresholdEngine resolve < 50ms cached")
func testThresholdResolveCachedLatency() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .healthyOptimizer, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 801)
    try await cohort.write(to: graph)

    let personaStore = try GRDBPersonaStore.inMemory()
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let engine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    // Warm the cache.
    _ = try await engine.resolveActiveThresholdSet()

    let start = Date()
    _ = try await engine.resolveActiveThresholdSet()
    let elapsed = Date().timeIntervalSince(start) * 1000

    #expect(elapsed < 50, "Cached resolve should be < 50ms, was \(String(format: "%.1f", elapsed))ms")
}

@Test("GraphStore getLatestReading < 20ms on 7-day cohort")
func testGraphStoreLatency() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 7, endingAt: Date().addingTimeInterval(-172800), seed: 802)
    try await cohort.write(to: graph)

    let start = Date()
    _ = try await graph.getLatestReading(for: .glucose)
    let elapsed = Date().timeIntervalSince(start) * 1000

    #expect(elapsed < 20, "getLatestReading should be < 20ms, was \(String(format: "%.1f", elapsed))ms")
}
