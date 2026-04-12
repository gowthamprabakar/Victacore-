// GlucoseGenerator.swift
// VitaCoreSynthetic — Multi-component glucose time-series generator.
//
// Produces a continuous-glucose-monitor-like stream (or fingerstick-only
// stream, depending on the persona's `cgmSamplesPerHour`) with the
// following physiological components layered together:
//
//   1. Baseline  — persona-specific fasting mean, slowly drifting.
//   2. Circadian — gentle sinusoidal day/night oscillation.
//   3. Dawn phenomenon — 05:00–08:00 rise, persona-specific amplitude.
//   4. Meal excursions — post-meal spikes keyed off a meal schedule,
//      gamma-shaped response curve peaking ~60–90 min after the meal.
//   5. Exercise dips — workout windows produce a temporary drop.
//   6. Stochastic hypoglycemic events — rare, triggered by a Bernoulli
//      draw against `glucoseHypoEventProbability`.
//   7. Sensor noise — Gaussian noise per reading at `glucoseSensorNoise`.
//
// Every component is deterministic given the same `SeededGenerator`, so
// committed fixtures stay byte-identical across runs.

import Foundation
import VitaCoreContracts

// MARK: - GlucoseGenerator

public struct GlucoseGenerator {

    public let traits: TraitProfile
    public let mealSchedule: [MealEvent]
    public let workoutWindows: [DateInterval]

    public init(
        traits: TraitProfile,
        mealSchedule: [MealEvent],
        workoutWindows: [DateInterval] = []
    ) {
        self.traits = traits
        self.mealSchedule = mealSchedule
        self.workoutWindows = workoutWindows
    }

    // -------------------------------------------------------------------------
    // MARK: Public entry point
    // -------------------------------------------------------------------------

    /// Generates glucose readings across `[start, end)`. If the persona
    /// uses a CGM (`cgmSamplesPerHour > 0`), readings are emitted at the
    /// CGM cadence; otherwise only fingerstick checks at the scheduled
    /// check times are emitted.
    public func generate(
        from start: Date,
        to end: Date,
        rng: inout SeededGenerator
    ) -> [Reading] {
        var readings: [Reading] = []
        let source = traits.cgmSamplesPerHour > 0
            ? "skill.cgmDexcom"
            : "skill.glucoseManual"
        let unit = MetricType.glucose.unit

        // -- CGM path --------------------------------------------------
        if traits.cgmSamplesPerHour > 0 {
            let intervalSeconds = 3600.0 / Double(traits.cgmSamplesPerHour)
            var t = start
            while t < end {
                let value = valueAt(time: t, rng: &rng)
                readings.append(
                    Reading(
                        metricType: .glucose,
                        value: value,
                        unit: unit,
                        timestamp: t,
                        sourceSkillId: source,
                        confidence: 0.95,
                        trendDirection: .stable
                    )
                )
                t = t.addingTimeInterval(intervalSeconds)
            }
        }

        // -- Fingerstick path (in addition to CGM for T1D, or solo) ----
        if traits.fingerstickChecksPerDay > 0 {
            let totalDays = max(1, Int(end.timeIntervalSince(start) / 86400))
            let checksTotal = traits.fingerstickChecksPerDay * totalDays
            let span = end.timeIntervalSince(start)
            for _ in 0..<checksTotal {
                let offset = rng.nextUniform(0, span)
                let t = start.addingTimeInterval(offset)
                let value = valueAt(time: t, rng: &rng)
                readings.append(
                    Reading(
                        metricType: .glucose,
                        value: value,
                        unit: unit,
                        timestamp: t,
                        sourceSkillId: "skill.glucoseManual",
                        confidence: 1.0,
                        trendDirection: .stable
                    )
                )
            }
        }

        // Apply trend labels now that we have the full series, then
        // return sorted by timestamp so consumers see a monotonic stream.
        let sorted = readings.sorted { $0.timestamp < $1.timestamp }
        return labelTrends(sorted)
    }

    // -------------------------------------------------------------------------
    // MARK: Value model
    // -------------------------------------------------------------------------

