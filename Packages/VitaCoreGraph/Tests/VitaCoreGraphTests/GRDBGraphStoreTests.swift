// GRDBGraphStoreTests.swift
// VitaCoreGraph — Unit tests proving the GRDB-backed store conforms to
// GraphStoreProtocol and behaves identically to the MockGraphStore.

import Foundation
import Testing
import VitaCoreContracts
@testable import VitaCoreGraph

// MARK: - Writes + Latest reading

@Test("writeReading then getLatestReading round-trips the value")
func testWriteAndReadLatest() async throws {
    let store = try GRDBGraphStore.inMemory()

    let reading = Reading(
        metricType:     .glucose,
        value:          142.0,
        unit:           "mg/dL",
        timestamp:      Date(),
        sourceSkillId:  "skill.cgm.dexcom",
        confidence:     0.95,
        trendDirection: .stable,
        trendVelocity:  0.2
    )

    try await store.writeReading(reading)

    let fetched = try await store.getLatestReading(for: .glucose)
    #expect(fetched?.value == 142.0)
    #expect(fetched?.unit == "mg/dL")
    #expect(fetched?.trendDirection == .stable)
}

// MARK: - Multiple readings, correct ordering

@Test("getLatestReading returns the most recent reading when multiple exist")
func testLatestReadingOrderedByTimestamp() async throws {
    let store = try GRDBGraphStore.inMemory()
    let now = Date()

    let older = Reading(
        metricType: .glucose, value: 130, unit: "mg/dL",
        timestamp: now.addingTimeInterval(-3600),
        sourceSkillId: "test", confidence: 0.9
    )
    let newer = Reading(
        metricType: .glucose, value: 142, unit: "mg/dL",
        timestamp: now,
        sourceSkillId: "test", confidence: 0.9
    )

    try await store.writeReading(older)
    try await store.writeReading(newer)

    let latest = try await store.getLatestReading(for: .glucose)
    #expect(latest?.value == 142)
}

// MARK: - Range query

@Test("getRangeReadings returns readings within the window, ordered ascending")
func testRangeReadings() async throws {
    let store = try GRDBGraphStore.inMemory()
    let base = Date()

    // 5 readings, 10 minutes apart
    var readings: [Reading] = []
    for i in 0..<5 {
        readings.append(
            Reading(
                metricType: .glucose,
                value: Double(100 + i * 10),
                unit: "mg/dL",
                timestamp: base.addingTimeInterval(Double(i) * 600),
                sourceSkillId: "test",
                confidence: 0.9
            )
        )
    }
    try await store.writeReadings(readings)

    let window = try await store.getRangeReadings(
        for: .glucose,
        from: base,
        to: base.addingTimeInterval(1800) // first 30 min = 4 readings
    )
    #expect(window.count == 4)
    #expect(window.first?.value == 100)
    #expect(window.last?.value == 130)
}

// MARK: - Aggregate

@Test("getAggregatedMetric computes min/max/avg/count correctly")
func testAggregate() async throws {
    let store = try GRDBGraphStore.inMemory()
    let base = Date()
    let values: [Double] = [100, 120, 140, 160, 180]

    let readings = values.enumerated().map { i, v in
        Reading(
            metricType: .glucose,
            value: v,
            unit: "mg/dL",
            timestamp: base.addingTimeInterval(Double(i) * 60),
            sourceSkillId: "test",
            confidence: 0.9
        )
    }
    try await store.writeReadings(readings)

    let agg = try await store.getAggregatedMetric(
        for: .glucose,
        from: base,
        to: base.addingTimeInterval(600)
    )
    #expect(agg?.count == 5)
    #expect(agg?.min == 100)
    #expect(agg?.max == 180)
    #expect(agg?.average == 140)
}

// MARK: - Monitoring snapshot

@Test("getCurrentSnapshot assembles the latest reading for every metric")
func testSnapshotAssembly() async throws {
    let store = try GRDBGraphStore.inMemory()
    let now = Date()

    try await store.writeReading(
        Reading(metricType: .glucose, value: 142, unit: "mg/dL",
                timestamp: now, sourceSkillId: "cgm", confidence: 0.9)
    )
    try await store.writeReading(
        Reading(metricType: .heartRate, value: 68, unit: "bpm",
                timestamp: now, sourceSkillId: "hk", confidence: 0.92)
    )
    try await store.writeReading(
        Reading(metricType: .steps, value: 7520, unit: "steps",
                timestamp: now, sourceSkillId: "hk", confidence: 0.95)
    )

    let snap = try await store.getCurrentSnapshot()
    #expect(snap.glucose?.value == 142)
    #expect(snap.heartRate?.value == 68)
    #expect(snap.steps?.value == 7520)
    #expect(snap.bloodPressureSystolic == nil)      // never written
    #expect(snap.dataQuality == .poor)              // only 3 metrics populated
}

// MARK: - Episodes

@Test("writeEpisode / getEpisodes round-trips the full payload")
func testEpisodes() async throws {
    let store = try GRDBGraphStore.inMemory()
    let now = Date()
    let payload = "{\"source\":\"test\"}".data(using: .utf8)!

    let episode = Episode(
        episodeType:      .manualGlucose,
        sourceSkillId:    "skill.manual.glucose",
        sourceConfidence: 0.7,
        referenceTime:    now,
        payload:          payload
    )
    try await store.writeEpisode(episode)

    let fetched = try await store.getEpisodes(
        from: now.addingTimeInterval(-3600),
        to:   now.addingTimeInterval(3600),
        types: [.manualGlucose]
    )
    #expect(fetched.count == 1)
    #expect(fetched.first?.episodeType == .manualGlucose)
    #expect(fetched.first?.payload == payload)
}

// MARK: - Type filter

@Test("getEpisodes filters by type when types array is non-empty")
func testEpisodeTypeFilter() async throws {
    let store = try GRDBGraphStore.inMemory()
    let now = Date()
    let emptyPayload = Data()

    try await store.writeEpisode(
        Episode(episodeType: .cgmGlucose, sourceSkillId: "cgm",
                sourceConfidence: 0.95, referenceTime: now, payload: emptyPayload)
    )
    try await store.writeEpisode(
        Episode(episodeType: .bpReading, sourceSkillId: "bp",
                sourceConfidence: 0.9, referenceTime: now, payload: emptyPayload)
    )

    let glucose = try await store.getEpisodes(
        from: now.addingTimeInterval(-3600),
        to:   now.addingTimeInterval(3600),
        types: [.cgmGlucose]
    )
    #expect(glucose.count == 1)
    #expect(glucose.first?.episodeType == .cgmGlucose)
}

// MARK: - Purge

@Test("purgeReadings removes readings older than cutoff")
func testPurge() async throws {
    let store = try GRDBGraphStore.inMemory()
    let now = Date()

    try await store.writeReading(
        Reading(metricType: .glucose, value: 100, unit: "mg/dL",
                timestamp: now.addingTimeInterval(-7200), // 2h ago
                sourceSkillId: "test", confidence: 0.9)
    )
    try await store.writeReading(
        Reading(metricType: .glucose, value: 142, unit: "mg/dL",
                timestamp: now,
                sourceSkillId: "test", confidence: 0.9)
    )

    // Purge everything older than 1 hour
    try await store.purgeReadings(
        for: .glucose,
        olderThan: now.addingTimeInterval(-3600)
    )

    let range = try await store.getRangeReadings(
        for: .glucose,
        from: now.addingTimeInterval(-86400),
        to: now.addingTimeInterval(1)
    )
    #expect(range.count == 1)
    #expect(range.first?.value == 142)
}
