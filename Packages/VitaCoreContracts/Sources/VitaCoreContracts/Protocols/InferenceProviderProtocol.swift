import Foundation

// MARK: - LLMModelStatus

/// Lifecycle status for the on-device LLM download and readiness.
public enum LLMModelStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case notDownloaded
    case downloading
    case downloaded
    case loading
    case ready
    case error
}

// MARK: - InferenceProviderProtocol

/// Abstraction over the on-device LLM inference engine (MetabolismAgent / MiroFish).
public protocol InferenceProviderProtocol: Sendable {

    /// Streams a token-by-token response for a user message.
    func sendMessage(
        _ text: String,
        request: InferenceRequest
    ) -> AsyncStream<String>

    /// Returns the most recent prescription card for the given request.
    func getLatestPrescriptionCard(for request: InferenceRequest) async throws -> PrescriptionCard?

    /// Returns the current model lifecycle status and version string.
    func getModelStatus() async -> (status: LLMModelStatus, version: String?)

    /// Returns the detailed on-device model status record.
    func getModelStatusRecord() async -> ModelStatus

    /// Analyses a food description and returns macro breakdown.
    func analyzeFood(_ description: String) async throws -> FoodAnalysisResult

    /// Returns all saved conversation sessions.
    func getSessions() async throws -> [ConversationSession]

    /// Creates a new conversation session and returns it.
    func createSession(title: String) async throws -> ConversationSession

    /// Deletes a session by id.
    func deleteSession(id: UUID) async throws
}
