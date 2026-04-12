// ConditionProfiles.swift
// VitaCoreThreshold — Static threshold profiles for the 5 MVP conditions.
//
// Each profile defines metric bands for the metrics most relevant to
// that condition. Bands are sourced from ADA Standards of Care 2024,
// AHA/ACC Blood Pressure Guidelines 2017, and ESC Heart Failure
// Guidelines 2023. They are DEFAULTS — the priority stack resolver
// can tighten them, and clinician overrides can override them entirely.
//
// Band semantics (per MetricThreshold in VitaCoreContracts):
//   safe:     ideal operating range
//   watch:    warrants increased monitoring (user notified once)
//   alert:    requires user action (meal, medication, rest)
//   critical: triggers emergency guidance (hypo protocol, seek care)

import Foundation
import VitaCoreContracts

// MARK: - ConditionProfile

/// A named collection of metric thresholds that apply when a condition
/// is active on the user's persona. Each threshold carries a `priority`
/// field so the resolver can select the tighter of two conflicting
/// thresholds.
public struct ConditionProfile: Sendable, Hashable {
    public let conditionKey: ConditionKey
    public let thresholds: [MetricThreshold]
    /// Base priority for all thresholds in this profile. Individual
    /// thresholds may raise their own `priority` above this.
    public let basePriority: Int
}

// MARK: - Profile library

public enum ConditionProfiles {

    // MARK: - Healthy Baseline (population defaults)

    public static let healthyBaseline = ConditionProfile(
        conditionKey: .healthyBaseline,
        thresholds: [
            MetricThreshold(
                metricType: .glucose,
                safeBand:     70...140,
                watchBand:    55...200,
                alertBand:    40...250,
                criticalBand: 0...400,
                priority: 0
            ),
            MetricThreshold(
                metricType: .heartRate,
                safeBand:     50...100,
                watchBand:    40...120,
                alertBand:    35...140,
                criticalBand: 0...220,
                priority: 0
            ),
            MetricThreshold(
                metricType: .bloodPressureSystolic,
                safeBand:     90...120,
                watchBand:    80...130,
                alertBand:    70...140,
                criticalBand: 0...200,
                priority: 0
            ),
            MetricThreshold(
                metricType: .bloodPressureDiastolic,
                safeBand:     60...80,
                watchBand:    50...85,
                alertBand:    40...90,
                criticalBand: 0...130,
                priority: 0
            ),
            MetricThreshold(
                metricType: .spo2,
                safeBand:     95...100,
                watchBand:    92...100,
                alertBand:    88...100,
                criticalBand: 0...100,
                priority: 0
            )
        ],
        basePriority: 0
    )

    // MARK: - Type 1 Diabetes

    public static let type1Diabetes = ConditionProfile(
        conditionKey: .type1Diabetes,
        thresholds: [
            MetricThreshold(
                metricType: .glucose,
                safeBand:     70...180,     // ADA time-in-range target
                watchBand:    54...250,     // sub-54 is level 2 hypo
                alertBand:    40...300,
                criticalBand: 0...400,
                priority: 3                // condition-level, above population
            ),
            MetricThreshold(
                metricType: .heartRate,
                safeBand:     50...120,
                watchBand:    40...130,
                alertBand:    35...150,
                criticalBand: 0...220,
                priority: 2
            )
        ],
        basePriority: 3
    )

    // MARK: - Type 2 Diabetes

    public static let type2Diabetes = ConditionProfile(
        conditionKey: .type2Diabetes,
        thresholds: [
            MetricThreshold(
                metricType: .glucose,
                safeBand:     70...180,     // ADA target same as T1D
                watchBand:    60...200,
                alertBand:    50...250,
                criticalBand: 0...400,
                priority: 3
            ),
            MetricThreshold(
                metricType: .bloodPressureSystolic,
                safeBand:     90...130,     // ADA: <130 for diabetics
                watchBand:    80...140,
                alertBand:    70...150,
                criticalBand: 0...200,
                priority: 3
            )
        ],
        basePriority: 3
    )

    // MARK: - Prediabetes

    public static let prediabetes = ConditionProfile(
        conditionKey: .prediabetes,
        thresholds: [
            MetricThreshold(
                metricType: .glucose,
                safeBand:     70...140,     // postprandial target
                watchBand:    60...160,
                alertBand:    50...200,
                criticalBand: 0...350,
                priority: 2
            )
        ],
        basePriority: 2
    )

    // MARK: - Hypertension

    public static let hypertension = ConditionProfile(
        conditionKey: .hypertension,
        thresholds: [
            MetricThreshold(
                metricType: .bloodPressureSystolic,
                safeBand:     90...130,     // ACC/AHA Stage 1 target
                watchBand:    80...140,
                alertBand:    70...160,
                criticalBand: 0...200,
                priority: 3
            ),
            MetricThreshold(
                metricType: .bloodPressureDiastolic,
                safeBand:     60...80,
                watchBand:    50...90,
                alertBand:    40...100,
                criticalBand: 0...130,
                priority: 3
            ),
            MetricThreshold(
                metricType: .heartRate,
                safeBand:     50...90,      // tighter resting HR for HTN
                watchBand:    40...100,
                alertBand:    35...120,
                criticalBand: 0...220,
                priority: 2
            )
        ],
        basePriority: 3
    )

    // MARK: - Lookup

    /// Returns the condition profile for a given key, or nil for
    /// conditions not yet in the MVP profile library.
    public static func profile(for key: ConditionKey) -> ConditionProfile? {
        switch key {
        case .healthyBaseline: return healthyBaseline
        case .type1Diabetes:   return type1Diabetes
        case .type2Diabetes:   return type2Diabetes
        case .prediabetes:     return prediabetes
        case .hypertension:    return hypertension
        default:               return nil
        }
    }
}
