// FoodFlowCoordinator.swift
// VitaCore – Food Photo Analysis Pipeline
// Stage orchestrator: state machine + ViewModel for the 7-stage food flow.

import SwiftUI
import Observation
import UIKit
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Stage Machine

enum FoodFlowStage: Equatable {
    case camera
    case qualityCheck(ImageQualityReport)
    case analysisLoading
    case allergenWarning(AllergenWarning)
    case medicationInteraction(MedicationInteraction)
    case review(FoodAnalysisResult)
    case confirmation(FoodAnalysisResult)
    case error(String)

    static func == (lhs: FoodFlowStage, rhs: FoodFlowStage) -> Bool {
        switch (lhs, rhs) {
        case (.camera, .camera):                         return true
        case (.analysisLoading, .analysisLoading):       return true
        case (.qualityCheck, .qualityCheck):             return true
        case (.allergenWarning, .allergenWarning):       return true
        case (.medicationInteraction, .medicationInteraction): return true
        case (.review, .review):                         return true
        case (.confirmation, .confirmation):             return true
        case (.error, .error):                           return true
        default:                                         return false
        }
    }
}

// MARK: - Supporting Warning / Interaction Types

struct AllergenWarning: Identifiable, Equatable {
    let id = UUID()
    let allergen: String
    let severity: AllergenSeverity
    let detectedInItem: String
    let matchReason: String

    static func == (lhs: AllergenWarning, rhs: AllergenWarning) -> Bool {
        lhs.id == rhs.id
    }
}

struct MedicationInteraction: Identifiable, Equatable {
    let id = UUID()
    let medication: String
    let medicationClass: MedicationClass
    let food: String
    let severity: InteractionSeverity
    let description: String
    let recommendation: String

    enum InteractionSeverity: String {
        case caution, moderate, severe
    }

    static func == (lhs: MedicationInteraction, rhs: MedicationInteraction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class FoodFlowViewModel {

    // MARK: Published state
    var currentStage: FoodFlowStage = .camera
    var capturedImage: UIImage?
    var capturedImageData: Data?
    var analysisResult: FoodAnalysisResult?
    var qualityReport: ImageQualityReport?

    /// Progress 0.0 – 1.0 for the loading stage.
    var analysisProgress: Double = 0.0
    var analysisStatusText: String = "Analyzing your meal..."

    /// Editable portions per FoodEntry.id (grams).
    var editablePortions: [UUID: Double] = [:]

    // MARK: Dependencies
    private let inferenceProvider: InferenceProviderProtocol
    private let personaEngine: PersonaEngineProtocol
    private let skillBus: SkillBusProtocol

    init(
        inferenceProvider: InferenceProviderProtocol,
        personaEngine: PersonaEngineProtocol,
        skillBus: SkillBusProtocol
    ) {
        self.inferenceProvider = inferenceProvider
        self.personaEngine = personaEngine
        self.skillBus = skillBus
    }

    // MARK: - Image Capture Entry Point

    func handleImageCapture(_ image: UIImage) async {
        capturedImage = image
        capturedImageData = image.jpegData(compressionQuality: 0.8)

        let report = await mockQualityCheck()
        qualityReport = report

        if !report.isUsable || report.overallScore < 0.6 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStage = .qualityCheck(report)
            }
            return
        }

        await startAnalysis()
    }

    // MARK: - Quality Check Responses

    func acceptLowQuality() {
        Task { await startAnalysis() }
    }

    func retakePhoto() {
        capturedImage = nil
        capturedImageData = nil
        qualityReport = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStage = .camera
        }
    }

    // MARK: - Analysis Pipeline

    func startAnalysis() async {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStage = .analysisLoading
            analysisProgress = 0.0
            analysisStatusText = "Analyzing your meal..."
        }

        let progressSteps: [(Double, String)] = [
            (0.15, "Detecting food items..."),
            (0.35, "Measuring portions..."),
            (0.55, "Calculating nutrition..."),
            (0.75, "Checking allergens..."),
            (0.90, "Checking medications..."),
            (1.00, "Almost done...")
        ]

        for (progress, status) in progressSteps {
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.analysisProgress = progress
                self.analysisStatusText = status
            }
        }

        let mockResult = createMockAnalysisResult()
        analysisResult = mockResult

        for item in mockResult.recognisedItems {
            if let grams = item.portionGrams {
                editablePortions[item.id] = grams
            }
        }

        if let allergen = await checkAllergens(result: mockResult) {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentStage = .allergenWarning(allergen)
            }
            return
        }

        if let interaction = await checkMedicationInteractions(result: mockResult) {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentStage = .medicationInteraction(interaction)
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            currentStage = .review(mockResult)
        }
    }

    // MARK: - Allergen / Medication Responses

    func acknowledgeAllergen() {
        guard let result = analysisResult else { return }
        Task {
            if let interaction = await checkMedicationInteractions(result: result) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStage = .medicationInteraction(interaction)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStage = .review(result)
                }
            }
        }
    }

    func acknowledgeMedicationInteraction() {
        guard let result = analysisResult else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStage = .review(result)
        }
    }

    // MARK: - Review Actions

    func updatePortion(for itemId: UUID, grams: Double) {
        editablePortions[itemId] = grams
    }

    func discardFood() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStage = .camera
        }
        analysisResult = nil
        capturedImage = nil
        capturedImageData = nil
        analysisProgress = 0
        editablePortions = [:]
    }

    func confirmFood() async {
        guard let result = analysisResult else { return }

        // Sprint 1 F-04: write confirmed food to GraphStore via SkillBus.
        let logResult = await skillBus.logFoodEntry(
            result: result,
            timestamp: Date()
        )
        if !logResult.success {
            print("⚠️ FoodFlow: failed to log food — \(logResult.message ?? "unknown error")")
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            currentStage = .confirmation(result)
        }
    }

    // MARK: - Mock Helpers

    private func mockQualityCheck() async -> ImageQualityReport {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return ImageQualityReport(
            isUsable: true,
            brightnessScore: 0.85,
            sharpnessScore: 0.82,
            occlusionScore: 0.95,
            overallScore: 0.87,
            issues: []
        )
    }

    private func createMockAnalysisResult() -> FoodAnalysisResult {
        let items: [FoodEntry] = [
            FoodEntry(
                name: "Basmati Rice",
                portionGrams: 180,
                calories: 234,
                carbsG: 52,
                proteinG: 4.3,
                fatG: 0.5,
                sourceSkillId: "skill.manual.food.vision"
            ),
            FoodEntry(
                name: "Dal (Lentil Curry)",
                portionGrams: 150,
                calories: 186,
                carbsG: 28,
                proteinG: 12,
                fatG: 4.2,
                sourceSkillId: "skill.manual.food.vision"
            )
        ]

        return FoodAnalysisResult(
            recognisedItems: items,
            totalCalories: 420,
            totalCarbsG: 80,
            totalProteinG: 16.3,
            totalFatG: 4.7,
            confidence: 0.82
        )
    }

    private func checkAllergens(result: FoodAnalysisResult) async -> AllergenWarning? {
        // Persona-driven allergen matching will be wired here via personaEngine.
        return nil
    }

    private func checkMedicationInteractions(result: FoodAnalysisResult) async -> MedicationInteraction? {
        // Medication interaction checks will be wired here via personaEngine / skillBus.
        return nil
    }
}
