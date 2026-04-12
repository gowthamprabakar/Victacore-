// PersonaArchetype.swift
// VitaCoreSynthetic — Physiological prior profiles for the 4 locked
// synthetic personas. Every generator reads traits from this file; adding
// a new persona is a matter of defining a new case and a `TraitProfile`.
//
// Traits are clinically-motivated but intentionally simplified — the goal
// is a dataset that stress-tests our threshold engine and agents with
// realistic *patterns*, not to be a medical-grade simulation. Values are
// drawn from published population distributions where available and the
// VitaCore ideology doc otherwise.

import Foundation

// MARK: - PersonaArchetype

/// The four locked synthetic personas. Anything past Wave 1.2 consumes
/// cohorts built from these archetypes.
public enum PersonaArchetype: String, CaseIterable, Codable, Sendable, Hashable {
    /// Type 1 diabetic on CGM + insulin pump. Highest signal variance —
    /// stress-tests hypoglycemia detection, dawn phenomenon, meal
    /// excursions, exercise-induced drops, and sensor noise.
    case t1dPump

    /// Type 2 diabetic on oral metformin ± basal insulin. Flatter glucose
    /// curves, post-meal peaks, morning elevation, comorbid hypertension,
    /// medication-adherence edge cases.
    case t2dOralOrBasal

    /// Prediabetic / metabolic syndrome. Normal most of the time with
    /// stress-induced excursions and weekend drift. Tests "mostly healthy
    /// but not quite" classification.
    case prediabetic

    /// Healthy optimizer on Apple Watch, no medications. Tight
    /// physiological bands, subtle circadian rhythms, workout responses.
    /// Exercises the app's behaviour on clean data.
    case healthyOptimizer

    public var displayName: String {
        switch self {
        case .t1dPump:          return "T1D on Pump + CGM"
        case .t2dOralOrBasal:   return "T2D on Oral ± Basal"
        case .prediabetic:      return "Prediabetic"
        case .healthyOptimizer: return "Healthy Optimizer"
        }
    }
}

// MARK: - TraitProfile

/// A bundle of physiological priors driving every generator. All values
/// are population-level distribution parameters (not per-reading values)
/// so a single profile can power a full 30–90 day cohort.
public struct TraitProfile: Sendable, Hashable {

    // MARK: Identity

    public let archetype: PersonaArchetype
    public let age: Int                 // years
    public let heightCm: Double
    public let weightKg: Double
    public let biologicalSex: String    // "male" | "female" — simplified

    // MARK: Glucose

    /// Fasting glucose baseline (mg/dL).
    public let glucoseFastingMean: Double
    /// Daily stdev of glucose around baseline.
    public let glucoseStdev: Double
    /// Amplitude of post-meal excursion (mg/dL peak above baseline).
    public let glucoseMealSpikeAmplitude: Double
    /// Strength of dawn phenomenon (mg/dL above baseline at 05:00–08:00).
    public let glucoseDawnAmplitude: Double
    /// Probability that any given reading triggers a hypoglycemic episode
    /// (value < 70 mg/dL). Only meaningful for T1D/T2D-on-insulin.
    public let glucoseHypoEventProbability: Double
    /// Sensor measurement noise (mg/dL, 1-sigma).
    public let glucoseSensorNoise: Double
    /// CGM readings per hour. 12 = Dexcom G7 (5-minute sampling), 0 = fingerstick.
    public let cgmSamplesPerHour: Int
    /// Manual fingerstick checks per day (on top of any CGM stream).
    public let fingerstickChecksPerDay: Int

    // MARK: Heart rate

    /// Resting heart rate (bpm).
    public let heartRateResting: Double
    /// Peak heart rate during a typical workout.
    public let heartRateWorkoutPeak: Double
    /// Heart rate variability baseline (ms, RMSSD).
    public let hrvBaseline: Double

    // MARK: Blood pressure (spot measurements)

    public let bpSystolicMean: Double
    public let bpDiastolicMean: Double
    /// Probability of a high-BP reading (>140/90).
    public let bpElevatedProbability: Double

    // MARK: Sleep

    /// Target hours per night.
    public let sleepTargetHours: Double
    /// Typical bedtime hour (24h, 0..24).
    public let sleepBedtimeHour: Double

    // MARK: Activity

    /// Target daily step count.
    public let stepsDailyTarget: Int
    /// Probability that any given day is a dedicated workout day.
    public let workoutDayProbability: Double

    // MARK: Medication

    /// Number of distinct medications scheduled daily.
    public let medicationCountDaily: Int
    /// Adherence rate (0..1). 0.85–0.95 is typical in the literature.
    public let medicationAdherence: Double
}

// MARK: - Trait profile table

