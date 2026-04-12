import Foundation

/// Categorises the origin and nature of an Episode node in the graph.
public enum EpisodeType: String, Codable, Sendable, Hashable, CaseIterable {
    case healthkitSteps
    case healthkitHeartrate
    case healthkitSleep
    case healthkitWorkout
    case healthkitSpO2
    case healthkitHRV
    case cgmGlucose
    case manualGlucose
    case bpReading
    case nutritionEvent
    case fluidEvent
    case weightReading
    case symptomNote
    case medicationEvent
    case monitoringResult
    case inferenceOutput
    case conversationTurn
    case simulationResult
    case alertEvent
    case personaChange
    case correction
    case dataGap
    case descriptiveInsight
}

/// A time-stamped graph node representing a discrete health event.
public struct Episode: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let episodeType: EpisodeType
    /// The skill (data source) that produced this episode.
    public let sourceSkillId: String
    /// Confidence score emitted by the source skill [0, 1].
    public let sourceConfidence: Float
    /// The wall-clock time the event occurred or was measured.
    public let referenceTime: Date
    /// The wall-clock time the episode was written to the graph.
    public let ingestionTime: Date
    /// Opaque binary payload; callers decode with `EpisodeType`-specific logic.
    public let payload: Data

    public init(
        id: UUID = UUID(),
        episodeType: EpisodeType,
        sourceSkillId: String,
        sourceConfidence: Float,
        referenceTime: Date,
        ingestionTime: Date = Date(),
        payload: Data
    ) {
        self.id = id
        self.episodeType = episodeType
        self.sourceSkillId = sourceSkillId
        self.sourceConfidence = sourceConfidence
        self.referenceTime = referenceTime
        self.ingestionTime = ingestionTime
        self.payload = payload
    }
}
