// VitaCoreInferenceProvider.swift
// VitaCoreInference — `InferenceProviderProtocol` production conformance.
//
// Sprint 1.B. This is the bridge between the app's UI layer and the
// on-device Gemma runtime. It handles:
//
//   1. System prompt construction (PersonaContext + ThresholdSet → <2000 tokens)
//   2. Streaming chat via Gemma4Runtime.generate()
//   3. Prescription card generation via structured output parsing
//   4. Conversation session CRUD via ConversationStore (own SQLite)
//   5. Graceful fallback when model is not loaded → rule-based insights
//   6. Food analysis via text-based macro estimation (no vision tower MVP)
//
// Thread-safety: `@unchecked Sendable` because Gemma4Runtime is an actor
// and ConversationStore is an actor; this class holds no mutable state
// of its own beyond the model-loaded flag.

import Foundation
import CoreImage
import VitaCoreContracts

// MARK: - VitaCoreInferenceProvider

public final class VitaCoreInferenceProvider: InferenceProviderProtocol, @unchecked Sendable {

    private let runtime: Gemma4Runtime
    private let conversationStore: ConversationStore

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        runtime: Gemma4Runtime,
        conversationStore: ConversationStore
    ) {
        self.runtime = runtime
        self.conversationStore = conversationStore
    }

    // -------------------------------------------------------------------------
    // MARK: Model Status
    // -------------------------------------------------------------------------

    public func getModelStatus() async -> (status: LLMModelStatus, version: String?) {
        let loadDuration = await runtime.lastLoadDuration
        if loadDuration > 0 {
            return (.ready, "Gemma 3n E4B 4-bit (MLX)")
        }
        return (.notDownloaded, nil)
    }

    public func getModelStatusRecord() async -> ModelStatus {
        let loadDuration = await runtime.lastLoadDuration
        let peakMem = await runtime.lastLoadPeakMemoryBytes
        let isLoaded = loadDuration > 0
        return ModelStatus(
            modelId: "gemma-3n-E4B-it-4bit",
            isLoaded: isLoaded,
            memorySizeMB: isLoaded ? Double(peakMem) / 1_048_576 : nil,
            loadLatencyMs: isLoaded ? loadDuration * 1000 : nil,
            lastInferenceAt: nil,
            errorMessage: nil
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Chat (sendMessage)
    // -------------------------------------------------------------------------

    public func sendMessage(
        _ text: String,
        request: InferenceRequest
    ) -> AsyncStream<String> {
        let (status, _) = UnsafeSendableBox(runtime).value
            .map { _ in (LLMModelStatus.ready, nil as String?) }
            ?? (.notDownloaded, nil)
        // We can't synchronously check actor state, so we go async inside.

        return AsyncStream { continuation in
            Task {
                let modelStatus = await self.getModelStatus()

                if modelStatus.status == .ready {
                    // Model loaded → real Gemma inference with system prompt
                    let systemPrompt = SystemPromptBuilder.build(from: request)
                    let fullPrompt = """
                    <start_of_turn>system
                    \(systemPrompt)
                    <end_of_turn>
                    <start_of_turn>user
                    \(text)
                    <end_of_turn>
                    <start_of_turn>model
                    """

                    let stream = self.runtime.generate(
                        prompt: fullPrompt,
                        maxTokens: 512,
                        temperature: request.temperatureHint
                    )

                    do {
                        for try await chunk in stream {
                            continuation.yield(chunk)
                        }
                    } catch {
                        continuation.yield("\n\n*Inference error: \(error.localizedDescription)*")
                    }
                } else {
                    // Model not loaded → rule-based fallback
                    let response = SystemPromptBuilder.buildRuleBasedResponse(
                        for: text,
                        request: request
                    )
                    // Simulate streaming by yielding word-by-word
                    let words = response.split(separator: " ")
                    for (i, word) in words.enumerated() {
                        let sep = i == 0 ? "" : " "
                        continuation.yield(sep + String(word))
                        try? await Task.sleep(for: .milliseconds(20))
                    }
                }

                continuation.finish()
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Prescription Card
    // -------------------------------------------------------------------------

    public func getLatestPrescriptionCard(
        for request: InferenceRequest
    ) async throws -> PrescriptionCard? {
        let modelStatus = await getModelStatus()

        if modelStatus.status == .ready {
            // Real Gemma inference → structured output
            let systemPrompt = SystemPromptBuilder.build(from: request)
            let prescriptionPrompt = """
            <start_of_turn>system
            \(systemPrompt)

            OUTPUT FORMAT: Respond with ONLY a JSON object:
            {"action_verb":"Walk","action_detail":"Take a brisk 10-minute walk","action_quantity":10,"action_unit":"minutes","primary_benefit":"Improves insulin sensitivity and lowers post-meal glucose","time_window":"within 30 minutes","trajectory_score":0.85,"baseline_delta":-15}
            <end_of_turn>
            <start_of_turn>user
            Based on my current health data, what is the single best action I can take right now?
            <end_of_turn>
            <start_of_turn>model
            """

            var fullResponse = ""
            for try await chunk in runtime.generate(prompt: prescriptionPrompt, maxTokens: 256, temperature: 0.3) {
                fullResponse += chunk
            }

            // Parse JSON from response
            if let prescription = parsePrescription(from: fullResponse, requestId: request.id) {
                return prescription
            }
        }

        // Fallback: rule-based prescription card
        return buildRuleBasedPrescriptionCard(from: request)
    }

    private func parsePrescription(from text: String, requestId: UUID) -> PrescriptionCard? {
        // Extract JSON from the response (model may wrap it in markdown or add text)
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            return nil
        }
        let jsonStr = String(text[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let prescription = Prescription(
            rank: 1,
            actionVerb: dict["action_verb"] as? String ?? "Act",
            actionDetail: dict["action_detail"] as? String ?? "",
            actionQuantity: dict["action_quantity"] as? Double ?? 0,
            actionUnit: dict["action_unit"] as? String ?? "",
            primaryBenefit: dict["primary_benefit"] as? String ?? "",
            timeWindow: dict["time_window"] as? String ?? "now",
            closingTime: nil,
            trajectoryScore: Float(dict["trajectory_score"] as? Double ?? 0.5),
            baselineDelta: dict["baseline_delta"] as? Double ?? 0,
            contraindications: []
        )

        return PrescriptionCard(
            prescriptions: [prescription],
            baselineOutcome: "No action baseline",
            overallConfidence: prescription.trajectoryScore,
            dataCoverage: Float(1.0),
            sourceRequestId: requestId,
            generatedAt: Date()
        )
    }

    private func buildRuleBasedPrescriptionCard(from request: InferenceRequest) -> PrescriptionCard {
        // Simple rule: if glucose is elevated, suggest a walk. If low, suggest a snack.
        let snap = request.snapshot
        var verb = "Walk"
        var detail = "Take a 10-minute brisk walk to improve insulin sensitivity"
        var benefit = "Helps lower post-meal glucose by 15-20 mg/dL"
        var quantity: Double = 10
        var unit = "minutes"

        if let g = snap.glucose {
            let band = request.thresholdSet.classify(value: g.value, for: .glucose)
            if band == .watch && g.value < 80 {
                verb = "Eat"
                detail = "Have 15g of fast-acting carbohydrates (juice, glucose tabs)"
                benefit = "Raises glucose by 30-50 mg/dL within 15 minutes"
                quantity = 15
                unit = "grams carbs"
            } else if band == .safe {
                verb = "Hydrate"
                detail = "Drink a glass of water (250 mL)"
                benefit = "Supports metabolic function and helps maintain glucose stability"
                quantity = 250
                unit = "mL"
            }
        }

        let prescription = Prescription(
            rank: 1,
            actionVerb: verb,
            actionDetail: detail,
            actionQuantity: quantity,
            actionUnit: unit,
            primaryBenefit: benefit,
            timeWindow: "within 30 minutes",
            closingTime: Date().addingTimeInterval(1800),
            trajectoryScore: 0.75,
            baselineDelta: -15,
            contraindications: []
        )

        return PrescriptionCard(
            prescriptions: [prescription],
            baselineOutcome: "Continue current trajectory",
            overallConfidence: 0.75,
            dataCoverage: 1.0,
            sourceRequestId: request.id,
            generatedAt: Date()
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Food Analysis
    // -------------------------------------------------------------------------

    public func analyzeFood(_ description: String) async throws -> FoodAnalysisResult {
        // Sprint 1 F-01: real food database search across 100+ curated items
        // (USDA FoodData Central + South Asian + international foods).
        // Splits the user's input into words and searches for each,
        // aggregating all matching items into one FoodAnalysisResult.

        let foodDB = try FoodDatabase.shared()

        // Split description into searchable terms.
        let terms = description
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var matchedItems: [FoodItem] = []
        var seenIds: Set<Int> = []

        for term in terms {
            let results = try await foodDB.search(term, limit: 3)
            for item in results where !seenIds.contains(item.fdcId) {
                matchedItems.append(item)
                seenIds.insert(item.fdcId)
            }
        }

        // If individual terms didn't match, try the full string.
        if matchedItems.isEmpty {
            let fullResults = try await foodDB.search(description, limit: 5)
            matchedItems = fullResults
        }

        // Build result from matched items.
        if !matchedItems.isEmpty {
            return foodDB.buildAnalysisResult(items: matchedItems)
        }

        // Fallback: generic estimate for completely unknown food.
        return FoodAnalysisResult(
            recognisedItems: [
                FoodEntry(
                    name: description,
                    portionGrams: 200,
                    calories: 300,
                    carbsG: 40,
                    proteinG: 15,
                    fatG: 10,
                    sourceSkillId: "skill.foodTextAnalysis",
                    timestamp: Date()
                )
            ],
            totalCalories: 300,
            totalCarbsG: 40,
            totalProteinG: 15,
            totalFatG: 10,
            confidence: 0.2,
            analysedAt: Date()
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Session CRUD
    // -------------------------------------------------------------------------

    public func getSessions() async throws -> [ConversationSession] {
        try await conversationStore.getAllSessions()
    }

    public func createSession(title: String) async throws -> ConversationSession {
        let session = ConversationSession(
            initiatedBy: .user,
            turns: [
                ConversationTurn(
                    role: .system,
                    content: "Session: \(title)",
                    intent: .conversational
                )
            ],
            status: .active
        )
        try await conversationStore.saveSession(session)
        return session
    }

    public func deleteSession(id: UUID) async throws {
        try await conversationStore.deleteSession(id: id)
    }
}

// MARK: - UnsafeSendableBox (helper for async→sync bridge)

/// Thin wrapper to satisfy Sendable when passing through closures.
/// Only used for non-mutating reads.
private struct UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T?
    init(_ value: T) { self.value = value }
}
