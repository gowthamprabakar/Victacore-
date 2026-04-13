// ChatViewModel.swift
// VitaCore — Conversational AI Interface ViewModel
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Architecture: 5-layer OpenClaw | Sprint Phase 2

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreThreshold

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {

    // MARK: - Session

    var currentSession: ConversationSession?
    var turns: [ConversationTurn] = []

    // MARK: - Input State

    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingContent: String = ""
    var streamingRole: ConversationRole = .assistant

    // MARK: - Health Context Bar

    var isContextBarExpanded: Bool = false
    var contextReadings: [MetricType: Reading] = [:]

    // MARK: - Evidence Disclosure

    var expandedEvidence: Set<UUID> = []

    // MARK: - Model Status

    var modelReady: Bool = true
    var onDeviceIndicatorShown: Bool = true

    // MARK: - View State

    var viewState: ViewState<Void> = .loading

    // MARK: - Dependencies

    private let inferenceProvider: InferenceProviderProtocol
    private let graphStore: GraphStoreProtocol
    private let personaEngine: PersonaEngineProtocol

    // MARK: - Init

    init(
        inferenceProvider: InferenceProviderProtocol,
        graphStore: GraphStoreProtocol,
        personaEngine: PersonaEngineProtocol
    ) {
        self.inferenceProvider = inferenceProvider
        self.graphStore = graphStore
        self.personaEngine = personaEngine
    }

    // MARK: - Load

    func load() async {
        viewState = .loading
        do {
            let sessions = try await inferenceProvider.getSessions()
            if let active = sessions.first(where: { $0.status == .active }) {
                currentSession = active
                turns = active.turns
            } else {
                currentSession = try await inferenceProvider.createSession(title: "New Chat")
                let welcome = ConversationTurn(
                    role: .assistant,
                    content: "Hi Praba! I can help you understand your health data, log meals, or answer questions. What would you like to explore?",
                    intent: .conversational,
                    actions: []
                )
                turns = [welcome]
            }

            await loadHealthContext()
            viewState = .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func loadHealthContext() async {
        let metrics: [MetricType] = [.glucose, .heartRate, .steps, .fluidIntake]
        for metric in metrics {
            if let reading = try? await graphStore.getLatestReading(for: metric) {
                contextReadings[metric] = reading
            }
        }
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let userTurn = ConversationTurn(
            role: .user,
            content: text,
            intent: classifyIntent(text),
            actions: []
        )
        turns.append(userTurn)
        inputText = ""

        isStreaming = true
        streamingContent = ""
        streamingRole = .assistant

        let request = await makeInferenceRequest()
        let stream = inferenceProvider.sendMessage(text, request: request)
        var fullResponse = ""

        for await token in stream {
            fullResponse += token
            streamingContent = fullResponse
        }

        let assistantTurn = ConversationTurn(
            role: .assistant,
            content: fullResponse,
            intent: .conversational,
            actions: suggestedActions(for: fullResponse)
        )
        turns.append(assistantTurn)

        isStreaming = false
        streamingContent = ""
    }

    // MARK: - Proactive Session

    func openProactiveSession(triggerMessage: String, alertContext: String) {
        let systemTurn = ConversationTurn(
            role: .system,
            content: alertContext,
            intent: .conversational,
            actions: []
        )
        let assistantTurn = ConversationTurn(
            role: .assistant,
            content: triggerMessage,
            intent: .healthStatus,
            actions: [.logActivity, .remindLater, .dismiss]
        )
        turns.append(contentsOf: [systemTurn, assistantTurn])
    }

    // MARK: - Evidence Toggle

    func toggleEvidence(for turnId: UUID) {
        if expandedEvidence.contains(turnId) {
            expandedEvidence.remove(turnId)
        } else {
            expandedEvidence.insert(turnId)
        }
    }

    // MARK: - Context Bar

    func toggleContextBar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isContextBarExpanded.toggle()
        }
    }

    // MARK: - Formatted Context Values

    var glucoseDisplayValue: String {
        if let r = contextReadings[.glucose] {
            return String(format: "%.0f", r.value)
        }
        return "—"
    }

    var heartRateDisplayValue: String {
        if let r = contextReadings[.heartRate] {
            return String(format: "%.0f", r.value)
        }
        return "—"
    }

    var stepsDisplayValue: String {
        if let r = contextReadings[.steps] {
            let k = r.value / 1000.0
            return String(format: "%.1fk", k)
        }
        return "—"
    }

    var fluidDisplayValue: String {
        if let r = contextReadings[.fluidIntake] {
            let l = r.value / 1000.0
            return String(format: "%.1fL", l)
        }
        return "—"
    }

    // MARK: - Private Helpers

    private func classifyIntent(_ text: String) -> ConversationIntent {
        let lower = text.lowercased()
        if lower.contains("eat") || lower.contains("food") || lower.contains("meal") { return .foodQuery }
        if lower.contains("glucose") || lower.contains("sugar") || lower.contains("blood") { return .metricQuestion }
        if lower.contains("why") || lower.contains("explain") || lower.contains("how") { return .explanationRequest }
        if lower.contains("walk") || lower.contains("exercise") || lower.contains("gym") { return .lifestyleAdvice }
        if lower.contains("symptom") || lower.contains("feel") || lower.contains("hurt") { return .symptomReport }
        if lower.contains("log") || lower.contains("record") || lower.contains("track") { return .logRequest }
        if lower.contains("goal") || lower.contains("target") { return .goalManagement }
        if lower.contains("medicine") || lower.contains("medication") || lower.contains("pill") { return .medicationQuery }
        return .conversational
    }

    private func suggestedActions(for response: String) -> [ActionType] {
        let lower = response.lowercased()
        var actions: [ActionType] = []
        if lower.contains("walk") || lower.contains("exercise") || lower.contains("activity") {
            actions.append(.logActivity)
        }
        if lower.contains("water") || lower.contains("hydrat") || lower.contains("fluid") {
            actions.append(.logFluid)
        }
        if lower.contains("doctor") || lower.contains("clinician") || lower.contains("physician") {
            actions.append(.contactClinician)
        }
        actions.append(.remindLater)
        actions.append(.dismiss)
        return Array(actions.prefix(3))
    }

    private func makeInferenceRequest() async -> InferenceRequest {
        // Sprint 3.C: fetch REAL health context so the LLM system prompt
        // includes the user's actual conditions, goals, meds, thresholds,
        // and current readings — not empty stubs.
        let persona: PersonaContext
        let snapshot: MonitoringSnapshot
        let thresholds: ThresholdSet

        do {
            persona = try await personaEngine.getPersonaContext()
        } catch {
            persona = PersonaContext(userId: UUID())
        }

        do {
            snapshot = try await graphStore.getCurrentSnapshot()
        } catch {
            snapshot = MonitoringSnapshot(dataQuality: .insufficient)
        }

        // ThresholdSet: resolve from persona conditions using the
        // deterministic ThresholdResolver (no async needed).
        let resolver = ThresholdResolver()
        thresholds = resolver.resolve(from: persona)

        // Fetch recent episodes for context (last 4 hours).
        let recentEpisodes: [Episode]
        do {
            recentEpisodes = try await graphStore.getEpisodes(
                from: Date().addingTimeInterval(-14400),
                to: Date(),
                types: EpisodeType.allCases
            )
        } catch {
            recentEpisodes = []
        }

        return InferenceRequest(
            persona: persona,
            snapshot: snapshot,
            thresholdSet: thresholds,
            recentEpisodes: Array(recentEpisodes.prefix(10)),
            conversationalOverride: nil,
            temperatureHint: 0.4
        )
    }
}
