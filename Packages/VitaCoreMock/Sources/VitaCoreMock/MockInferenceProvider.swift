import Foundation
import VitaCoreContracts

public final class MockInferenceProvider: InferenceProviderProtocol {

    public init() {}

    // MARK: - sendMessage

    public func sendMessage(
        _ text: String,
        request: InferenceRequest
    ) -> AsyncStream<String> {
        let tokens = [
            "Based", " on", " your", " current", " glucose", " of", " 142", " mg/dL",
            " and", " stable", " trend,", " a", " 10-minute", " walk", " would",
            " typically", " bring", " it", " down", " by", " about", " 18", " mg/dL",
            " within", " 20", " minutes.", " Your", " post-breakfast", " pattern",
            " shows", " this", " is", " a", " consistent", " response."
        ]
        return AsyncStream { continuation in
            Task {
                for token in tokens {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - getLatestPrescriptionCard

    public func getLatestPrescriptionCard(for request: InferenceRequest) async throws -> PrescriptionCard? {
        let now = Date()
        let prescriptions: [Prescription] = [
            Prescription(
                rank: 1,
                actionVerb: "Walk",
                actionDetail: "10 minutes at moderate pace",
                actionQuantity: 10,
                actionUnit: "minutes",
                primaryBenefit: "Glucose reduction ~18 mg/dL",
                timeWindow: "within 20 minutes",
                closingTime: now.addingTimeInterval(1800),
                trajectoryScore: 0.87,
                baselineDelta: -18,
                contraindications: []
            ),
            Prescription(
                rank: 2,
                actionVerb: "Drink water",
                actionDetail: "500mL of water",
                actionQuantity: 500,
                actionUnit: "mL",
                primaryBenefit: "Improved insulin sensitivity",
                timeWindow: "next 30 minutes",
                closingTime: now.addingTimeInterval(1800),
                trajectoryScore: 0.72,
                baselineDelta: -6,
                contraindications: []
            )
        ]
        return PrescriptionCard(
            prescriptions: prescriptions,
            baselineOutcome: "Glucose likely to remain elevated at 145–155 mg/dL without action.",
            overallConfidence: 0.87,
            dataCoverage: 0.94,
            sourceRequestId: request.id
        )
    }

    // MARK: - getModelStatus

    public func getModelStatus() async -> (status: LLMModelStatus, version: String?) {
        (.downloaded, "Gemma4-E4B-INT4")
    }

    public func getModelStatusRecord() async -> ModelStatus {
        ModelStatus(
            modelId: "Gemma4-E4B-INT4",
            isLoaded: true,
            memorySizeMB: 2_048,
            loadLatencyMs: 1_340,
            lastInferenceAt: Date().addingTimeInterval(-300)
        )
    }

    // MARK: - analyzeFood

    public func analyzeFood(_ description: String) async throws -> FoodAnalysisResult {
        let rice = FoodEntry(
            name: "Basmati rice",
            portionGrams: 200,
            calories: 260,
            carbsG: 56,
            proteinG: 5,
            fatG: 0.5,
            sourceSkillId: "mockVision"
        )
        let dal = FoodEntry(
            name: "Toor dal",
            portionGrams: 150,
            calories: 160,
            carbsG: 22,
            proteinG: 9,
            fatG: 2.5,
            sourceSkillId: "mockVision"
        )
        return FoodAnalysisResult(
            recognisedItems: [rice, dal],
            totalCalories: 420,
            totalCarbsG: 78,
            totalProteinG: 14,
            totalFatG: 3,
            confidence: 0.88
        )
    }

    // MARK: - getSessions / createSession / deleteSession

    public func getSessions() async throws -> [ConversationSession] {
        let now = Date()
        return [
            ConversationSession(
                initiatedBy: .user,
                turns: [],
                status: .resolved,
                sessionSummary: "Discussed post-meal glucose spike and walk prescription.",
                startedAt: now.addingTimeInterval(-86400),
                endedAt: now.addingTimeInterval(-82800)
            ),
            ConversationSession(
                initiatedBy: .proactiveAlert,
                turns: [],
                status: .resolved,
                sessionSummary: "Addressed low glucose alert at 65 mg/dL.",
                startedAt: now.addingTimeInterval(-172800),
                endedAt: now.addingTimeInterval(-172200)
            )
        ]
    }

    public func createSession(title: String) async throws -> ConversationSession {
        ConversationSession(
            initiatedBy: .user,
            status: .active,
            startedAt: Date()
        )
    }

    public func deleteSession(id: UUID) async throws {
        // No-op for mock
    }
}
