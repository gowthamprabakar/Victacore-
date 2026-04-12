// VitaCorePersonaEngine.swift
// VitaCorePersona — `PersonaEngineProtocol` production conformance.
//
// T031 + T032 rewrite: ALL bootstrap and mutation logic now delegates to
// actor-isolated methods on `GRDBPersonaStore`:
//
//   • `store.bootstrapIfNeeded(inferencer:graphStore:)` — serialises the
//     load→infer→save sequence so concurrent `getPersonaContext()` calls
//     on an empty store produce exactly one row.
//   • `store.mutate { ctx in ... }` — serialises read-modify-write so
//     concurrent `addMedication` + `updateGoal` cannot lose each other.
//
// The engine itself holds no mutable state and needs no lock of its own.

import Foundation
import VitaCoreContracts

// MARK: - VitaCorePersonaEngine

public final class VitaCorePersonaEngine: PersonaEngineProtocol, @unchecked Sendable {

    private let store: GRDBPersonaStore
    private let inferencer: PersonaInferencer
    private let graphStore: GraphStoreProtocol

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        store: GRDBPersonaStore,
        graphStore: GraphStoreProtocol,
        inferencer: PersonaInferencer = PersonaInferencer()
    ) {
        self.store = store
        self.graphStore = graphStore
        self.inferencer = inferencer
    }

    // -------------------------------------------------------------------------
    // MARK: PersonaEngineProtocol — Read
    // -------------------------------------------------------------------------

    public func getPersonaContext() async throws -> PersonaContext {
        // T031: bootstrap is actor-serialised inside the store. Two
        // concurrent callers both enter this method → actor serialises →
        // first caller infers + saves → second caller sees the saved row.
        try await store.bootstrapIfNeeded(
            inferencer: inferencer,
            graphStore: graphStore
        )
    }

    public func getActiveConditions() async throws -> [ConditionSummary] {
        try await getPersonaContext().activeConditions
    }

    public func getActiveGoals() async throws -> [GoalSummary] {
        try await getPersonaContext().activeGoals
    }

    public func getActiveMedications() async throws -> [MedicationSummary] {
        try await getPersonaContext().activeMedications
    }

    public func getAllergies() async throws -> [AllergenSummary] {
        try await getPersonaContext().allergies
    }

    public func getGoalProgress() async throws -> [GoalProgress] {
        try await getPersonaContext().goalProgress
    }

    // -------------------------------------------------------------------------
    // MARK: PersonaEngineProtocol — Write
    // -------------------------------------------------------------------------

    public func updatePersonaContext(_ context: PersonaContext) async throws {
        try await store.saveContext(context)
    }

    public func updateGoal(type: GoalType, newTarget: Double) async throws {
        // T032: actor-serialised read-modify-write — no lost updates.
        _ = try await store.mutate { ctx in
            let updatedGoals = ctx.activeGoals.map { goal -> GoalSummary in
                guard goal.goalType == type else { return goal }
                return GoalSummary(
                    goalType: goal.goalType,
                    target: newTarget,
                    current: goal.current,
                    direction: goal.direction
                )
            }
            return PersonaContext(
                userId: ctx.userId,
                activeConditions: ctx.activeConditions,
                activeGoals: updatedGoals,
                activeMedications: ctx.activeMedications,
                allergies: ctx.allergies,
                preferences: ctx.preferences,
                responseProfiles: ctx.responseProfiles,
                thresholdOverrides: ctx.thresholdOverrides,
                dataQualityFlags: ctx.dataQualityFlags,
                goalProgress: ctx.goalProgress
            )
        }
    }

    public func addMedication(_ medication: MedicationSummary) async throws {
        _ = try await store.mutate { ctx in
            PersonaContext(
                userId: ctx.userId,
                activeConditions: ctx.activeConditions,
                activeGoals: ctx.activeGoals,
                activeMedications: ctx.activeMedications + [medication],
                allergies: ctx.allergies,
                preferences: ctx.preferences,
                responseProfiles: ctx.responseProfiles,
                thresholdOverrides: ctx.thresholdOverrides,
                dataQualityFlags: ctx.dataQualityFlags,
                goalProgress: ctx.goalProgress
            )
        }
    }

    public func removeMedication(id: UUID) async throws {
        _ = try await store.mutate { ctx in
            PersonaContext(
                userId: ctx.userId,
                activeConditions: ctx.activeConditions,
                activeGoals: ctx.activeGoals,
                activeMedications: ctx.activeMedications.filter { $0.id != id },
                allergies: ctx.allergies,
                preferences: ctx.preferences,
                responseProfiles: ctx.responseProfiles,
                thresholdOverrides: ctx.thresholdOverrides,
                dataQualityFlags: ctx.dataQualityFlags,
                goalProgress: ctx.goalProgress
            )
        }
    }
}
