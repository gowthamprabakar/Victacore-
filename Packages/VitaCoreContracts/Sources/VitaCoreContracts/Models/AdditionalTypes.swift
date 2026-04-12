import Foundation

// MARK: - UserProfile

/// Core identity and demographic information for a VitaCore user.
public struct UserProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let displayName: String
    public let email: String
    public let dateOfBirth: Date?
    public let biologicalSex: BiologicalSex
    public let heightCm: Double?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        email: String,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex = .notSpecified,
        heightCm: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum BiologicalSex: String, Codable, Sendable, Hashable, CaseIterable {
    case male
    case female
    case other
    case notSpecified
}

// MARK: - Entry Types

public struct ConditionEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let conditionKey: ConditionKey
    public let diagnosedAt: Date?
    public let severity: String
    public let notes: String?

    public init(id: UUID = UUID(), conditionKey: ConditionKey, diagnosedAt: Date? = nil, severity: String, notes: String? = nil) {
        self.id = id; self.conditionKey = conditionKey; self.diagnosedAt = diagnosedAt; self.severity = severity; self.notes = notes
    }
}

public struct GoalEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let goalType: GoalType
    public let target: Double
    public let startDate: Date
    public let endDate: Date?
    public let notes: String?

    public init(id: UUID = UUID(), goalType: GoalType, target: Double, startDate: Date = Date(), endDate: Date? = nil, notes: String? = nil) {
        self.id = id; self.goalType = goalType; self.target = target; self.startDate = startDate; self.endDate = endDate; self.notes = notes
    }
}

public struct MedicationEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let classKey: MedicationClass
    public let name: String
    public let dose: String
    public let frequency: String
    public let startDate: Date
    public let endDate: Date?

    public init(id: UUID = UUID(), classKey: MedicationClass, name: String, dose: String, frequency: String, startDate: Date = Date(), endDate: Date? = nil) {
        self.id = id; self.classKey = classKey; self.name = name; self.dose = dose; self.frequency = frequency; self.startDate = startDate; self.endDate = endDate
    }
}

public struct AllergyEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let allergen: String
    public let severity: AllergenSeverity
    public let reaction: String?
    public let recordedAt: Date

    public init(id: UUID = UUID(), allergen: String, severity: AllergenSeverity, reaction: String? = nil, recordedAt: Date = Date()) {
        self.id = id; self.allergen = allergen; self.severity = severity; self.reaction = reaction; self.recordedAt = recordedAt
    }
}

public struct FluidEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let volumeMl: Double
    public let fluidType: String
    public let timestamp: Date

    public init(id: UUID = UUID(), volumeMl: Double, fluidType: String = "water", timestamp: Date = Date()) {
        self.id = id; self.volumeMl = volumeMl; self.fluidType = fluidType; self.timestamp = timestamp
    }
}

public struct GlucoseEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let valueMgDl: Double
    public let context: GlucoseContext
    public let sourceSkillId: String
    public let timestamp: Date

    public init(id: UUID = UUID(), valueMgDl: Double, context: GlucoseContext = .unknown, sourceSkillId: String, timestamp: Date = Date()) {
        self.id = id; self.valueMgDl = valueMgDl; self.context = context; self.sourceSkillId = sourceSkillId; self.timestamp = timestamp
    }
}

public enum GlucoseContext: String, Codable, Sendable, Hashable, CaseIterable {
    case fasting, postMeal, preMeal, bedtime, wakeUp, unknown
}

public struct BPEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let systolicMmHg: Double
    public let diastolicMmHg: Double
    public let heartRateBpm: Double?
    public let sourceSkillId: String
    public let timestamp: Date

    public init(id: UUID = UUID(), systolicMmHg: Double, diastolicMmHg: Double, heartRateBpm: Double? = nil, sourceSkillId: String, timestamp: Date = Date()) {
        self.id = id; self.systolicMmHg = systolicMmHg; self.diastolicMmHg = diastolicMmHg; self.heartRateBpm = heartRateBpm; self.sourceSkillId = sourceSkillId; self.timestamp = timestamp
    }
}