public extension PersonaArchetype {

    /// Returns the default trait profile for this archetype. Cohort
    /// building uses this directly; tests can inject custom profiles if
    /// they need to exercise a specific edge case.
    var defaultTraits: TraitProfile {
        switch self {

        // ---- T1D on CGM + pump ---------------------------------------
        case .t1dPump:
            return TraitProfile(
                archetype: self,
                age: 34,
                heightCm: 172,
                weightKg: 68,
                biologicalSex: "female",
                glucoseFastingMean: 130,
                glucoseStdev: 42,
                glucoseMealSpikeAmplitude: 85,
                glucoseDawnAmplitude: 30,
                glucoseHypoEventProbability: 0.008,  // ~2 hypos/day possible
                glucoseSensorNoise: 8,
                cgmSamplesPerHour: 12,                // Dexcom G7 5-min
                fingerstickChecksPerDay: 2,
                heartRateResting: 68,
                heartRateWorkoutPeak: 165,
                hrvBaseline: 42,
                bpSystolicMean: 118,
                bpDiastolicMean: 76,
                bpElevatedProbability: 0.04,
                sleepTargetHours: 7.5,
                sleepBedtimeHour: 22.75,
                stepsDailyTarget: 9000,
                workoutDayProbability: 0.5,
                medicationCountDaily: 1,              // insulin pump (treated as one med)
                medicationAdherence: 0.97
            )

        // ---- T2D on oral ± basal -------------------------------------
        case .t2dOralOrBasal:
            return TraitProfile(
                archetype: self,
                age: 58,
                heightCm: 168,
                weightKg: 88,
                biologicalSex: "male",
                glucoseFastingMean: 145,
                glucoseStdev: 28,
                glucoseMealSpikeAmplitude: 60,
                glucoseDawnAmplitude: 22,
                glucoseHypoEventProbability: 0.002,  // rare on orals
                glucoseSensorNoise: 6,
                cgmSamplesPerHour: 0,                 // fingerstick only
                fingerstickChecksPerDay: 3,
                heartRateResting: 78,
                heartRateWorkoutPeak: 140,
                hrvBaseline: 28,
                bpSystolicMean: 138,
                bpDiastolicMean: 88,
                bpElevatedProbability: 0.22,
                sleepTargetHours: 6.5,
                sleepBedtimeHour: 23.5,
                stepsDailyTarget: 6000,
                workoutDayProbability: 0.25,
                medicationCountDaily: 3,              // metformin + statin + ACE inhibitor
                medicationAdherence: 0.88
            )

        // ---- Prediabetic / metabolic syndrome ------------------------
        case .prediabetic:
            return TraitProfile(
                archetype: self,
                age: 45,
                heightCm: 175,
                weightKg: 84,
                biologicalSex: "male",
                glucoseFastingMean: 108,
                glucoseStdev: 18,
                glucoseMealSpikeAmplitude: 45,
                glucoseDawnAmplitude: 12,
                glucoseHypoEventProbability: 0.0001, // effectively none
                glucoseSensorNoise: 5,
                cgmSamplesPerHour: 0,
                fingerstickChecksPerDay: 1,
                heartRateResting: 72,
                heartRateWorkoutPeak: 155,
                hrvBaseline: 38,
                bpSystolicMean: 128,
                bpDiastolicMean: 82,
                bpElevatedProbability: 0.10,
                sleepTargetHours: 7.0,
                sleepBedtimeHour: 23.25,
                stepsDailyTarget: 7500,
                workoutDayProbability: 0.35,
                medicationCountDaily: 0,
                medicationAdherence: 1.0
            )

        // ---- Healthy optimizer ---------------------------------------
        case .healthyOptimizer:
            return TraitProfile(
                archetype: self,
                age: 29,
                heightCm: 180,
                weightKg: 75,
                biologicalSex: "male",
                glucoseFastingMean: 92,
                glucoseStdev: 12,
                glucoseMealSpikeAmplitude: 30,
                glucoseDawnAmplitude: 6,
                glucoseHypoEventProbability: 0.0,
                glucoseSensorNoise: 4,
                cgmSamplesPerHour: 0,
                fingerstickChecksPerDay: 1,
                heartRateResting: 55,
                heartRateWorkoutPeak: 180,
                hrvBaseline: 65,
                bpSystolicMean: 115,
                bpDiastolicMean: 72,
                bpElevatedProbability: 0.01,
                sleepTargetHours: 8.0,
                sleepBedtimeHour: 22.5,
                stepsDailyTarget: 12000,
                workoutDayProbability: 0.7,
                medicationCountDaily: 0,
                medicationAdherence: 1.0
            )
        }
    }
}
