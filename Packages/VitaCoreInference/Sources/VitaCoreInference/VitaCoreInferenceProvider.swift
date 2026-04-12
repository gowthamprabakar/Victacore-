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
        // MVP: text-based macro estimation. No vision tower yet.
        // Simple heuristic lookup for common foods.
        let lower = description.lowercased()

        var items: [FoodEntry] = []
        var totalCal: Double = 0, totalCarbs: Double = 0
        var totalProtein: Double = 0, totalFat: Double = 0

        // Basic food database (expandable)
        let foodDB: [(pattern: String, name: String, cal: Double, carbs: Double, protein: Double, fat: Double)] = [
            ("rice", "Rice (1 cup)", 206, 45, 4.3, 0.4),
            ("chicken", "Chicken breast (100g)", 165, 0, 31, 3.6),
            ("salad", "Mixed salad", 120, 12, 3, 7),
            ("bread", "Bread (2 slices)", 160, 30, 5, 2),
            ("egg", "Eggs (2)", 156, 1.1, 13, 10.6),
            ("banana", "Banana", 105, 27, 1.3, 0.4),
            ("apple", "Apple", 95, 25, 0.5, 0.3),
            ("milk", "Milk (1 cup)", 149, 12, 8, 8),
            ("pasta", "Pasta (1 cup)", 220, 43, 8, 1.3),
            ("fish", "Fish fillet (100g)", 136, 0, 26, 3),
            ("dal", "Dal (1 cup)", 230, 40, 18, 1),
            ("roti", "Roti (2)", 200, 36, 6, 4),
            ("idli", "Idli (3)", 195, 39, 5.4, 0.6),
            ("dosa", "Dosa (1)", 168, 28, 4, 4.5),
            ("biryani", "Biryani (1 plate)", 450, 55, 20, 16)
        ]

        for food in foodDB {
            if lower.contains(food.pattern) {
                items.append(FoodEntry(
                    name: food.name,
                    portionGrams: nil,
                    calories: food.cal,
                    carbsG: food.carbs,
                    proteinG: food.protein,
                    fatG: food.fat,
                    sourceSkillId: "skill.foodTextAnalysis",
                    timestamp: Date()
                ))
                totalCal += food.cal
                totalCarbs += food.carbs
                totalProtein += food.protein
                totalFat += food.fat
            }
        }

        // If nothing matched, estimate generically
        if items.isEmpty {
            let generic = FoodEntry(
                name: description,
                portionGrams: 200,
                calories: 300,
                carbsG: 40,
                proteinG: 15,
                fatG: 10,
                sourceSkillId: "skill.foodTextAnalysis",
                timestamp: Date()
            )
            items.append(generic)
            totalCal = 300; totalCarbs = 40; totalProtein = 15; totalFat = 10
        }

        return FoodAnalysisResult(
            recognisedItems: items,
            totalCalories: totalCal,
            totalCarbsG: totalCarbs,
            totalProteinG: totalProtein,
            totalFatG: totalFat,
            confidence: items.count == 1 && items[0].name == description ? 0.3 : 0.7,
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
