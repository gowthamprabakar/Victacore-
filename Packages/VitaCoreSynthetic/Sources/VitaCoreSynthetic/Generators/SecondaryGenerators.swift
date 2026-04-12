// SecondaryGenerators.swift
// VitaCoreSynthetic — Lighter-weight generators that support the glucose
// signal: meal schedule, heart rate, steps, sleep, blood pressure, and
// weight. Every generator is deterministic w.r.t. an inbound
// `SeededGenerator` and reads from a `TraitProfile`.
//
// These generators intentionally use simpler models than GlucoseGenerator
// because (a) they are not the primary signal for episode detection
// in Wave 1/3 and (b) we prefer code that is easy to tune by eye than a
// physiologically-perfect model. Realism can be layered in later as
// ThresholdEngine / HeartbeatEngine drive requirements.

import Foundation
import VitaCoreContracts

// MARK: - MealScheduleGenerator

/// Emits a realistic 3–5 meals/day schedule for the requested window.
/// Macro distributions are tuned so total daily calories land in a
/// persona-appropriate range.
public struct MealScheduleGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    /// Builds meal events across a set of calendar days. The result is
    /// used by `GlucoseGenerator` (meal excursions), `FoodLogGenerator`
    /// below (readings), and `EpisodeLabeler` (ground-truth events).
    public func generate(
        days: [Date],
        rng: inout SeededGenerator
    ) -> [MealEvent] {
        var meals: [MealEvent] = []
        let targetCals = targetCaloriesPerDay()

        for day in days {
            let mealCount = rng.nextInt(3, 4)
            // Fixed anchor hours with jitter.
            let anchorHours: [Double] = [7.5, 12.5, 19.0, 15.5]  // last = snack
            for i in 0..<mealCount {
                let jitter = rng.nextUniform(-0.5, 0.5)
                let hour = anchorHours[i] + jitter
                let time = day.addingTimeInterval(hour * 3600)
                let share = mealCount == 3 ? (i == 1 ? 0.4 : 0.3) : 0.25
                let cals = targetCals * share * rng.nextUniform(0.85, 1.15)
                // Macros (g): carbs 45%, protein 25%, fat 30% by energy
                let carbs = cals * 0.45 / 4.0
                let protein = cals * 0.25 / 4.0
                let fat = cals * 0.30 / 9.0
                meals.append(
                    MealEvent(
                        time: time,
                        carbs: carbs,
                        calories: cals,
                        protein: protein,
                        fat: fat
                    )
                )
            }
        }
        return meals.sorted { $0.time < $1.time }
    }

    /// Basal metabolic rate × activity factor, scaled by workout prob.
    private func targetCaloriesPerDay() -> Double {
        let bmr: Double = {
            // Mifflin–St Jeor, simplified.
            let base = 10 * traits.weightKg + 6.25 * traits.heightCm - 5 * Double(traits.age)
            return traits.biologicalSex == "female" ? base - 161 : base + 5
        }()
        let activityFactor = 1.3 + traits.workoutDayProbability * 0.4
        return bmr * activityFactor
    }
}

// MARK: - FoodLogGenerator

/// Converts a meal schedule into individual `Reading` records for
/// calories / carbs / protein / fat. One logical meal produces four
/// co-timed readings.
public struct FoodLogGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    public func generate(
        meals: [MealEvent]
    ) -> [Reading] {
        var readings: [Reading] = []
        readings.reserveCapacity(meals.count * 4)
        let source = "skill.foodManual"
        for meal in meals {
            readings.append(reading(.calories, meal.calories, at: meal.time, source: source))
            readings.append(reading(.carbs, meal.carbs, at: meal.time, source: source))
            readings.append(reading(.protein, meal.protein, at: meal.time, source: source))
            readings.append(reading(.fat, meal.fat, at: meal.time, source: source))
        }
        return readings
    }

    private func reading(_ metric: MetricType, _ value: Double, at time: Date, source: String) -> Reading {
        Reading(
            metricType: metric,
            value: value,
            unit: metric.unit,
            timestamp: time,
            sourceSkillId: source,
            confidence: 0.9,
            trendDirection: .stable
        )
    }
}

// MARK: - HeartRateGenerator

/// Heart rate with circadian baseline, activity coupling (workout
/// windows raise HR), and gaussian per-reading noise. HRV stream emits
/// a daily morning reading keyed to sleep quality.
public struct HeartRateGenerator {

    public let traits: TraitProfile
    public let workoutWindows: [DateInterval]

    public init(traits: TraitProfile, workoutWindows: [DateInterval]) {
        self.traits = traits
        self.workoutWindows = workoutWindows
    }

    /// Emits a reading every `samplingMinutes` minutes across the span.
    public func generate(
        from start: Date,
        to end: Date,
        samplingMinutes: Int = 15,
        rng: inout SeededGenerator
    ) -> [Reading] {
        var readings: [Reading] = []
        let step = TimeInterval(samplingMinutes * 60)
        var t = start
        while t < end {
            let value = hrAt(time: t, rng: &rng)
            readings.append(
                Reading(
                    metricType: .heartRate,
                    value: value,
                    unit: MetricType.heartRate.unit,
                    timestamp: t,
                    sourceSkillId: "skill.healthKitHR",
                    confidence: 0.95,
                    trendDirection: .stable
                )
            )
            t = t.addingTimeInterval(step)
        }
        return readings
    }

