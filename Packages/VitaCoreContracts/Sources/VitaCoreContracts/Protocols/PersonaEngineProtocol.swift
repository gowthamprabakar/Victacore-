import Foundation

// MARK: - PersonaEngineProtocol

/// Abstraction over the persona / profile engine.
public protocol PersonaEngineProtocol: Sendable {

    /// Returns the full persona context for the current user.
    func getPersonaContext() async throws -> PersonaContext

    /// Returns only the active conditions.
    func getActiveConditions() async throws -> [ConditionSummary]

    /// Returns only the active goals.
    func getActiveGoals() async throws -> [GoalSummary]

    /// Returns only the active medications.
    func getActiveMedications() async throws -> [MedicationSummary]

    /// Returns only the active allergens.
    func getAllergies() async throws -> [AllergenSummary]

    /// Returns current goal progress entries.
    func getGoalProgress() async throws -> [GoalProgress]

    /// Persists an updated persona context.
    func updatePersonaContext(_ context: PersonaContext) async throws

    /// Updates a single goal's target value.
    func updateGoal(type: GoalType, newTarget: Double) async throws

    /// Adds a new medication.
    func addMedication(_ medication: MedicationSummary) async throws

    /// Removes a medication by id.
    func removeMedication(id: UUID) async throws
}
