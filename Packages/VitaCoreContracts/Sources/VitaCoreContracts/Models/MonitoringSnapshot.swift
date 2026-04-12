import Foundation

/// Data quality level for a monitoring snapshot.
public enum DataQuality: String, Codable, Sendable, Hashable, CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case insufficient

    public var score: Double {
        switch self {
        case .excellent:    return 1.0
        case .good:         return 0.8
        case .fair:         return 0.6
        case .poor:         return 0.4
        case .insufficient: return 0.0
        }
    }
}

/// A point-in-time snapshot of all current metric readings used as inference context.
public struct MonitoringSnapshot: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID

    // MARK: Glycaemia
    public let glucose: Reading?
    public let glucoseTrend: TrendDirection?

    // MARK: Cardiovascular
    public let bloodPressureSystolic: Reading?
    public let bloodPressureDiastolic: Reading?
    public let heartRate: Reading?
    public let heartRateVariability: Reading?
    public let spo2: Reading?

    // MARK: Activity
    public let steps: Reading?
    public let inactivityDuration: Reading?

    // MARK: Recovery
    public let sleep: Reading?

    // MARK: Nutrition & Hydration
    public let fluidIntake: Reading?
    public let calories: Reading?
    public let carbs: Reading?
    public let protein: Reading?
    public let fat: Reading?

    // MARK: Body Composition
    public let weight: Reading?

    // MARK: Meta
    /// Overall data quality for this snapshot.
    public let dataQuality: DataQuality
    /// Wall-clock time this snapshot was assembled.
    public let timestamp: Date
    /// Seconds since the oldest reading used in this snapshot was taken.
    public let evaluationAge: TimeInterval

    public init(
        id: UUID = UUID(),
        glucose: Reading? = nil,
        glucoseTrend: TrendDirection? = nil,
        bloodPressureSystolic: Reading? = nil,
        bloodPressureDiastolic: Reading? = nil,
        heartRate: Reading? = nil,
        heartRateVariability: Reading? = nil,
        spo2: Reading? = nil,
        steps: Reading? = nil,
        inactivityDuration: Reading? = nil,
        sleep: Reading? = nil,
        fluidIntake: Reading? = nil,
        calories: Reading? = nil,
        carbs: Reading? = nil,
        protein: Reading? = nil,
        fat: Reading? = nil,
        weight: Reading? = nil,
        dataQuality: DataQuality = .good,
        timestamp: Date = Date(),
        evaluationAge: TimeInterval = 0
    ) {
        self.id = id
        self.glucose = glucose
        self.glucoseTrend = glucoseTrend
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.spo2 = spo2
        self.steps = steps
        self.inactivityDuration = inactivityDuration
        self.sleep = sleep
        self.fluidIntake = fluidIntake
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.weight = weight
        self.dataQuality = dataQuality
        self.timestamp = timestamp
        self.evaluationAge = evaluationAge
    }

    /// Returns a flat list of all non-nil readings.
    public var allReadings: [Reading] {
        [glucose, bloodPressureSystolic, bloodPressureDiastolic,
         heartRate, heartRateVariability, spo2,
         steps, inactivityDuration, sleep,
         fluidIntake, calories, carbs, protein, fat, weight]
            .compactMap { $0 }
    }
}
