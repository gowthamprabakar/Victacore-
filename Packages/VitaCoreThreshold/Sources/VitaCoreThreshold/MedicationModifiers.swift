// MedicationModifiers.swift
// VitaCoreThreshold — Medication-driven threshold adjustments.
//
// Certain medication classes alter the physiological meaning of a
// metric value. For example, beta-blockers lower resting heart rate,
// so a HR of 55 on a beta-blocker is normal, not bradycardic. These
// modifiers are applied AFTER condition-profile resolution but BEFORE
// clinician overrides (priority level 4 in the 7-level stack).

import Foundation
import VitaCoreContracts

// MARK: - MedicationModifier

public struct MedicationModifier: Sendable, Hashable {
    public let medicationClass: MedicationClass
    public let metricType: MetricType
    /// Shift to apply to the safe band's lower bound (negative = lower).
    public let safeLowerShift: Double
    /// Shift to apply to the safe band's upper bound (negative = lower).
    public let safeUpperShift: Double
    /// Priority for this modifier in the resolution stack.
    public let priority: Int
}

// MARK: - Modifier library

public enum MedicationModifiers {

    /// Beta-blockers (metoprolol, atenolol, propranolol) lower resting
    /// HR by ~10-25%. Safe HR band shifts down.
    public static let betaBlocker = MedicationModifier(
        medicationClass: .betaBlocker,
        metricType: .heartRate,
        safeLowerShift: -10,   // allow resting HR down to 40
        safeUpperShift: -10,   // upper safe HR also shifts down
        priority: 4
    )

    /// Insulin increases hypoglycemia risk. Tighten the glucose "watch"
    /// lower bound so sub-80 readings get flagged earlier.
    public static let insulin = MedicationModifier(
        medicationClass: .insulin,
        metricType: .glucose,
        safeLowerShift: 5,     // raise lower safe from 70 → 75
        safeUpperShift: 0,
        priority: 4
    )

    /// ACE inhibitors target lower BP. Shift the systolic safe upper
    /// bound down to 125.
    public static let aceInhibitor = MedicationModifier(
        medicationClass: .aceInhibitor,
        metricType: .bloodPressureSystolic,
        safeLowerShift: 0,
        safeUpperShift: -5,    // tighten from 130 → 125
        priority: 4
    )

    /// Returns all applicable modifiers for a given medication class.
    public static func modifiers(for med: MedicationClass) -> [MedicationModifier] {
        switch med {
        case .betaBlocker:   return [betaBlocker]
        case .insulin:       return [insulin]
        case .aceInhibitor:  return [aceInhibitor]
        default:             return []
        }
    }
}
