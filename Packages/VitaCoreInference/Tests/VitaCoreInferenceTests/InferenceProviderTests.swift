// InferenceProviderTests.swift
// VitaCoreInference — Sprint 1.B tests for VitaCoreInferenceProvider,
// ConversationStore, SystemPromptBuilder, and food analysis.

import Foundation
import Testing
import VitaCoreContracts
@testable import VitaCoreInference

// MARK: - Helper: build a minimal InferenceRequest for testing

private func makeTestRequest(
    conditions: [ConditionKey] = [.type1Diabetes],
    glucoseValue: Double = 137,
    glucoseBand: ClosedRange<Double> = 70...180
) -> InferenceRequest {
    let persona = PersonaContext(
        userId: UUID(),
        activeConditions: conditions.map {
            ConditionSummary(conditionKey: $0, severity: "moderate", daysActive: 30)
        },
        activeGoals: [
            GoalSummary(goalType: .stepsDaily, target: 9000, current: 4500, direction: 1),
            GoalSummary(goalType: .timeInRange, target: 70, current: 60, direction: 1)
        ],
        activeMedications: [
            MedicationSummary(classKey: .insulin, name: "Lantus", dose: "20u", frequency: "QHS")
        ],
        allergies: [
            AllergenSummary(allergen: "Peanut", severity: .severe, semanticMapRefs: ["groundnut"])
        ]
    )

    let snapshot = MonitoringSnapshot(
        glucose: Reading(metricType: .glucose, value: glucoseValue, unit: "mg/dL",
                         timestamp: Date(), sourceSkillId: "skill.cgmDexcom", confidence: 0.95),
        glucoseTrend: .stable,
        bloodPressureSystolic: Reading(metricType: .bloodPressureSystolic, value: 118, unit: "mmHg",
                                       timestamp: Date(), sourceSkillId: "skill.bpManual", confidence: 0.95),
        bloodPressureDiastolic: Reading(metricType: .bloodPressureDiastolic, value: 76, unit: "mmHg",
                                        timestamp: Date(), sourceSkillId: "skill.bpManual", confidence: 0.95),
        heartRate: Reading(metricType: .heartRate, value: 68, unit: "bpm",
                           timestamp: Date(), sourceSkillId: "skill.healthKitHR", confidence: 0.95),
        heartRateVariability: nil,
        spo2: nil,
        steps: Reading(metricType: .steps, value: 4500, unit: "steps",
                       timestamp: Date(), sourceSkillId: "skill.healthKitSteps", confidence: 0.98),
        inactivityDuration: nil,
        sleep: Reading(metricType: .sleep, value: 7.2, unit: "hr",
                       timestamp: Date(), sourceSkillId: "skill.healthKitSleep", confidence: 0.9),
        fluidIntake: nil,
        calories: nil,
        carbs: nil,
        protein: nil,
        fat: nil,
        weight: nil,
        dataQuality: .good,
        timestamp: Date(),
        evaluationAge: 30
    )

    let thresholdSet = ThresholdSet(thresholds: [
        MetricThreshold(metricType: .glucose, safeBand: glucoseBand,
                        watchBand: 54...250, alertBand: 40...300, criticalBand: 0...400, priority: 3),
        MetricThreshold(metricType: .heartRate, safeBand: 50...120,
                        watchBand: 40...130, alertBand: 35...150, criticalBand: 0...220, priority: 2)
    ])

    return InferenceRequest(
        persona: persona,
        snapshot: snapshot,
        thresholdSet: thresholdSet,
        recentEpisodes: [],
        requestedAt: Date(),
        stalenessThreshold: 300,
        conversationalOverride: nil,
        temperatureHint: 0.7
    )
}

// MARK: - SystemPromptBuilder

@Test("System prompt contains safety constraints and persona data")
func testSystemPromptContent() {
    let request = makeTestRequest()
    let prompt = SystemPromptBuilder.build(from: request)

    #expect(prompt.contains("VitaCore"))
    #expect(prompt.contains("NEVER"))
    #expect(prompt.contains("type1Diabetes"))
    #expect(prompt.contains("Lantus"))
    #expect(prompt.contains("Peanut"))
    #expect(prompt.contains("137"))
    #expect(prompt.contains("pattern"))
    // Safety constraints present
    #expect(prompt.contains("seek immediate medical attention"))
    #expect(prompt.contains("Never recommend stopping"))
}

@Test("System prompt stays under 2000 token estimate (~8000 chars)")
func testSystemPromptLength() {
    let request = makeTestRequest()
    let prompt = SystemPromptBuilder.build(from: request)
    #expect(prompt.count < 8000, "System prompt should be under ~2000 tokens / 8000 chars, got \(prompt.count)")
}

@Test("Rule-based response includes glucose insight when model not loaded")
func testRuleBasedResponse() {
    let request = makeTestRequest(glucoseValue: 137)
    let response = SystemPromptBuilder.buildRuleBasedResponse(for: "How am I doing?", request: request)
    #expect(response.contains("137"))
    #expect(response.contains("safe"))
    #expect(response.contains("without the on-device AI model"))
}