public struct WeightEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let valueKg: Double
    public let sourceSkillId: String
    public let timestamp: Date

    public init(id: UUID = UUID(), valueKg: Double, sourceSkillId: String, timestamp: Date = Date()) {
        self.id = id; self.valueKg = valueKg; self.sourceSkillId = sourceSkillId; self.timestamp = timestamp
    }
}

public struct NoteEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let content: String
    public let tags: [String]
    public let timestamp: Date

    public init(id: UUID = UUID(), content: String, tags: [String] = [], timestamp: Date = Date()) {
        self.id = id; self.content = content; self.tags = tags; self.timestamp = timestamp
    }
}

public struct FoodEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let portionGrams: Double?
    public let calories: Double?
    public let carbsG: Double?
    public let proteinG: Double?
    public let fatG: Double?
    public let sourceSkillId: String
    public let timestamp: Date

    public init(id: UUID = UUID(), name: String, portionGrams: Double? = nil, calories: Double? = nil, carbsG: Double? = nil, proteinG: Double? = nil, fatG: Double? = nil, sourceSkillId: String, timestamp: Date = Date()) {
        self.id = id; self.name = name; self.portionGrams = portionGrams; self.calories = calories; self.carbsG = carbsG; self.proteinG = proteinG; self.fatG = fatG; self.sourceSkillId = sourceSkillId; self.timestamp = timestamp
    }
}

// MARK: - Preference Profile

public struct PreferenceProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let preferences: PreferenceSummary
    public let updatedAt: Date

    public init(id: UUID = UUID(), userId: UUID, preferences: PreferenceSummary, updatedAt: Date = Date()) {
        self.id = id; self.userId = userId; self.preferences = preferences; self.updatedAt = updatedAt
    }
}

// MARK: - BackupStatus

public struct BackupStatus: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let lastBackupAt: Date?
    public let totalEpisodes: Int
    public let sizeBytes: Int64
    public let isEncrypted: Bool

    public init(id: UUID = UUID(), lastBackupAt: Date? = nil, totalEpisodes: Int = 0, sizeBytes: Int64 = 0, isEncrypted: Bool = true) {
        self.id = id; self.lastBackupAt = lastBackupAt; self.totalEpisodes = totalEpisodes; self.sizeBytes = sizeBytes; self.isEncrypted = isEncrypted
    }
}

// MARK: - Graph Write Results

public struct EpisodeWriteResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let episodeId: UUID
    public let success: Bool
    public let errorMessage: String?
    public let writtenAt: Date

    public init(id: UUID = UUID(), episodeId: UUID, success: Bool, errorMessage: String? = nil, writtenAt: Date = Date()) {
        self.id = id; self.episodeId = episodeId; self.success = success; self.errorMessage = errorMessage; self.writtenAt = writtenAt
    }
}

public struct BatchWriteResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let results: [EpisodeWriteResult]
    public var successCount: Int { results.filter { $0.success }.count }
    public var failureCount: Int { results.filter { !$0.success }.count }

    public init(id: UUID = UUID(), results: [EpisodeWriteResult]) {
        self.id = id; self.results = results
    }
}

// MARK: - PointInTimeState

/// A complete snapshot of all graph data as of a specific moment.
public struct PointInTimeState: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let asOf: Date
    public let episodes: [Episode]
    public let persona: PersonaContext?
    public let snapshot: MonitoringSnapshot?

    public init(id: UUID = UUID(), asOf: Date, episodes: [Episode] = [], persona: PersonaContext? = nil, snapshot: MonitoringSnapshot? = nil) {
        self.id = id; self.asOf = asOf; self.episodes = episodes; self.persona = persona; self.snapshot = snapshot
    }
}

// MARK: - Search & Query Types

