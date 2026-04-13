import Foundation

// MARK: - Supporting Enums

public enum ConditionKey: String, Codable, Sendable, Hashable, CaseIterable {
    case type2Diabetes
    case type1Diabetes
    case prediabetes
    case hypertension
    case hypertensionS2
    case cardiacRisk
    case heartFailure
    case elderly65Plus
    case hypothyroidism
    case hyperthyroidism
    case ckd
    case copd
    case obesity
    case pcos
    case ironDeficiency
    case vitaminDDeficiency
    case healthyBaseline
}

public enum GoalType: String, Codable, Sendable, Hashable, CaseIterable {
    case glucoseA1C
    case bpSystolic
    case bpDiastolic
    case stepsDaily
    case weightTarget
    case sleepDuration
    case fluidDaily
    case caloriesDaily
    case carbsDaily
    case proteinDaily
    case exerciseMinutes
    case timeInRange
    case restingHR
    case hrvTarget
}

public enum MedicationClass: String, Codable, Sendable, Hashable, CaseIterable {
    case metformin
    case insulin
    case sulfonylurea
    case sglt2Inhibitor
    case glp1Agonist
    case betaBlocker
    case aceInhibitor
    case calciumChannelBlocker
    case diuretic
    case statin
    case warfarin
    case levothyroxine
    case maoi
    case other
}

public enum AllergenSeverity: String, Codable, Sendable, Hashable, CaseIterable {
    case mild
    case moderate
    case severe
    case anaphylactic
}

// MARK: - Supporting Structs

public struct ConditionSummary: Identifiable, Codable, Sendable, Hashable {
    public var id: ConditionKey { conditionKey }
    public let conditionKey: ConditionKey
    public let severity: String
    public let daysActive: Int

    public init(conditionKey: ConditionKey, severity: String, daysActive: Int) {
        self.conditionKey = conditionKey
        self.severity = severity
        self.daysActive = daysActive
    }
}

public struct GoalSummary: Identifiable, Codable, Sendable, Hashable {
    public var id: GoalType { goalType }
    public let goalType: GoalType
    public let target: Double
    public let current: Double
    /// Positive means target is above current; negative means below.
    public let direction: Double

    public init(goalType: GoalType, target: Double, current: Double, direction: Double) {
        self.goalType = goalType
        self.target = target
        self.current = current
        self.direction = direction
    }
}

public struct MedicationSummary: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let classKey: MedicationClass
    public let name: String
    public let dose: String
    public let frequency: String
    public let interactionFlags: [String]

    public init(
        id: UUID = UUID(),
        classKey: MedicationClass,
        name: String,
        dose: String,
        frequency: String,
        interactionFlags: [String] = []
    ) {
        self.id = id
        self.classKey = classKey
        self.name = name
        self.dose = dose
        self.frequency = frequency
        self.interactionFlags = interactionFlags
    }
}

public struct AllergenSummary: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let allergen: String
    public let severity: AllergenSeverity
    /// References into the semantic allergy map.
    public let semanticMapRefs: [String]

    public init(
        id: UUID = UUID(),
        allergen: String,
        severity: AllergenSeverity,
        semanticMapRefs: [String] = []
    ) {
        self.id = id
        self.allergen = allergen
        self.severity = severity
        self.semanticMapRefs = semanticMapRefs
    }
}

public struct PreferenceSummary: Codable, Sendable, Hashable {
    public let dietaryRestrictions: [String]
    public let cuisinePreferences: [String]
    public let notificationQuietHoursStart: Int   // hour in 24h
    public let notificationQuietHoursEnd: Int
    public let preferMetricUnits: Bool
    public let languageCode: String

