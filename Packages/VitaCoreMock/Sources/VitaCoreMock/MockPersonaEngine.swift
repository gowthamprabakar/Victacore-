import Foundation
import VitaCoreContracts

public final class MockPersonaEngine: PersonaEngineProtocol {

    public init() {}

    // MARK: - Persona Data

    private let mockPersona: PersonaContext = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let dob = cal.date(from: DateComponents(year: 1990, month: 1, day: 15))!
        let now = Date()

        let conditions: [ConditionSummary] = [
            ConditionSummary(conditionKey: .type2Diabetes, severity: "moderate", daysActive: 365),
            ConditionSummary(conditionKey: .hypertension, severity: "mild", daysActive: 180)
        ]

        let goals: [GoalSummary] = [
            GoalSummary(goalType: .stepsDaily, target: 10_000, current: 7_520, direction: 1),
            GoalSummary(goalType: .fluidDaily, target: 2_500, current: 1_200, direction: 1),
            GoalSummary(goalType: .timeInRange, target: 80, current: 84, direction: -1)
        ]

        let medications: [MedicationSummary] = [
            MedicationSummary(
                classKey: .metformin,
                name: "Metformin",
                dose: "500mg",
                frequency: "BID",
                interactionFlags: []
            ),
            MedicationSummary(
                classKey: .aceInhibitor,
                name: "Lisinopril",
                dose: "10mg",
                frequency: "QD",
                interactionFlags: []
            )
        ]

        let allergies: [AllergenSummary] = [
            AllergenSummary(
                allergen: "Peanut",
                severity: .severe,
                semanticMapRefs: ["groundnut", "satay", "peanut butter", "arachis oil"]
            )
        ]

        let goalProgress: [GoalProgress] = [
            GoalProgress(
                goalType: .stepsDaily,
                target: 10_000,
                current: 7_520,
                trend: .improving,
                streakDays: 4
            ),
            GoalProgress(
                goalType: .fluidDaily,
                target: 2_500,
                current: 1_200,
                trend: .worsening,
                streakDays: 0
            ),
            GoalProgress(
                goalType: .timeInRange,
                target: 80,
                current: 84,
                trend: .improving,
                streakDays: 7
            )
        ]

        let preferences = PreferenceSummary(
            dietaryRestrictions: [],
            cuisinePreferences: ["Indian", "Mediterranean"],
            notificationQuietHoursStart: 22,
            notificationQuietHoursEnd: 7,
            preferMetricUnits: true,
            languageCode: "en"
        )

        return PersonaContext(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            activeConditions: conditions,
            activeGoals: goals,
            activeMedications: medications,
            allergies: allergies,
            preferences: preferences,
            responseProfiles: [
                ResponseProfileSummary(
                    interventionType: "10min_walk",
                    avgDelta: -18,
                    sampleCount: 23,
                    confidence: 0.87
                ),
                ResponseProfileSummary(
                    interventionType: "500mL_water",
                    avgDelta: -6,
                    sampleCount: 15,
                    confidence: 0.72
                )
            ],
            thresholdOverrides: [],
            dataQualityFlags: [],
            goalProgress: goalProgress
        )
    }()

    // MARK: - PersonaEngineProtocol

    public func getPersonaContext() async throws -> PersonaContext {
        mockPersona
    }

    public func getActiveConditions() async throws -> [ConditionSummary] {
        mockPersona.activeConditions
    }

    public func getActiveGoals() async throws -> [GoalSummary] {
        mockPersona.activeGoals
    }

    public func getActiveMedications() async throws -> [MedicationSummary] {
        mockPersona.activeMedications
    }

    public func getAllergies() async throws -> [AllergenSummary] {
        mockPersona.allergies
    }

    public func getGoalProgress() async throws -> [GoalProgress] {
        mockPersona.goalProgress
    }

    public func updatePersonaContext(_ context: PersonaContext) async throws {
        // No-op for mock
    }

    public func updateGoal(type: GoalType, newTarget: Double) async throws {
        // No-op for mock
    }

    public func addMedication(_ medication: MedicationSummary) async throws {
        // No-op for mock
    }

    public func removeMedication(id: UUID) async throws {
        // No-op for mock
    }
}
