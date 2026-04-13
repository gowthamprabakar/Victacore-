// UnitDriftTests.swift — Sprint 5 Q-04
// Verify T033: mmol/L readings → correct classification (not false T1D).

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
@testable import VitaCorePersona

@Test("mmol/L glucose readings do NOT classify as T1D")
func testMmolLDoesNotTriggerT1D() async throws {
    let graph = try GRDBGraphStore.inMemory()

    // Write 20 glucose readings in mmol/L (European CGM format).
    // Healthy values: 4.5–6.5 mmol/L (= 81–117 mg/dL).
    let now = Date()
    var readings: [Reading] = []
    for i in 0..<20 {
        readings.append(Reading(
            metricType: .glucose,
            value: 5.0 + Double(i % 3) * 0.5,  // 5.0, 5.5, 6.0 mmol/L
            unit: "mmol/L",
            timestamp: now.addingTimeInterval(-Double(i) * 3600),
            sourceSkillId: "skill.cgmDexcom",
            confidence: 0.95
        ))
    }
    try await graph.writeReadings(readings)

    let inferencer = PersonaInferencer()
    let decision = try await inferencer.inferContext(from: graph, windowDays: 14, now: now)

    guard case let .confident(archetype, _) = decision else {
        // Provisional is also acceptable (data adequacy gate).
        return
    }

    // A healthy European user at 5.0 mmol/L should NOT be classified as T1D.
    #expect(archetype != .likelyT1D, "mmol/L readings should not trigger T1D classification")
    #expect(archetype == .healthy || archetype == .prediabetic,
            "5.0 mmol/L = 90 mg/dL = healthy range")
}

@Test("Mixed mg/dL and mmol/L readings normalise correctly")
func testMixedUnits() async throws {
    let graph = try GRDBGraphStore.inMemory()
    let now = Date()

    // Write some mg/dL and some mmol/L readings.
    try await graph.writeReadings([
        Reading(metricType: .glucose, value: 95, unit: "mg/dL",
                timestamp: now.addingTimeInterval(-7200), sourceSkillId: "skill.glucoseManual", confidence: 1.0),
        Reading(metricType: .glucose, value: 5.3, unit: "mmol/L",
                timestamp: now.addingTimeInterval(-3600), sourceSkillId: "skill.cgmLibre", confidence: 0.95),
        Reading(metricType: .glucose, value: 100, unit: "mg/dL",
                timestamp: now, sourceSkillId: "skill.glucoseManual", confidence: 1.0),
    ])

    // Add more to cross data-adequacy gate.
    for i in 3..<15 {
        try await graph.writeReading(Reading(
            metricType: .glucose, value: 92 + Double(i % 5),
            unit: "mg/dL", timestamp: now.addingTimeInterval(-Double(i) * 7200),
            sourceSkillId: "skill.glucoseManual", confidence: 1.0
        ))
    }

    let inferencer = PersonaInferencer()
    let decision = try await inferencer.inferContext(from: graph, windowDays: 14, now: now)
    let ctx = decision.context
    // Should classify as healthy — all values in 90-100 mg/dL range.
    #expect(ctx.activeConditions.contains { $0.conditionKey == .healthyBaseline })
}
