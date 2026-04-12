// HeartbeatEngineTests.swift

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
import VitaCoreSynthetic
import VitaCorePersona
import VitaCoreThreshold
@testable import VitaCoreHeartbeat

// MARK: - Thread-safe alert collector for @Sendable closures

private final class AlertCollector: @unchecked Sendable {
    private var _alerts: [HeartbeatAlert] = []
    var alerts: [HeartbeatAlert] { _alerts }
    var count: Int { _alerts.count }
    func append(_ alert: HeartbeatAlert) { _alerts.append(alert) }
}

// MARK: - HeartbeatEngine Tests

@Test("Engine detects hypo fast-path alert for glucose < 70")
func testHypoFastPath() async throws {
    let graph = try GRDBGraphStore.inMemory()

    // Seed cohort first so PersonaEngine can classify.
    let personaStore = try GRDBPersonaStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 1)
    try await cohort.write(to: graph)

    // Write a sub-70 glucose reading AFTER the cohort with a future
    // timestamp so it's the one getLatestReading returns.
    try await graph.writeReading(Reading(
        metricType: .glucose, value: 58, unit: "mg/dL",
        timestamp: Date().addingTimeInterval(1), sourceSkillId: "skill.cgmDexcom", confidence: 0.95
    ))

    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let engine = HeartbeatEngine(graphStore: graph, thresholdEngine: thresholdEngine)
    let collector = AlertCollector()
    engine.onAlert = { alert in collector.append(alert) }

    await engine.runCycle()

    let hypoAlerts = collector.alerts.filter { $0.metricType == .glucose && $0.isFastPath }
    #expect(!hypoAlerts.isEmpty, "Should fire fast-path hypo alert for glucose 58")
    #expect(hypoAlerts.first?.level == .critical)
}

@Test("Engine detects HR fast-path for resting HR > 120")
func testHRFastPath() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let personaStore = try GRDBPersonaStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .healthyOptimizer, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 2)
    try await cohort.write(to: graph)

    // Write elevated HR AFTER cohort with future timestamp.
    try await graph.writeReading(Reading(
        metricType: .heartRate, value: 135, unit: "bpm",
        timestamp: Date().addingTimeInterval(1), sourceSkillId: "skill.healthKitHR", confidence: 0.95
    ))
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let engine = HeartbeatEngine(graphStore: graph, thresholdEngine: thresholdEngine)
    let collector = AlertCollector()
    engine.onAlert = { alert in collector.append(alert) }

    await engine.runCycle()

    let hrAlerts = collector.alerts.filter { $0.metricType == .heartRate && $0.isFastPath }
    #expect(!hrAlerts.isEmpty, "Should fire fast-path HR alert for HR 135")
}

@Test("Engine detects threshold crossing safe → watch → alert")
func testThresholdCrossing() async throws {
    let graph = try GRDBGraphStore.inMemory()

    let personaStore = try GRDBPersonaStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 3)
    try await cohort.write(to: graph)
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let engine = HeartbeatEngine(graphStore: graph, thresholdEngine: thresholdEngine)
    let collector = AlertCollector()
    engine.onAlert = { alert in collector.append(alert) }

    // Cycle 1: safe glucose (no crossing, starting from safe).
    let t1 = Date().addingTimeInterval(1)
    try await graph.writeReading(Reading(
        metricType: .glucose, value: 120, unit: "mg/dL",
        timestamp: t1, sourceSkillId: "skill.cgmDexcom", confidence: 0.95
    ))
    await engine.runCycle()
    let alertsAfterSafe = collector.alerts.filter { $0.metricType == .glucose && !$0.isFastPath }
    #expect(alertsAfterSafe.isEmpty, "No crossing alert for safe reading on first cycle")

    // Cycle 2: watch glucose (crossing from safe → watch).
    let t2 = Date().addingTimeInterval(2)
    try await graph.writeReading(Reading(
        metricType: .glucose, value: 210, unit: "mg/dL",
        timestamp: t2, sourceSkillId: "skill.cgmDexcom", confidence: 0.95
    ))
    await engine.runCycle()
    let watchAlerts = collector.alerts.filter { $0.metricType == .glucose && !$0.isFastPath }
    #expect(!watchAlerts.isEmpty, "Should fire crossing alert from safe → watch")
}

@Test("Engine writes monitoring result episode to GraphStore")
func testMonitoringResultEpisode() async throws {
    let graph = try GRDBGraphStore.inMemory()

    let personaStore = try GRDBPersonaStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .healthyOptimizer, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 4)
    try await cohort.write(to: graph)
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let engine = HeartbeatEngine(graphStore: graph, thresholdEngine: thresholdEngine)
    await engine.runCycle()

    let episodes = try await graph.getEpisodes(
        from: Date().addingTimeInterval(-60),
        to: Date().addingTimeInterval(60),
        types: [.monitoringResult]
    )
    #expect(!episodes.isEmpty, "Should write a monitoringResult episode after each cycle")
}

@Test("Engine does not re-fire same crossing on consecutive cycles")
func testNoDuplicateCrossingAlert() async throws {
    let graph = try GRDBGraphStore.inMemory()

    let personaStore = try GRDBPersonaStore.inMemory()
    let cohort = CohortBuilder().buildCohort(archetype: .t1dPump, days: 14, endingAt: Date().addingTimeInterval(-172800), seed: 5)
    try await cohort.write(to: graph)
    let personaEngine = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
    let thresholdEngine = VitaCoreThresholdEngine(personaEngine: personaEngine)

    let engine = HeartbeatEngine(graphStore: graph, thresholdEngine: thresholdEngine)
    let collector = AlertCollector()
    engine.onAlert = { alert in collector.append(alert) }

    // Write elevated glucose after cohort and run two cycles.
    try await graph.writeReading(Reading(
        metricType: .glucose, value: 220, unit: "mg/dL",
        timestamp: Date().addingTimeInterval(1), sourceSkillId: "skill.cgmDexcom", confidence: 0.95
    ))

    await engine.runCycle()
    let firstCycleCount = collector.count

    await engine.runCycle()
    let secondCycleCount = collector.count

    // Second cycle should NOT re-fire the same crossing (band is now watch, not safe→watch).
    #expect(secondCycleCount == firstCycleCount, "Should not re-fire crossing alert on same band")
}
