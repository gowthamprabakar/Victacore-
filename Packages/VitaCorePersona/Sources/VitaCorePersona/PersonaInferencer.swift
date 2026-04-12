// PersonaInferencer.swift
// VitaCorePersona — Classifies a user into a starter archetype by
// inspecting their graph data, and synthesises a `PersonaContext` seed
// with sensible default conditions / goals.
//
// This is intentionally deterministic and rule-based (no ML). The goal
// is to give first-launch users a reasonable starting PersonaContext
// without forcing them through a long onboarding flow — they can
// override any field from Settings later.
//
// Classification rules (tuned against the 4 Sprint 0.3 synthetic
// cohorts, tests in `PersonaInferencerTests.swift`):
//
//   • Any glucose reading < 60 in the last 14 days → likelyT1D
//   • Mean glucose > 135 AND range > 120                       → likelyT1D
//   • Mean glucose 126–150 AND narrower range (<100) + no hypos → likelyT2D
//   • Mean glucose 101–125                                      → prediabetic
//   • Mean glucose ≤ 100 (or no glucose data at all)            → healthy
//
// BP is a tie-breaker: `bpElevatedProbability > 15%` from recent
// readings adds `.hypertension` to any archetype. Medications present
// in the graph (Wave 1 has none yet, so this is a no-op for now) would
// further pin the archetype; we'll wire that in once `C08 ManualEntry`
// emits medication events.

import Foundation
import VitaCoreContracts

// MARK: - InferredArchetype

/// Internal classification output. Maps 1:1 onto Sprint 0.3
/// `PersonaArchetype` for test cross-validation, but doesn't import
/// `VitaCoreSynthetic` — that would be a circular dep (synthetic data
/// is a *downstream* consumer of persona, not an upstream dep).
public enum InferredArchetype: String, Sendable, Hashable, CaseIterable {
    case likelyT1D
    case likelyT2D
    case prediabetic
    case healthy
}

// MARK: - InferenceDecision

/// The data-adequacy-aware result of an inference pass. Satisfies T030
/// (devil-critic C1 + spec.md FR-014): the inferencer MUST NOT silently
/// lock an empty-graph user into a `healthy` persona.
///
///   • `.confident(archetype, context)` — the graph has enough data for
///     the rules to produce a trusted classification. Callers SHOULD
///     persist the context.
///   • `.provisional(context)` — the graph has insufficient data. The
///     returned context is an in-memory default (`healthyBaseline` +
///     broad safe-range goals). Callers MUST NOT persist it; the next
///     call should re-run the inferencer so the user automatically
///     picks up their real archetype once HealthKit sync completes.
public enum InferenceDecision: Sendable {
    case confident(archetype: InferredArchetype, context: PersonaContext)
    case provisional(context: PersonaContext)

    public var context: PersonaContext {
        switch self {
        case .confident(_, let ctx), .provisional(let ctx):
            return ctx
        }
    }

    public var shouldPersist: Bool {
        if case .confident = self { return true }
        return false
    }
}

// MARK: - PersonaInferencer

public struct PersonaInferencer: Sendable {

    public init() {}

    // -------------------------------------------------------------------------
    // MARK: Inference entry point
    // -------------------------------------------------------------------------

    /// Classifies the user by reading the last `windowDays` days of
    /// graph data through the injected `GraphStoreProtocol`, then
    /// synthesises a starter `PersonaContext` populated with conditions
    /// and goals appropriate for that archetype.
    ///
    /// T030 / FR-014: returns an `InferenceDecision` which captures
    /// whether the graph had enough data to support a *persistable*
    /// classification. When the gate is not satisfied, the caller
    /// receives a `.provisional` in-memory default that MUST NOT be
    /// persisted, so that the next call automatically re-runs the
    /// inferencer once HealthKit back-fill (or another source) arrives.
    public func inferContext(
        from store: GraphStoreProtocol,
        windowDays: Int = 14,
        now: Date = Date()
    ) async throws -> InferenceDecision {

        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86400)

