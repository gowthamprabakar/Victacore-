// CohortRoundTripTests.swift — Sprint 5 Q-01
// Constitution Gate #3: VitaCoreGraph tests with realistic multi-metric data.
// Cannot import VitaCoreSynthetic (circular dep), so we generate inline.

import Foundation
import Testing
import VitaCoreContracts
@testable import VitaCoreGraph

/// Helper: generate N glucose readings with realistic variance.
private func generateGlucose(n: Int, baseMean: Double, stdev: Double, from start: Date) -> [Reading] {
    (0..<n).map { i in
        let noise = Double((i * 7 + 13) % 20) - 10.0
        return Reading(
            metricType: .glucose,
            value: max(40, baseMean + noise * stdev / 10.0),
            unit: "mg/dL",
            timestamp: start.addingTimeInterval(Double(i) * 300),
            sourceSkillId: "skill.cgmDexcom",
            confidence: 0.95
        )
    }
}

private func generateHR(n: Int, from start: Date) -> [Reading] {
    (0..<n).map { i in
        return Reading(
            metricType: .heartRate,
            value: 65 + Double(i % 15),
            unit: "bpm",
            timestamp: start.addingTimeInterval(Double(i) * 900),
            sourceSkillId: "skill.healthKitHR",
            confidence: 0.95
        )
    }
}

@Test("Multi-metric write + read round-trip with 2000+ readings")
func testLargeRoundTrip() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let start = Date().addingTimeInterval(-7 * 86400)
    let end = Date()

    let glucose = generateGlucose(n: 2016, baseMean: 130, stdev: 40, from: start) // 7 days × 288/day
    let hr = generateHR(n: 672, from: start) // 7 days × 96/day (15-min)

    try await graph.writeReadings(glucose)
    try await graph.writeReadings(hr)

    let gRange = try await graph.getRangeReadings(for: .glucose, from: start, to: end)
    #expect(gRange.count == 2016)

    let hrRange = try await graph.getRangeReadings(for: .heartRate, from: start, to: end)
    #expect(hrRange.count == 672)
}

@Test("Aggregate on large dataset returns correct stats")
func testAggregateOnLargeData() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let start = Date().addingTimeInterval(-7 * 86400)
    let end = Date()

    let readings = generateGlucose(n: 500, baseMean: 140, stdev: 30, from: start)
    try await graph.writeReadings(readings)

    let agg = try await graph.getAggregatedMetric(for: .glucose, from: start, to: end)
    #expect(agg != nil)
    #expect(agg!.count == 500)
    #expect(agg!.average > 100 && agg!.average < 180)
    #expect(agg!.min < agg!.average)
    #expect(agg!.max > agg!.average)
}

@Test("Snapshot assembles latest from multi-metric dataset")
func testSnapshotFromMultiMetric() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    try await graph.writeReadings([
        Reading(metricType: .glucose, value: 137, unit: "mg/dL", timestamp: now, sourceSkillId: "test", confidence: 0.95),
        Reading(metricType: .heartRate, value: 68, unit: "bpm", timestamp: now, sourceSkillId: "test", confidence: 0.95),
        Reading(metricType: .bloodPressureSystolic, value: 120, unit: "mmHg", timestamp: now, sourceSkillId: "test", confidence: 0.95),
        Reading(metricType: .bloodPressureDiastolic, value: 80, unit: "mmHg", timestamp: now, sourceSkillId: "test", confidence: 0.95),
        Reading(metricType: .steps, value: 7500, unit: "steps", timestamp: now, sourceSkillId: "test", confidence: 0.98),
    ])

    let snap = try await graph.getCurrentSnapshot()
    #expect(snap.glucose?.value == 137)
    #expect(snap.heartRate?.value == 68)
    #expect(snap.bloodPressureSystolic?.value == 120)
    #expect(snap.steps?.value == 7500)
}

@Test("Purge removes readings older than cutoff from large dataset")
func testPurgeOnLargeData() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let start = Date().addingTimeInterval(-14 * 86400)

    let readings = generateGlucose(n: 1000, baseMean: 130, stdev: 30, from: start)
    try await graph.writeReadings(readings)

    let cutoff = Date().addingTimeInterval(-7 * 86400)
    try await graph.purgeReadings(for: .glucose, olderThan: cutoff)

    let remaining = try await graph.getRangeReadings(for: .glucose, from: start, to: Date())
    #expect(remaining.count < 1000)
    #expect(remaining.allSatisfy { $0.timestamp >= cutoff })
}
