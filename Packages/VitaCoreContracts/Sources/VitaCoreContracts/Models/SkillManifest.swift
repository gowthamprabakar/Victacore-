import Foundation

// MARK: - SkillConnectionType

public enum SkillConnectionType: String, Codable, Sendable, Hashable, CaseIterable {
    case healthkit
    case oauth
    case bluetooth
    case manual
}

// MARK: - SkillConnectionStatus

public enum SkillConnectionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case connected
    case disconnected
    case authExpired
    case syncing
    case error
}

// MARK: - SkillTriggerMode

public enum SkillTriggerMode: String, Codable, Sendable, Hashable, CaseIterable {
    /// Fired on a fixed time interval.
    case periodic
    /// Fired when a HealthKit observer fires.
    case healthKitObserver
    /// Fired when a Bluetooth characteristic changes.
    case bluetoothCharacteristic
    /// Fired on demand by the skill bus.
    case onDemand
}

// MARK: - SkillHealthStatus

/// Runtime health report for a single skill.
public struct SkillHealthStatus: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let skillId: String
    public let isHealthy: Bool
    public let latencyMs: Double?
    public let errorMessage: String?
    public let checkedAt: Date

    public init(
        id: UUID = UUID(),
        skillId: String,
        isHealthy: Bool,
        latencyMs: Double? = nil,
        errorMessage: String? = nil,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.isHealthy = isHealthy
        self.latencyMs = latencyMs
        self.errorMessage = errorMessage
        self.checkedAt = checkedAt
    }
}

// MARK: - SkillManifest

/// Describes a registered skill (data adapter) in the VitaCore skill bus.
public struct SkillManifest: Identifiable, Codable, Sendable, Hashable {
    public let skillId: String
    public var id: String { skillId }
    public let displayName: String
    /// Short hardware or service name shown in the skill list.
    public let deviceName: String
    /// SF Symbol name for this skill's icon.
    public let icon: String
    public let connectionType: SkillConnectionType
    public var status: SkillConnectionStatus
    public var lastSyncTime: Date?
    /// Weighting applied to readings from this skill when composing snapshots [0, 1].
    public let confidenceWeight: Float
    public let triggerMode: SkillTriggerMode

    public init(
        skillId: String,
        displayName: String,
        deviceName: String,
        icon: String,
        connectionType: SkillConnectionType,
        status: SkillConnectionStatus = .disconnected,
        lastSyncTime: Date? = nil,
        confidenceWeight: Float = 1.0,
        triggerMode: SkillTriggerMode = .onDemand
    ) {
        self.skillId = skillId
        self.displayName = displayName
        self.deviceName = deviceName
        self.icon = icon
        self.connectionType = connectionType
        self.status = status
        self.lastSyncTime = lastSyncTime
        self.confidenceWeight = confidenceWeight
        self.triggerMode = triggerMode
    }
}