    private func hrAt(time: Date, rng: inout SeededGenerator) -> Double {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute], from: time)
        let hour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0

        // Circadian: low at 04:00, high around 16:00.
        let circadian = 4.0 * sin(2.0 * .pi * (hour - 4.0) / 24.0)
        var v = traits.heartRateResting + circadian

        // Workout coupling — triangular profile peaking at peak bpm.
        for window in workoutWindows {
            if window.contains(time) {
                let progress = time.timeIntervalSince(window.start) / window.duration
                let shape = sin(progress * .pi)
                v = traits.heartRateResting + shape * (traits.heartRateWorkoutPeak - traits.heartRateResting)
                break
            }
        }

        v += rng.nextGaussian(mean: 0, stdev: 3.0)
        return max(35, min(220, v))
    }
}

// MARK: - StepGenerator

/// Daily step totals with persona-specific mean, weekend dip, and
/// workout-day boost. Emits one `Reading` per day at 23:59.
public struct StepGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    public func generate(
        days: [Date],
        workoutDays: Set<Date>,
        rng: inout SeededGenerator
    ) -> [Reading] {
        let cal = Calendar(identifier: .gregorian)
        var readings: [Reading] = []
        for day in days {
            let weekday = cal.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            let base = Double(traits.stepsDailyTarget)
            var steps = base * rng.nextUniform(0.7, 1.15)
            if isWeekend { steps *= 0.85 }
            if workoutDays.contains(cal.startOfDay(for: day)) {
                steps *= rng.nextUniform(1.2, 1.5)
            }
            let t = cal.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
            readings.append(
                Reading(
                    metricType: .steps,
                    value: steps.rounded(),
                    unit: MetricType.steps.unit,
                    timestamp: t,
                    sourceSkillId: "skill.healthKitSteps",
                    confidence: 0.98,
                    trendDirection: .stable
                )
            )
        }
        return readings
    }
}

// MARK: - SleepGenerator

/// One sleep reading per night (hours slept). Duration draws from a
/// Gaussian around `traits.sleepTargetHours` with stdev 0.7.
public struct SleepGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    public func generate(days: [Date], rng: inout SeededGenerator) -> [Reading] {
        let cal = Calendar(identifier: .gregorian)
        var readings: [Reading] = []
        for day in days {
            let hours = max(3.0, min(12.0, rng.nextGaussian(mean: traits.sleepTargetHours, stdev: 0.7)))
            // Record against 08:00 of the morning after.
            let wake = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
            readings.append(
                Reading(
                    metricType: .sleep,
                    value: hours,
                    unit: MetricType.sleep.unit,
                    timestamp: wake,
                    sourceSkillId: "skill.healthKitSleep",
                    confidence: 0.9,
                    trendDirection: .stable
                )
            )
        }
        return readings
    }
}

// MARK: - BloodPressureGenerator

/// Spot BP measurements — morning and evening, persona-gated probability
/// of elevated readings. Emits two `Reading` values per sample (systolic
/// + diastolic).
public struct BloodPressureGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    public func generate(days: [Date], rng: inout SeededGenerator) -> [Reading] {
        let cal = Calendar(identifier: .gregorian)
        var readings: [Reading] = []
        for day in days {
            // 80% chance of a morning reading, 60% of an evening reading.
            if rng.nextBernoulli(0.8) {
                let t = cal.date(bySettingHour: 7, minute: 30, second: 0, of: day) ?? day
                readings.append(contentsOf: sample(at: t, rng: &rng))
            }
            if rng.nextBernoulli(0.6) {
                let t = cal.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day
                readings.append(contentsOf: sample(at: t, rng: &rng))
            }
        }
        return readings
    }

    private func sample(at time: Date, rng: inout SeededGenerator) -> [Reading] {
        let elevated = rng.nextBernoulli(traits.bpElevatedProbability)
        let sys = traits.bpSystolicMean
            + (elevated ? rng.nextUniform(15, 35) : 0)
            + rng.nextGaussian(mean: 0, stdev: 5)
        let dia = traits.bpDiastolicMean
            + (elevated ? rng.nextUniform(8, 18) : 0)
            + rng.nextGaussian(mean: 0, stdev: 4)
        let source = "skill.bloodPressureManual"
        return [
            Reading(
                metricType: .bloodPressureSystolic,
                value: sys.rounded(),
                unit: MetricType.bloodPressureSystolic.unit,
                timestamp: time,
                sourceSkillId: source,
                confidence: 0.95
            ),
            Reading(
                metricType: .bloodPressureDiastolic,
                value: dia.rounded(),
                unit: MetricType.bloodPressureDiastolic.unit,
                timestamp: time,
                sourceSkillId: source,
                confidence: 0.95
            )
        ]
    }
}

// MARK: - WeightGenerator

/// Weekly weigh-ins with small per-day noise around a slow trend line.
public struct WeightGenerator {

    public let traits: TraitProfile

    public init(traits: TraitProfile) {
        self.traits = traits
    }

    public func generate(days: [Date], rng: inout SeededGenerator) -> [Reading] {
        let cal = Calendar(identifier: .gregorian)
        var readings: [Reading] = []
        let startWeight = traits.weightKg
        for (idx, day) in days.enumerated() {
            // Sample once a week on Sundays.
            let weekday = cal.component(.weekday, from: day)
            guard weekday == 1 else { continue }
            let trend = -0.02 * Double(idx / 7)   // gentle slow drop
            let noise = rng.nextGaussian(mean: 0, stdev: 0.35)
            let value = startWeight + trend + noise
            let t = cal.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day
            readings.append(
                Reading(
                    metricType: .weight,
                    value: value,
                    unit: MetricType.weight.unit,
                    timestamp: t,
                    sourceSkillId: "skill.weightManual",
                    confidence: 0.98,
                    trendDirection: .stable
                )
            )
        }
        return readings
    }
}
