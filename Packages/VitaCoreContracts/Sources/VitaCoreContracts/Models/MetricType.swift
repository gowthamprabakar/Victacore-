import Foundation

/// The set of health metrics tracked by VitaCore.
public enum MetricType: String, Codable, Sendable, Hashable, CaseIterable {
    case glucose
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case heartRate
    case heartRateVariability
    case spo2
    case steps
    case sleep
    case fluidIntake
    case weight
    case calories
    case carbs
    case protein
    case fat
    case inactivityDuration

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .glucose:                  return "Blood Glucose"
        case .bloodPressureSystolic:    return "Systolic BP"
        case .bloodPressureDiastolic:   return "Diastolic BP"
        case .heartRate:                return "Heart Rate"
        case .heartRateVariability:     return "HRV"
        case .spo2:                     return "SpO2"
        case .steps:                    return "Steps"
        case .sleep:                    return "Sleep"
        case .fluidIntake:              return "Fluid Intake"
        case .weight:                   return "Weight"
        case .calories:                 return "Calories"
        case .carbs:                    return "Carbohydrates"
        case .protein:                  return "Protein"
        case .fat:                      return "Fat"
        case .inactivityDuration:       return "Inactivity Duration"
        }
    }

    /// Standard unit of measurement.
    public var unit: String {
        switch self {
        case .glucose:                  return "mg/dL"
        case .bloodPressureSystolic:    return "mmHg"
        case .bloodPressureDiastolic:   return "mmHg"
        case .heartRate:                return "bpm"
        case .heartRateVariability:     return "ms"
        case .spo2:                     return "%"
        case .steps:                    return "steps"
        case .sleep:                    return "hr"
        case .fluidIntake:              return "mL"
        case .weight:                   return "kg"
        case .calories:                 return "kcal"
        case .carbs:                    return "g"
        case .protein:                  return "g"
        case .fat:                      return "g"
        case .inactivityDuration:       return "min"
        }
    }

    /// SF Symbol name representing this metric.
    public var icon: String {
        switch self {
        case .glucose:                  return "drop.fill"
        case .bloodPressureSystolic:    return "heart.fill"
        case .bloodPressureDiastolic:   return "heart.fill"
        case .heartRate:                return "waveform.path.ecg"
        case .heartRateVariability:     return "waveform.path.ecg.rectangle"
        case .spo2:                     return "lungs.fill"
        case .steps:                    return "figure.walk"
        case .sleep:                    return "moon.fill"
        case .fluidIntake:              return "cup.and.saucer.fill"
        case .weight:                   return "scalemass.fill"
        case .calories:                 return "flame.fill"
        case .carbs:                    return "leaf.fill"
        case .protein:                  return "circle.grid.2x2.fill"
        case .fat:                      return "drop.circle.fill"
        case .inactivityDuration:       return "timer"
        }
    }
}