    public init(
        dietaryRestrictions: [String] = [],
        cuisinePreferences: [String] = [],
        notificationQuietHoursStart: Int = 22,
        notificationQuietHoursEnd: Int = 7,
        preferMetricUnits: Bool = true,
        languageCode: String = "en"
    ) {
        self.dietaryRestrictions = dietaryRestrictions
        self.cuisinePreferences = cuisinePreferences
        self.notificationQuietHoursStart = notificationQuietHoursStart
        self.notificationQuietHoursEnd = notificationQuietHoursEnd
        self.preferMetricUnits = preferMetricUnits
        self.languageCode = languageCode
    }
}

public struct ResponseProfileSummary: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    /// The type of intervention (e.g., "30min_walk", "low_carb_meal").
    public let interventionType: String
    /// Average metric delta observed after this intervention.
    public let avgDelta: Double
    public let sampleCount: Int
    public let confidence: Float

    public init(
        id: UUID = UUID(),
        interventionType: String,
        avgDelta: Double,
        sampleCount: Int,
        confidence: Float
    ) {
        self.id = id
        self.interventionType = interventionType
        self.avgDelta = avgDelta
        self.sampleCount = sampleCount
        self.confidence = confidence
    }
}

public struct ThresholdOverride: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricType: MetricType
    public let lowerBound: Double?
    public let upperBound: Double?
    public let reason: String

    public init(
        id: UUID = UUID(),
        metricType: MetricType,
        lowerBound: Double? = nil,
        upperBound: Double? = nil,
        reason: String
    ) {
        self.id = id
        self.metricType = metricType
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.reason = reason
    }
}

public struct DataQualityFlag: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricType: MetricType
    public let flagCode: String
    public let description: String
    public let detectedAt: Date

    public init(
        id: UUID = UUID(),
        metricType: MetricType,
        flagCode: String,
        description: String,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.metricType = metricType
        self.flagCode = flagCode
        self.description = description
        self.detectedAt = detectedAt
    }
}

// MARK: - ActivityStatus (Sprint 4 O-04)

/// The user's current activity status. MiroFish adjusts recommendations
/// when the user is sick, injured, or resting.
public enum ActivityStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case active     // Normal — full recommendations
    case sick       // Reduce exercise, prioritise rest
    case injured    // Avoid specific movements
    case resting    // Intentional rest day
}

// MARK: - PersonaContext (frozen contract)

/// The complete, user-specific health context used to personalise every inference.
public struct PersonaContext: Identifiable, Codable, Sendable, Hashable {
    public let userId: UUID
    public var id: UUID { userId }
    public let activeConditions: [ConditionSummary]
    public let activeGoals: [GoalSummary]
    public let activeMedications: [MedicationSummary]
    public let allergies: [AllergenSummary]
    public let preferences: PreferenceSummary
    public let responseProfiles: [ResponseProfileSummary]
    public let thresholdOverrides: [ThresholdOverride]
    public let dataQualityFlags: [DataQualityFlag]
    public let goalProgress: [GoalProgress]
    /// Sprint 4 O-04: user's current activity status. Optional for
    /// backwards compatibility with existing stored blobs.
    public let activityStatus: ActivityStatus?

    public init(
        userId: UUID,
        activeConditions: [ConditionSummary] = [],
        activeGoals: [GoalSummary] = [],
        activeMedications: [MedicationSummary] = [],
        allergies: [AllergenSummary] = [],
        preferences: PreferenceSummary = PreferenceSummary(),
        responseProfiles: [ResponseProfileSummary] = [],
        thresholdOverrides: [ThresholdOverride] = [],
        dataQualityFlags: [DataQualityFlag] = [],
        goalProgress: [GoalProgress] = [],
        activityStatus: ActivityStatus? = .active
    ) {
        self.userId = userId
        self.activeConditions = activeConditions
        self.activeGoals = activeGoals
        self.activeMedications = activeMedications
        self.allergies = allergies
        self.preferences = preferences
        self.responseProfiles = responseProfiles
        self.thresholdOverrides = thresholdOverrides
        self.dataQualityFlags = dataQualityFlags
        self.goalProgress = goalProgress
        self.activityStatus = activityStatus
    }
}
