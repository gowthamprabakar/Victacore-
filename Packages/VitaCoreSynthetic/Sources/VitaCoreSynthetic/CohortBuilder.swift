// CohortBuilder.swift
// VitaCoreSynthetic — Top-level orchestrator.
//
// Callers use `CohortBuilder` to produce a complete synthetic dataset
// for a given persona × date range × seed, as a `SyntheticCohort` value
// containing all `Reading` and `Episode` records. The cohort can then be
// written to any `GraphStoreProtocol` via `write(to:)` — tests use an
// in-memory GRDB, demo mode writes into the real on-disk store.

import Foundation
import VitaCoreContracts

// MARK: - SyntheticCohort

/// The full output of a synthetic generation run. Immutable value type,
/// cheap to pass around and compare in tests.
public struct SyntheticCohort: Sendable, Hashable {
    public let archetype: PersonaArchetype
    public let start: Date
    public let end: Date
    public let seed: UInt64
    public let readings: [Reading]
    public let episodes: [Episode]

    /// Total number of readings, for quick test sanity checks.
    public var readingCount: Int { readings.count }
    /// Total number of ground-truth episodes.
    public var episodeCount: Int { episodes.count }
}

// MARK: - CohortBuilder

public struct CohortBuilder {

    public init() {}

    // -------------------------------------------------------------------------
    // MARK: Build
    // -------------------------------------------------------------------------

    /// Builds a full multi-metric synthetic cohort for the given
    /// persona, date range, and seed. Output is deterministic —
    /// identical inputs yield byte-identical readings and episodes
    /// (modulo `Reading.id` / `Episode.id` UUIDs, which are random but
    /// excluded from the `Hashable` fingerprint below).
    public func buildCohort(
        archetype: PersonaArchetype,
        days: Int,
        endingAt end: Date = Date(),
        seed: UInt64
    ) -> SyntheticCohort {
        precondition(days > 0, "CohortBuilder.buildCohort: days must be > 0")

        let traits = archetype.defaultTraits
        var rng = SeededGenerator(seed: seed)

        // Calendar-aligned day list, starting at midnight `days` ago.
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.date(
            byAdding: .day,
            value: -(days - 1),
            to: cal.startOfDay(for: end)
        ) ?? end
        let dayList: [Date] = (0..<days).map {
            cal.date(byAdding: .day, value: $0, to: startDay) ?? startDay
        }
        let rangeStart = startDay
        let rangeEnd = cal.date(
            byAdding: .day,
            value: 1,
            to: dayList.last ?? startDay
        ) ?? end

        // -- Workout days + windows (consumed by glucose + HR gens) ----
        var workoutDaySet: Set<Date> = []
        var workoutWindows: [DateInterval] = []
        for day in dayList {
            if rng.nextBernoulli(traits.workoutDayProbability) {
                workoutDaySet.insert(cal.startOfDay(for: day))
                let workoutHour = rng.nextUniform(7.0, 18.0)
                let start = day.addingTimeInterval(workoutHour * 3600)
                let duration = rng.nextUniform(30 * 60, 75 * 60)  // 30–75 min
                workoutWindows.append(DateInterval(start: start, duration: duration))
            }
        }

        // -- Meal schedule (drives glucose + food log gens) ------------
        let mealGen = MealScheduleGenerator(traits: traits)
        let meals = mealGen.generate(days: dayList, rng: &rng)

        // -- Glucose (the main signal) ---------------------------------
        let glucoseGen = GlucoseGenerator(
            traits: traits,
            mealSchedule: meals,
            workoutWindows: workoutWindows
        )
        let glucoseReadings = glucoseGen.generate(
            from: rangeStart,
            to: rangeEnd,
            rng: &rng
        )

        // -- Food log --------------------------------------------------
        let foodGen = FoodLogGenerator(traits: traits)
        let foodReadings = foodGen.generate(meals: meals)

        // -- Heart rate ------------------------------------------------
        let hrGen = HeartRateGenerator(traits: traits, workoutWindows: workoutWindows)
        let hrReadings = hrGen.generate(from: rangeStart, to: rangeEnd, rng: &rng)

        // -- Steps -----------------------------------------------------
        let stepGen = StepGenerator(traits: traits)
        let stepReadings = stepGen.generate(
            days: dayList,
            workoutDays: workoutDaySet,
            rng: &rng
        )

        // -- Sleep -----------------------------------------------------
        let sleepGen = SleepGenerator(traits: traits)
        let sleepReadings = sleepGen.generate(days: dayList, rng: &rng)

        // -- Blood pressure --------------------------------------------
        let bpGen = BloodPressureGenerator(traits: traits)
        let bpReadings = bpGen.generate(days: dayList, rng: &rng)

        // -- Weight ----------------------------------------------------
        let weightGen = WeightGenerator(traits: traits)
        let weightReadings = weightGen.generate(days: dayList, rng: &rng)

        // -- Merge + sort ----------------------------------------------
        var allReadings: [Reading] = []
        allReadings.reserveCapacity(
            glucoseReadings.count +
            foodReadings.count +
            hrReadings.count +
            stepReadings.count +
            sleepReadings.count +
            bpReadings.count +
            weightReadings.count
        )
        allReadings.append(contentsOf: glucoseReadings)
        allReadings.append(contentsOf: foodReadings)
        allReadings.append(contentsOf: hrReadings)
        allReadings.append(contentsOf: stepReadings)
        allReadings.append(contentsOf: sleepReadings)
        allReadings.append(contentsOf: bpReadings)
        allReadings.append(contentsOf: weightReadings)
        allReadings.sort { $0.timestamp < $1.timestamp }

        // -- Ground-truth episodes -------------------------------------
        let labeler = EpisodeLabeler()
        let episodes = labeler.label(readings: allReadings)

        return SyntheticCohort(
            archetype: archetype,
            start: rangeStart,
            end: rangeEnd,
            seed: seed,
            readings: allReadings,
            episodes: episodes
        )
    }
}

// MARK: - GraphStore writer

public extension SyntheticCohort {

    /// Writes every reading and episode in this cohort into the given
    /// graph store. Readings are written first (batched), then episodes
    /// one by one. This is the single entry point used by the demo-mode
    /// hook and by tests that want to exercise full-stack queries.
    func write(to store: GraphStoreProtocol) async throws {
        try await store.writeReadings(readings)
        for ep in episodes {
            try await store.writeEpisode(ep)
        }
    }
}