public struct SearchOptions: Codable, Sendable, Hashable {
    public let limit: Int
    public let offset: Int
    public let sortDescending: Bool
    public let includeStale: Bool

    public init(limit: Int = 50, offset: Int = 0, sortDescending: Bool = true, includeStale: Bool = false) {
        self.limit = limit; self.offset = offset; self.sortDescending = sortDescending; self.includeStale = includeStale
    }
}

public struct ContextResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let episodes: [Episode]
    public let totalCount: Int
    public let queryDurationMs: Double

    public init(id: UUID = UUID(), episodes: [Episode], totalCount: Int, queryDurationMs: Double = 0) {
        self.id = id; self.episodes = episodes; self.totalCount = totalCount; self.queryDurationMs = queryDurationMs
    }
}

/// A composable predicate for graph queries.
public indirect enum PredicateTree: Codable, Sendable, Hashable {
    case episodeType(EpisodeType)
    case metricType(MetricType)
    case skillId(String)
    case dateRange(ClosedRange<Date>)
    case and([PredicateTree])
    case or([PredicateTree])
    case not(PredicateTree)
}

public struct CompositeResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let readings: [Reading]
    public let episodes: [Episode]
    public let alerts: [AlertEvent]

    public init(id: UUID = UUID(), readings: [Reading] = [], episodes: [Episode] = [], alerts: [AlertEvent] = []) {
        self.id = id; self.readings = readings; self.episodes = episodes; self.alerts = alerts
    }
}

// MARK: - TimeWindow

/// Convenience enum for common query time horizons.
public enum TimeWindow: String, Codable, Sendable, Hashable, CaseIterable {
    case lastHour
    case last4Hours
    case last8Hours
    case last24Hours
    case last7Days
    case last30Days
    case last90Days

    public var duration: TimeInterval {
        switch self {
        case .lastHour:    return 3600
        case .last4Hours:  return 4 * 3600
        case .last8Hours:  return 8 * 3600
        case .last24Hours: return 24 * 3600
        case .last7Days:   return 7 * 24 * 3600
        case .last30Days:  return 30 * 24 * 3600
        case .last90Days:  return 90 * 24 * 3600
        }
    }

    public var startDate: Date { Date(timeIntervalSinceNow: -duration) }
    public var range: ClosedRange<Date> { startDate...Date() }
}

// MARK: - AggregateResult

public struct AggregateResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricType: MetricType
    public let window: TimeWindow
    public let mean: Double
    public let min: Double
    public let max: Double
    public let standardDeviation: Double
    public let sampleCount: Int
    public let computedAt: Date

    public init(id: UUID = UUID(), metricType: MetricType, window: TimeWindow, mean: Double, min: Double, max: Double, standardDeviation: Double, sampleCount: Int, computedAt: Date = Date()) {
        self.id = id; self.metricType = metricType; self.window = window; self.mean = mean; self.min = min; self.max = max; self.standardDeviation = standardDeviation; self.sampleCount = sampleCount; self.computedAt = computedAt
    }
}

// MARK: - Hydration Summary

public struct HydrationSummary: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let date: Date
    public let totalMl: Double
    public let goalMl: Double
    public var percentage: Double { goalMl == 0 ? 0 : min(1.0, totalMl / goalMl) }
    public let entries: [FluidEntry]

    public init(id: UUID = UUID(), date: Date, totalMl: Double, goalMl: Double, entries: [FluidEntry] = []) {
        self.id = id; self.date = date; self.totalMl = totalMl; self.goalMl = goalMl; self.entries = entries
    }
}

// MARK: - MedicationTiming

public struct MedicationTiming: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let medication: MedicationSummary
    public let scheduledAt: Date
    public var takenAt: Date?
    public var skipped: Bool

    public init(id: UUID = UUID(), medication: MedicationSummary, scheduledAt: Date, takenAt: Date? = nil, skipped: Bool = false) {
        self.id = id; self.medication = medication; self.scheduledAt = scheduledAt; self.takenAt = takenAt; self.skipped = skipped
    }
}

