// CohortBuilderTests.swift
// VitaCoreSynthetic — End-to-end tests covering the three things we
// care about most: (1) same seed → byte-identical output, (2) generated
// values land in clinically-plausible ranges per persona, (3) ground-
// truth episodes agree with a naive re-scan of the same reading stream.

import Foundation
import Testing
import VitaCoreContracts
import VitaCoreGraph
@testable import VitaCoreSynthetic

// MARK: - Determinism

@Test("Same seed produces byte-identical cohorts")
func testDeterminism() {
    let builder = CohortBuilder()
    let fixedEnd = Date(timeIntervalSince1970: 1_800_000_000)  // stable reference

    let a = builder.buildCohort(
        archetype: .t1dPump,
        days: 7,
        endingAt: fixedEnd,
        seed: 42
    )
    let b = builder.buildCohort(
        archetype: .t1dPump,
        days: 7,
        endingAt: fixedEnd,
        seed: 42
    )

    #expect(a.readingCount == b.readingCount)
    #expect(a.episodeCount == b.episodeCount)

    // Compare the value streams position by position. UUIDs differ
    // (random), so we fingerprint on (metric, value, timestamp, source).
    for (l, r) in zip(a.readings, b.readings) {
        #expect(l.metricType == r.metricType)
        #expect(l.value == r.value)
        #expect(l.timestamp == r.timestamp)
        #expect(l.sourceSkillId == r.sourceSkillId)
    }
}

@Test("Different seeds produce distinct cohorts")
func testSeedsDiverge() {
    let builder = CohortBuilder()
    let fixedEnd = Date(timeIntervalSince1970: 1_800_000_000)

    let a = builder.buildCohort(
        archetype: .healthyOptimizer,
        days: 7,
        endingAt: fixedEnd,
        seed: 1
    )
    let b = builder.buildCohort(
        archetype: .healthyOptimizer,
        days: 7,
        endingAt: fixedEnd,
        seed: 2
    )

    // Heart-rate readings exist for every persona regardless of CGM.
    let aHR = a.readings.first { $0.metricType == .heartRate }?.value ?? -1
    let bHR = b.readings.first { $0.metricType == .heartRate }?.value ?? -2
    #expect(aHR != bHR)
}

// MARK: - Persona range sanity

@Test("T1D glucose spans a wider range than healthy optimizer")
func testT1DGlucoseRangeWiderThanHealthy() {
    let builder = CohortBuilder()
    let end = Date(timeIntervalSince1970: 1_800_000_000)
    let t1d = builder.buildCohort(archetype: .t1dPump, days: 7, endingAt: end, seed: 7)
    let opt = builder.buildCohort(archetype: .healthyOptimizer, days: 7, endingAt: end, seed: 7)

    func stats(_ cohort: SyntheticCohort) -> (min: Double, max: Double) {
        let values = cohort.readings.filter { $0.metricType == .glucose }.map(\.value)
        return (values.min() ?? 0, values.max() ?? 0)
    }

    let t1dS = stats(t1d)
    let optS = stats(opt)
    #expect((t1dS.max - t1dS.min) > (optS.max - optS.min))
    // Healthy optimiser stays comfortably below diabetic-spike territory.
    #expect(optS.max < 180)
}

@Test("Healthy optimiser never triggers hypoglycemic episodes")
func testHealthyOptimiserNoHypo() {
    let builder = CohortBuilder()
    let cohort = builder.buildCohort(
        archetype: .healthyOptimizer,
        days: 14,
        endingAt: Date(timeIntervalSince1970: 1_800_000_000),
        seed: 999
    )
    let hypos = cohort.episodes.filter { $0.episodeType == .cgmGlucose }
    // Healthy optimiser has hypoProbability == 0 so the only way a hypo
    // could appear is if the base model dips below 70 naturally — which
    // it shouldn't for someone with fasting 92 ± 12.
    #expect(hypos.isEmpty)
}

@Test("T1D cohort produces at least one episode over 14 days")
func testT1DProducesEpisodes() {
    let builder = CohortBuilder()
    let cohort = builder.buildCohort(
        archetype: .t1dPump,
        days: 14,
        endingAt: Date(timeIntervalSince1970: 1_800_000_000),
        seed: 123
    )
    #expect(cohort.episodes.count > 0)
}

// MARK: - GRDB round-trip

@Test("Cohort writes to in-memory GRDB and reads back intact")
func testCohortRoundTripThroughGRDB() async throws {
    let store = try GRDBGraphStore.inMemory()
    let cohort = CohortBuilder().buildCohort(
        archetype: .t2dOralOrBasal,
        days: 3,
        endingAt: Date(timeIntervalSince1970: 1_800_000_000),
        seed: 55
    )
    try await cohort.write(to: store)

    // Sanity: we should be able to pull a glucose reading back.
    let latest = try await store.getLatestReading(for: .glucose)
    #expect(latest != nil)

    // And the full-range fetch should return at least the fingerstick
    // count we expected for 3 days of t2dOralOrBasal.
    let range = try await store.getRangeReadings(
        for: .glucose,
        from: cohort.start,
        to: cohort.end
    )
    #expect(range.count >= 3 * 3)  // 3 fingersticks/day * 3 days
}

// MARK: - Episode labeler agreement

@Test("Labeler agrees with naive re-scan for sub-70 glucose")
func testLabelerAgreesWithRescan() {
    let cohort = CohortBuilder().buildCohort(
        archetype: .t1dPump,
        days: 7,
        endingAt: Date(timeIntervalSince1970: 1_800_000_000),
        seed: 31
    )

    // Naive oracle: every contiguous sub-70 run in the glucose stream
    // should produce exactly one episode from the labeler.
    let glucose = cohort.readings
        .filter { $0.metricType == .glucose }
        .sorted { $0.timestamp < $1.timestamp }

    var naiveRunCount = 0
    var inRun = false
    for r in glucose {
        if r.value < 70 {
            if !inRun { naiveRunCount += 1; inRun = true }
        } else {
            inRun = false
        }
    }

    let labeledHypoCount = cohort.episodes.filter {
        $0.episodeType == .cgmGlucose &&
        (try? JSONSerialization.jsonObject(with: $0.payload) as? [String: Any])?["direction"] as? String == "below"
    }.count

    #expect(labeledHypoCount == naiveRunCount)
}