    /// Computes the glucose value at a specific moment by summing all
    /// physiological components.
    private func valueAt(time: Date, rng: inout SeededGenerator) -> Double {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute], from: time)
        let hour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0

        // 1. Baseline + 2. Circadian oscillation (±6 mg/dL, trough at 03:00)
        let circadianPhase = 2.0 * .pi * (hour - 3.0) / 24.0
        let circadian = 6.0 * sin(circadianPhase)
        var v = traits.glucoseFastingMean + circadian

        // 3. Dawn phenomenon — smooth rise 05:00–08:00, decay by 10:00.
        if hour >= 5.0 && hour <= 10.0 {
            let dawnPhase = (hour - 5.0) / 5.0               // 0..1
            let dawnShape = sin(dawnPhase * .pi)              // 0..1..0
            v += traits.glucoseDawnAmplitude * dawnShape
        }

        // 4. Meal excursions — sum of gamma responses from all past meals.
        for meal in mealSchedule {
            let dt = time.timeIntervalSince(meal.time) / 60.0  // minutes
            if dt > 0 && dt < 240 {                            // 4h response window
                v += mealResponse(dtMinutes: dt, carbs: meal.carbs)
            }
        }

        // 5. Exercise dips — linear drop up to 25 mg/dL during workout.
        for window in workoutWindows {
            if window.contains(time) {
                let progress = time.timeIntervalSince(window.start) / window.duration
                v -= 25.0 * sin(progress * .pi)
                break
            }
            // Post-exercise recovery (mild lingering drop up to 2h after)
            let postEnd = window.end.addingTimeInterval(7200)
            if time > window.end && time < postEnd {
                let frac = time.timeIntervalSince(window.end) / 7200
                v -= 8.0 * (1.0 - frac)
            }
        }

        // 6. Stochastic hypoglycemic events (rare, persona-gated)
        if rng.nextBernoulli(traits.glucoseHypoEventProbability) {
            v -= rng.nextUniform(20, 55)
        }

        // 7. Sensor noise (Gaussian)
        v += rng.nextGaussian(mean: 0, stdev: traits.glucoseSensorNoise)

        // Physiological clamp — below 30 or above 500 are not meaningful.
        return max(30, min(500, v))
    }

    /// Post-meal glucose response modelled as a gamma-shaped curve.
    /// Peak roughly at t=75 min, returning to baseline by t≈240 min.
    /// Amplitude scales with meal carbs (100g carbs = full amplitude).
    private func mealResponse(dtMinutes: Double, carbs: Double) -> Double {
        let amplitudeScale = min(carbs / 100.0, 1.5)
        let peakAmp = traits.glucoseMealSpikeAmplitude * amplitudeScale
        // Gamma-like shape: t * exp(-t/k) normalised so max == 1 at t=k.
        let k = 75.0
        let normalised = (dtMinutes / k) * exp(1.0 - dtMinutes / k)
        return peakAmp * max(0, normalised)
    }

    // -------------------------------------------------------------------------
    // MARK: Trend labelling
    // -------------------------------------------------------------------------

    /// Walks the sorted reading stream and assigns a `TrendDirection`
    /// based on the slope over a 15-minute trailing window.
    private func labelTrends(_ sorted: [Reading]) -> [Reading] {
        guard sorted.count > 1 else { return sorted }
        var labelled: [Reading] = []
        labelled.reserveCapacity(sorted.count)

        for i in sorted.indices {
            let current = sorted[i]
            // Find the earliest reading in the trailing 15-minute window.
            var j = i
            while j > 0 &&
                  current.timestamp.timeIntervalSince(sorted[j - 1].timestamp) <= 900 {
                j -= 1
            }
            let window = sorted[j...i]
            guard let first = window.first, window.count > 1 else {
                labelled.append(current)
                continue
            }
            let dtMinutes = current.timestamp
                .timeIntervalSince(first.timestamp) / 60.0
            let slope = (current.value - first.value) / max(1, dtMinutes)
            let direction: TrendDirection
            switch slope {
            case _ where slope > 2.0:   direction = .risingFast
            case _ where slope > 0.5:   direction = .rising
            case _ where slope < -2.0:  direction = .fallingFast
            case _ where slope < -0.5:  direction = .falling
            default:                    direction = .stable
            }
            labelled.append(
                Reading(
                    id: current.id,
                    metricType: current.metricType,
                    value: current.value,
                    unit: current.unit,
                    timestamp: current.timestamp,
                    sourceSkillId: current.sourceSkillId,
                    confidence: current.confidence,
                    trendDirection: direction,
                    trendVelocity: slope
                )
            )
        }
        return labelled
    }
}

// MARK: - MealEvent

/// A scheduled meal the glucose generator should respond to. Emitted by
/// `FoodLogGenerator`; carried in a typed struct so we don't have to
/// couple generators together.
public struct MealEvent: Sendable, Hashable {
    public let time: Date
    public let carbs: Double        // grams
    public let calories: Double
    public let protein: Double
    public let fat: Double

    public init(
        time: Date,
        carbs: Double,
        calories: Double,
        protein: Double,
        fat: Double
    ) {
        self.time = time
        self.carbs = carbs
        self.calories = calories
        self.protein = protein
        self.fat = fat
    }
}