@Test("Rule-based response flags elevated glucose")
func testRuleBasedResponseElevated() {
    let request = makeTestRequest(glucoseValue: 210, glucoseBand: 70...180)
    let response = SystemPromptBuilder.buildRuleBasedResponse(for: "What should I do?", request: request)
    #expect(response.contains("walk") || response.contains("water") || response.contains("watch"))
}

// MARK: - ConversationStore

@Test("ConversationStore CRUD round-trip")
func testConversationStoreCRUD() async throws {
    let store = try ConversationStore.inMemory()

    // Create
    let session = ConversationSession(
        initiatedBy: .user,
        turns: [ConversationTurn(role: .user, content: "Hello", intent: .conversational)],
        status: .active
    )
    try await store.saveSession(session)

    // Read all
    let all = try await store.getAllSessions()
    #expect(all.count == 1)
    #expect(all.first?.sessionId == session.sessionId)

    // Read by id
    let fetched = try await store.getSession(id: session.sessionId)
    #expect(fetched?.turns.count == 1)
    #expect(fetched?.turns.first?.content == "Hello")

    // Delete
    try await store.deleteSession(id: session.sessionId)
    let afterDelete = try await store.getAllSessions()
    #expect(afterDelete.isEmpty)
}

@Test("ConversationStore persists multiple sessions ordered by updated_at")
func testMultipleSessions() async throws {
    let store = try ConversationStore.inMemory()

    let s1 = ConversationSession(initiatedBy: .user, status: .active)
    let s2 = ConversationSession(initiatedBy: .proactiveAlert, status: .active)

    try await store.saveSession(s1)
    try await Task.sleep(for: .milliseconds(10))
    try await store.saveSession(s2)

    let all = try await store.getAllSessions()
    #expect(all.count == 2)
    // Most recently updated first
    #expect(all.first?.sessionId == s2.sessionId)
}

// MARK: - InferenceProvider (model-not-loaded path)

@Test("sendMessage returns rule-based response when model not loaded")
func testSendMessageFallback() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let request = makeTestRequest()
    var collected = ""
    for await chunk in provider.sendMessage("How am I doing?", request: request) {
        collected += chunk
    }

    #expect(!collected.isEmpty)
    #expect(collected.contains("137") || collected.contains("safe") || collected.contains("glucose"))
    #expect(collected.contains("without the on-device AI model"))
}

@Test("getLatestPrescriptionCard returns rule-based card when model not loaded")
func testPrescriptionCardFallback() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let request = makeTestRequest(glucoseValue: 190)
    let card = try await provider.getLatestPrescriptionCard(for: request)

    #expect(card != nil)
    #expect(card!.prescriptions.count >= 1)
    #expect(card!.prescriptions.first!.actionVerb.count > 0)
    #expect(card!.overallConfidence > 0)
}

// MARK: - Food Analysis

@Test("analyzeFood recognises common foods")
func testAnalyzeFoodCommon() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let result = try await provider.analyzeFood("chicken rice")
    #expect(result.recognisedItems.count >= 2) // chicken + rice
    #expect(result.totalCalories > 300)
    #expect(result.confidence >= 0.7)
}

@Test("analyzeFood handles South Asian foods")
func testAnalyzeFoodSouthAsian() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let result = try await provider.analyzeFood("dal roti")
    #expect(result.recognisedItems.count >= 2)
    #expect(result.totalCarbsG > 50) // dal + roti = significant carbs
}

@Test("analyzeFood finds quinoa in real DB (was unknown in 15-item lookup)")
func testAnalyzeFoodQuinoa() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    // "quinoa avocado bowl" — the real DB has quinoa (F-01 upgrade).
    let result = try await provider.analyzeFood("quinoa avocado bowl")
    #expect(result.recognisedItems.count >= 1)
    #expect(result.confidence >= 0.5) // quinoa is in the DB now
}

@Test("analyzeFood falls back for truly unknown food")
func testAnalyzeFoodTrulyUnknown() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let result = try await provider.analyzeFood("xyzzy plugh")
    #expect(result.recognisedItems.count == 1) // generic fallback
    #expect(result.confidence <= 0.3)
}

// MARK: - Model Status

@Test("Model status is notDownloaded when runtime not loaded")
func testModelStatusNotLoaded() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let (status, version) = await provider.getModelStatus()
    #expect(status == .notDownloaded)
    #expect(version == nil)

    let record = await provider.getModelStatusRecord()
    #expect(record.isLoaded == false)
    #expect(record.memorySizeMB == nil)
}

// MARK: - Session CRUD via Provider

@Test("Provider session CRUD delegates to ConversationStore")
func testProviderSessionCRUD() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let store = try ConversationStore.inMemory()
    let provider = VitaCoreInferenceProvider(runtime: runtime, conversationStore: store)

    let session = try await provider.createSession(title: "Test Chat")
    #expect(session.status == .active)

    let sessions = try await provider.getSessions()
    #expect(sessions.count == 1)

    try await provider.deleteSession(id: session.sessionId)
    let afterDelete = try await provider.getSessions()
    #expect(afterDelete.isEmpty)
}
