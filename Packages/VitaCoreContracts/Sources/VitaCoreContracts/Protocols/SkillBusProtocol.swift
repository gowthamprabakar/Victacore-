import Foundation

// MARK: - SkillDescriptor

/// Lightweight descriptor for a registered device / data-source skill as seen by the UI.
/// The full manifest is defined in Models/SkillManifest.swift (SkillManifest).
public struct SkillDescriptor: Identifiable, Codable, Sendable, Hashable {
    /// Stable skill identifier, e.g. "appleWatch", "dexcomG7".
    public let id: String
    public let displayName: String
    /// SF Symbol name for the skill's icon.
    public let iconName: String
    public let status: SkillConnectionStatus
    /// Human-readable description of when data last synced, e.g. "1 min ago".
    public let lastSyncDescription: String?
    /// Source confidence in [0, 1] when connected.
    public let confidence: Float?
    /// Metric types this skill can provide.
    public let supportedMetrics: [MetricType]

    public init(
        id: String,
        displayName: String,
        iconName: String,
        status: SkillConnectionStatus,
        lastSyncDescription: String? = nil,
        confidence: Float? = nil,
        supportedMetrics: [MetricType] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.status = status
        self.lastSyncDescription = lastSyncDescription
        self.confidence = confidence
        self.supportedMetrics = supportedMetrics
    }
}

// MARK: - SkillLogResult

public struct SkillLogResult: Sendable {
    public let success: Bool
    public let message: String?

    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

// MARK: - SkillBusProtocol

/// Abstraction over the skill / device ecosystem message bus.
public protocol SkillBusProtocol: Sendable {

    /// Returns all registered skill descriptors.
    func getRegisteredSkills() async -> [SkillDescriptor]

    /// Returns a single skill descriptor by id.
    func getSkill(id: String) async -> SkillDescriptor?

    /// Triggers a manual sync for the given skill.
    func syncSkill(id: String) async throws -> SkillLogResult

    /// Disconnects (de-authenticates) a skill.
    func disconnectSkill(id: String) async throws

    /// Logs a manual glucose reading through the skill bus.
    func logGlucose(value: Double, timestamp: Date) async -> SkillLogResult

    /// Logs a manual blood-pressure reading.
    func logBloodPressure(systolic: Double, diastolic: Double, timestamp: Date) async -> SkillLogResult

    /// Logs a manual fluid intake entry in mL.
    func logFluidIntake(volumeML: Double, timestamp: Date) async -> SkillLogResult

    /// Logs a manual food entry.
    func logFoodEntry(result: FoodAnalysisResult, timestamp: Date) async -> SkillLogResult

    /// Logs a manual weight reading in kg.
    func logWeight(valueKg: Double, timestamp: Date) async -> SkillLogResult

    /// Logs a symptom note.
    func logSymptomNote(text: String, timestamp: Date) async -> SkillLogResult
}