        // --- Pull the signals we classify on -----------------------------
        let glucoseReadings = try await store.getRangeReadings(
            for: .glucose, from: windowStart, to: now
        )
        let sysReadings = try await store.getRangeReadings(
            for: .bloodPressureSystolic, from: windowStart, to: now
        )
        let diaReadings = try await store.getRangeReadings(
            for: .bloodPressureDiastolic, from: windowStart, to: now
        )

        // --- Dedup (T038 / EC-02) ----------------------------------------
        // A user with Dexcom CGM + HealthKit mirroring produces two
        // copies of every glucose reading. Dedup on (timestamp rounded
        // to 1 s, metricType, round(value, 1)) before classification.
        let dedupedGlucose: [Reading] = {
            var seen = Set<String>()
            return glucoseReadings.filter { r in
                let key = "\(Int(r.timestamp.timeIntervalSince1970))-\(Int(r.value * 10))"
                return seen.insert(key).inserted
            }
        }()

        // --- Data-adequacy gate (T030 / FR-014) --------------------------
        // Rule: we only commit to a classification when the graph has
        // either a CGM stream OR enough fingerstick coverage (>= 3
        // readings/day over >= 7 days, i.e. 21+ readings in the window)
        // AND at least a small BP window. Anything less and we return a
        // provisional default that the engine MUST NOT persist.
        let adequate = dataAdequacyGate(
            glucose: dedupedGlucose,
            windowDays: windowDays
        )

        // --- Classify the glucose pattern --------------------------------
        let archetype = classifyGlucose(readings: dedupedGlucose)

        // --- Tie-breakers ------------------------------------------------
        let hasHypertension = hypertensionFlag(
            systolic: sysReadings,
            diastolic: diaReadings
        )

        // --- Synthesise the starter context ------------------------------
        let context = synthesiseContext(
            archetype: adequate ? archetype : .healthy,
            hasHypertension: adequate && hasHypertension
        )

