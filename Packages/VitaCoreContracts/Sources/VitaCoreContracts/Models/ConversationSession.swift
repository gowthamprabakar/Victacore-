import Foundation

// MARK: - ConversationIntent

/// The semantic intent detected or assigned to a conversation turn.
public enum ConversationIntent: String, Codable, Sendable, Hashable, CaseIterable {
    case foodQuery
    case foodAlternative
    case metricQuestion
    case healthStatus
    case explanationRequest
    case symptomReport
    case goalManagement
    case medicationQuery
    case lifestyleAdvice
    case logRequest
    case conversational
    case outOfScope
    case clarificationNeeded
    case imageAnalysis
}

// MARK: - ActionType

/// A discrete follow-up action that can be triggered from a conversation turn.
public enum ActionType: String, Codable, Sendable, Hashable, CaseIterable {
    case logActivity
    case logFluid
    case remindLater
    case dismiss
    case contactClinician
    case emergencyCall
}

// MARK: - ConversationRole

public enum ConversationRole: String, Codable, Sendable, Hashable, CaseIterable {
    case user
    case assistant
    case system
}

// MARK: - ConversationInitiator

/// Who or what triggered the conversation session.
public enum ConversationInitiator: String, Codable, Sendable, Hashable, CaseIterable {
    case user
    case proactiveAlert
    case proactiveDigest
    case proactiveWeekly
}

// MARK: - ConversationStatus

public enum ConversationStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case active
    case resolved
    case escalated
    case abandoned
}

// MARK: - ConversationTurn

/// A single message exchange within a session.
public struct ConversationTurn: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let role: ConversationRole
    public let content: String
    public let intent: ConversationIntent
    public let actions: [ActionType]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: ConversationRole,
        content: String,
        intent: ConversationIntent = .conversational,
        actions: [ActionType] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.intent = intent
        self.actions = actions
        self.timestamp = timestamp
    }
}

// MARK: - ConversationSession

/// A bounded dialogue session between the user and the VitaCore AI.
public struct ConversationSession: Identifiable, Codable, Sendable, Hashable {
    public let sessionId: UUID
    public var id: UUID { sessionId }
    public let initiatedBy: ConversationInitiator
    public var turns: [ConversationTurn]
    public var status: ConversationStatus
    /// The health context snapshot captured when the session was started.
    public let contextSnapshot: MonitoringSnapshot?
    /// A brief AI-generated summary written when the session resolves.
    public var sessionSummary: String?
    public let startedAt: Date
    public var endedAt: Date?

    public init(
        sessionId: UUID = UUID(),
        initiatedBy: ConversationInitiator,
        turns: [ConversationTurn] = [],
        status: ConversationStatus = .active,
        contextSnapshot: MonitoringSnapshot? = nil,
        sessionSummary: String? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.sessionId = sessionId
        self.initiatedBy = initiatedBy
        self.turns = turns
        self.status = status
        self.contextSnapshot = contextSnapshot
        self.sessionSummary = sessionSummary
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Returns all unique action types surfaced in this session.
    public var surfacedActions: Set<ActionType> {
        Set(turns.flatMap { $0.actions })
    }
}