// MARK: - GlucoseTrend

public struct GlucoseTrend: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let readings: [GlucoseEntry]
    public let direction: TrendDirection
    public let velocity: Double?         // mg/dL per minute
    public let timeInRangePercent: Double
    public let computedAt: Date

    public init(id: UUID = UUID(), readings: [GlucoseEntry], direction: TrendDirection, velocity: Double? = nil, timeInRangePercent: Double, computedAt: Date = Date()) {
        self.id = id; self.readings = readings; self.direction = direction; self.velocity = velocity; self.timeInRangePercent = timeInRangePercent; self.computedAt = computedAt
    }
}

// MARK: - Food Analysis

public struct FoodAnalysisResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let recognisedItems: [FoodEntry]
    public let totalCalories: Double
    public let totalCarbsG: Double
    public let totalProteinG: Double
    public let totalFatG: Double
    public let confidence: Float
    public let analysedAt: Date

    public init(id: UUID = UUID(), recognisedItems: [FoodEntry], totalCalories: Double, totalCarbsG: Double, totalProteinG: Double, totalFatG: Double, confidence: Float, analysedAt: Date = Date()) {
        self.id = id; self.recognisedItems = recognisedItems; self.totalCalories = totalCalories; self.totalCarbsG = totalCarbsG; self.totalProteinG = totalProteinG; self.totalFatG = totalFatG; self.confidence = confidence; self.analysedAt = analysedAt
    }
}

public struct ImageQualityReport: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let isUsable: Bool
    public let brightnessScore: Float
    public let sharpnessScore: Float
    public let occlusionScore: Float
    public let overallScore: Float
    public let issues: [String]

    public init(id: UUID = UUID(), isUsable: Bool, brightnessScore: Float, sharpnessScore: Float, occlusionScore: Float, overallScore: Float, issues: [String] = []) {
        self.id = id; self.isUsable = isUsable; self.brightnessScore = brightnessScore; self.sharpnessScore = sharpnessScore; self.occlusionScore = occlusionScore; self.overallScore = overallScore; self.issues = issues
    }
}

// MARK: - NER Entity

public struct NEREntity: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let text: String
    public let label: String            // e.g. "FOOD", "SYMPTOM", "MEDICATION"
    public let confidence: Float
    public let startIndex: Int
    public let endIndex: Int

    public init(id: UUID = UUID(), text: String, label: String, confidence: Float, startIndex: Int, endIndex: Int) {
        self.id = id; self.text = text; self.label = label; self.confidence = confidence; self.startIndex = startIndex; self.endIndex = endIndex
    }
}

// MARK: - Simulation

public struct SimulationSeed: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let baselineSnapshot: MonitoringSnapshot
    public let interventions: [String]
    public let horizonHours: Int
    public let randomSeed: UInt64?

    public init(id: UUID = UUID(), baselineSnapshot: MonitoringSnapshot, interventions: [String] = [], horizonHours: Int = 24, randomSeed: UInt64? = nil) {
        self.id = id; self.baselineSnapshot = baselineSnapshot; self.interventions = interventions; self.horizonHours = horizonHours; self.randomSeed = randomSeed
    }
}

// MARK: - ModelStatus

public struct ModelStatus: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let modelId: String
    public let isLoaded: Bool
    public let memorySizeMB: Double?
    public let loadLatencyMs: Double?
    public let lastInferenceAt: Date?
    public let errorMessage: String?

    public init(id: UUID = UUID(), modelId: String, isLoaded: Bool, memorySizeMB: Double? = nil, loadLatencyMs: Double? = nil, lastInferenceAt: Date? = nil, errorMessage: String? = nil) {
        self.id = id; self.modelId = modelId; self.isLoaded = isLoaded; self.memorySizeMB = memorySizeMB; self.loadLatencyMs = loadLatencyMs; self.lastInferenceAt = lastInferenceAt; self.errorMessage = errorMessage
    }
}