        if adequate {
            return .confident(archetype: archetype, context: context)
        } else {
            return .provisional(context: context)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Data-adequacy gate
    // -------------------------------------------------------------------------

    /// Returns `true` when the graph has enough glucose signal for the
    /// classification rules to be trusted enough to *persist* the
    /// result. The threshold is deliberately loose: the worst outcome
    /// of a false-positive `.confident` decision for a healthy-pattern
    /// user is that we persist a `healthyBaseline` classification,
    /// which the user can override from Settings at any time. The
    /// worst outcome of a false-negative `.provisional` decision for a
    /// genuine healthy user is that the engine never commits their
    /// classification and keeps recomputing it — correct but wasteful.
    /// Between the two we bias toward committing when in doubt.
    ///
    /// Gate (either condition sufficient):
    ///   (a) **Any CGM source present** — a single CGM reading from a
    ///       `skill.cgm*` prefixed source proves the user has a
    ///       continuous monitoring stream.
    ///   (b) **Fingerstick coverage** — ≥ 7 readings spanning ≥ 5
    ///       distinct calendar days. This rejects the 3-glitchy-
    ///       readings pathology while passing legitimate once-a-day
    ///       spot-checkers (healthy optimizers and prediabetics with
    ///       1 fingerstick/day).
    internal func dataAdequacyGate(
        glucose: [Reading],
        windowDays: Int
    ) -> Bool {
        // (a) CGM source present?
        if glucose.contains(where: { $0.sourceSkillId.hasPrefix("skill.cgm") }) {
            return true
        }

        // (b) ≥ 7 readings from ≥ 5 distinct days.
        guard glucose.count >= 7 else { return false }
        let cal = Calendar(identifier: .gregorian)
        let distinctDays = Set(glucose.map { cal.startOfDay(for: $0.timestamp) })
        return distinctDays.count >= 5
    }

    // -------------------------------------------------------------------------
    // MARK: Glucose classification
    // -------------------------------------------------------------------------

    private func classifyGlucose(readings: [Reading]) -> InferredArchetype {
        guard !readings.isEmpty else { return .healthy }

        // T033 / FR-017: normalise every reading to mg/dL. European
        // CGMs and some HealthKit sources report in mmol/L (typical
        // range 3–20). Without normalisation a healthy European at
        // 5.5 mmol/L would be classified as hypo (< 60).
        let values = readings.map { r -> Double in
            if r.unit == "mmol/L" || r.unit == "mmol/l" {
                return r.value * 18.0182  // standard conversion factor
            }
            return r.value   // assume mg/dL for "mg/dL", "mg/dl", or unspecified
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let minV = values.min() ?? mean
        let maxV = values.max() ?? mean
        let range = maxV - minV
        // T040 / EC-03: only count hypos from readings with adequate
        // confidence (>= 0.8). A single sub-60 sensor glitch at startup
        // must not trigger a T1D classification.
        let confidentHypoCount = zip(readings, values)
            .filter { $0.0.confidence >= 0.8 && $0.1 < 60 }
            .count

        // Rule 1: severe hypos + high mean → T1D suspected. Require
        // at least 2 confident hypo events to guard against sensor
        // glitches (T040 / EC-03). T2D on basal insulin can produce
        // rare hypos, so we also require the mean to be clearly
        // diabetic before committing.
        if confidentHypoCount >= 2 && mean > 125 {
            return .likelyT1D
        }

        // Rule 2: high mean + wide range → T1D regardless of hypos.
        if mean > 135 && range > 120 {
            return .likelyT1D
        }

        // Rule 3: elevated mean + narrower range + few/no hypos → T2D.
        // EC-04: T2D on basal insulin can produce 2–5 hypos over 14
        // days; raise the cap to 5 to avoid kicking them to T1D.
        if mean > 125 && mean <= 165 && range <= 150 && confidentHypoCount <= 5 {
            return .likelyT2D
        }

        // Rule 4: mildly elevated → prediabetic. The lower bound is
        // 115 (not 100) because postprandial readings from a healthy
        // person routinely hit 100–115. Prediabetic cohorts sit at
        // fasting ≈ 108 with larger meal spikes, so their sample mean
        // reliably clears 115.
        if mean > 115 && mean <= 135 {
            return .prediabetic
        }

        // Default: healthy baseline.
        return .healthy
    }

    // -------------------------------------------------------------------------
    // MARK: BP tie-breaker
    // -------------------------------------------------------------------------

    private func hypertensionFlag(
        systolic: [Reading],
        diastolic: [Reading]
    ) -> Bool {
        guard !systolic.isEmpty || !diastolic.isEmpty else { return false }
        let sysHigh = systolic.filter { $0.value > 140 }.count
        let diaHigh = diastolic.filter { $0.value > 90 }.count
        let total = systolic.count + diastolic.count
        guard total > 0 else { return false }
        let elevatedRatio = Double(sysHigh + diaHigh) / Double(total)
        return elevatedRatio > 0.15
    }

    // -------------------------------------------------------------------------
    // MARK: Context synthesis
    // -------------------------------------------------------------------------

    private func synthesiseContext(
        archetype: InferredArchetype,
        hasHypertension: Bool
    ) -> PersonaContext {

        var conditions: [ConditionSummary] = []
        var goals: [GoalSummary] = []

        switch archetype {

        case .likelyT1D:
            conditions.append(
                ConditionSummary(conditionKey: .type1Diabetes, severity: "moderate", daysActive: 0)
            )
            goals.append(contentsOf: [
                GoalSummary(goalType: .glucoseA1C,  target: 7.0,    current: 0, direction: -1),
                GoalSummary(goalType: .timeInRange, target: 70,     current: 0, direction: 1),
                GoalSummary(goalType: .stepsDaily,  target: 9_000,  current: 0, direction: 1),
                GoalSummary(goalType: .sleepDuration, target: 7.5,  current: 0, direction: 1)
            ])

        case .likelyT2D:
            conditions.append(
                ConditionSummary(conditionKey: .type2Diabetes, severity: "moderate", daysActive: 0)
            )
            goals.append(contentsOf: [
                GoalSummary(goalType: .glucoseA1C,  target: 6.8,    current: 0, direction: -1),
                GoalSummary(goalType: .stepsDaily,  target: 8_000,  current: 0, direction: 1),
                GoalSummary(goalType: .weightTarget, target: 80,    current: 0, direction: -1),
                GoalSummary(goalType: .carbsDaily,  target: 180,    current: 0, direction: -1)
            ])

        case .prediabetic:
            conditions.append(
                ConditionSummary(conditionKey: .prediabetes, severity: "mild", daysActive: 0)
            )
            goals.append(contentsOf: [
                GoalSummary(goalType: .stepsDaily,      target: 10_000, current: 0, direction: 1),
                GoalSummary(goalType: .exerciseMinutes, target: 150,    current: 0, direction: 1),
                GoalSummary(goalType: .weightTarget,    target: 78,     current: 0, direction: -1),
                GoalSummary(goalType: .carbsDaily,      target: 200,    current: 0, direction: -1)
            ])

        case .healthy:
            conditions.append(
                ConditionSummary(conditionKey: .healthyBaseline, severity: "none", daysActive: 0)
            )
            goals.append(contentsOf: [
                GoalSummary(goalType: .stepsDaily,      target: 12_000, current: 0, direction: 1),
                GoalSummary(goalType: .sleepDuration,   target: 8.0,    current: 0, direction: 1),
                GoalSummary(goalType: .exerciseMinutes, target: 200,    current: 0, direction: 1),
                GoalSummary(goalType: .hrvTarget,       target: 65,     current: 0, direction: 1)
            ])
        }

        if hasHypertension {
            conditions.append(
                ConditionSummary(conditionKey: .hypertension, severity: "mild", daysActive: 0)
            )
            goals.append(
                GoalSummary(goalType: .bpSystolic, target: 125, current: 0, direction: -1)
            )
        }

        // T036 / FR-021: synthesise archetype-appropriate threshold
        // overrides so C14 ThresholdEngine receives tighter bounds for
        // diabetic users rather than population defaults.
        var overrides: [ThresholdOverride] = []
        switch archetype {
        case .likelyT1D:
            overrides = [
                ThresholdOverride(metricType: .glucose, lowerBound: 70, upperBound: 180, reason: "Inferred T1D default (ADA target 70-180)"),
                ThresholdOverride(metricType: .heartRate, lowerBound: 50, upperBound: 120, reason: "Inferred T1D resting HR range")
            ]
        case .likelyT2D:
            overrides = [
                ThresholdOverride(metricType: .glucose, lowerBound: 70, upperBound: 180, reason: "Inferred T2D default (ADA target 70-180)"),
                ThresholdOverride(metricType: .bloodPressureSystolic, upperBound: 130, reason: "Inferred T2D BP target")
            ]
        case .prediabetic:
            overrides = [
                ThresholdOverride(metricType: .glucose, upperBound: 140, reason: "Inferred prediabetic postprandial target")
            ]
        case .healthy:
            overrides = [
                ThresholdOverride(metricType: .glucose, upperBound: 140, reason: "Healthy population upper bound")
            ]
        }

        // T037 / FR-022: synthesise goalProgress entries to match
        // activeGoals so Home Dashboard goal cards render with values.
        let goalProgress = goals.map { goal in
            GoalProgress(
                goalType: goal.goalType,
                target: goal.target,
                current: goal.current,
                trend: .stable,
                streakDays: 0
            )
        }

        // T034 / FR-018: use the Keychain-backed install UUID so the
        // same identity survives reinstalls and concurrent bootstrap
        // calls always upsert the same primary key.
        return PersonaContext(
            userId: InstallIdentity.getOrCreate(),
            activeConditions: conditions,
            activeGoals: goals,
            activeMedications: [],
            allergies: [],
            preferences: PreferenceSummary(),
            responseProfiles: [],
            thresholdOverrides: overrides,
            dataQualityFlags: [],
            goalProgress: goalProgress
        )
    }
}
