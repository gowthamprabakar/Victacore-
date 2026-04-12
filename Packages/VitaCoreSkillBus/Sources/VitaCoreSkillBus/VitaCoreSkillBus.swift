// VitaCoreSkillBus.swift
// VitaCoreSkillBus — `SkillBusProtocol` production conformance.
//
// Sprint 2.A. This is the last of the 5 frozen protocols to get a real
// implementation. After this, MockDataProvider is fully replaceable.
//
// Architecture:
//   • Manual entry skills (glucose, BP, fluid, food, weight, note)
//     write directly to GraphStoreProtocol via `writeReading` / `writeEpisode`.
//   • Device skills register as SkillDescriptors and are managed through
//     the `registeredSkills` array. HealthKitSkill (Sprint 2.B) will be
//     the first real device skill; until then only manual skills exist.
//   • Each log method produces both a Reading (for metric queries) and
//     an Episode (for event-based queries / timeline).

import Foundation
import VitaCoreContracts

// MARK: - VitaCoreSkillBus

public final class VitaCoreSkillBus: SkillBusProtocol, @unchecked Sendable {

    private let graphStore: GraphStoreProtocol
    private var registeredSkills: [SkillDescriptor]

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
        // Register manual-entry skills as always-connected.
        self.registeredSkills = [
            SkillDescriptor(
                id: "skill.manual.glucose",
                displayName: "Manual Glucose",
                iconName: "drop.fill",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 1.0,
                supportedMetrics: [.glucose]
            ),
            SkillDescriptor(
                id: "skill.manual.bp",
                displayName: "Manual Blood Pressure",
                iconName: "heart.fill",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 1.0,
                supportedMetrics: [.bloodPressureSystolic, .bloodPressureDiastolic]
            ),
            SkillDescriptor(
                id: "skill.manual.fluid",
                displayName: "Manual Fluid Intake",
                iconName: "cup.and.saucer.fill",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 1.0,
                supportedMetrics: [.fluidIntake]
            ),
            SkillDescriptor(
                id: "skill.manual.food",
                displayName: "Food Log",
                iconName: "leaf.fill",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 0.9,
                supportedMetrics: [.calories, .carbs, .protein, .fat]
            ),
            SkillDescriptor(
                id: "skill.manual.weight",
                displayName: "Manual Weight",
                iconName: "scalemass.fill",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 1.0,
                supportedMetrics: [.weight]
            ),
            SkillDescriptor(
                id: "skill.manual.note",
                displayName: "Symptom Note",
                iconName: "note.text",
                status: .connected,
                lastSyncDescription: "Always available",
                confidence: 1.0,
                supportedMetrics: []
            )
        ]
    }

    /// Current number of registered skills (for logging).
    public var registeredSkillCount: Int { registeredSkills.count }

    /// Registers an external device skill (e.g. HealthKitSkill).
    /// Called during app init or when a new device is paired.
    public func registerSkill(_ descriptor: SkillDescriptor) {
        registeredSkills.removeAll { $0.id == descriptor.id }
        registeredSkills.append(descriptor)
    }

    // -------------------------------------------------------------------------
    // MARK: Skill Management
    // -------------------------------------------------------------------------

    public func getRegisteredSkills() async -> [SkillDescriptor] {
        registeredSkills
    }

    public func getSkill(id: String) async -> SkillDescriptor? {
        registeredSkills.first { $0.id == id }
    }

    public func syncSkill(id: String) async throws -> SkillLogResult {
        // Manual skills don't need syncing. Device skills will override.
        SkillLogResult(success: true, message: "Manual skills are always in sync")
    }

    public func disconnectSkill(id: String) async throws {
        // Manual skills can't be disconnected. Device skills will override.
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Glucose
    // -------------------------------------------------------------------------

    public func logGlucose(value: Double, timestamp: Date) async -> SkillLogResult {
        let reading = Reading(
            metricType: .glucose,
            value: value,
            unit: MetricType.glucose.unit,
            timestamp: timestamp,
            sourceSkillId: "skill.manual.glucose",
            confidence: 1.0,
            trendDirection: .stable
        )
        let episode = Episode(
            episodeType: .manualGlucose,
            sourceSkillId: "skill.manual.glucose",
            sourceConfidence: 1.0,
            referenceTime: timestamp,
            payload: encodePayload(["value": value, "unit": "mg/dL"])
        )
        do {
            try await graphStore.writeReading(reading)
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "Glucose \(Int(value)) mg/dL logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Blood Pressure
    // -------------------------------------------------------------------------

    public func logBloodPressure(systolic: Double, diastolic: Double, timestamp: Date) async -> SkillLogResult {
        let sysReading = Reading(
            metricType: .bloodPressureSystolic, value: systolic,
            unit: MetricType.bloodPressureSystolic.unit, timestamp: timestamp,
            sourceSkillId: "skill.manual.bp", confidence: 1.0
        )
        let diaReading = Reading(
            metricType: .bloodPressureDiastolic, value: diastolic,
            unit: MetricType.bloodPressureDiastolic.unit, timestamp: timestamp,
            sourceSkillId: "skill.manual.bp", confidence: 1.0
        )
        let episode = Episode(
            episodeType: .bpReading,
            sourceSkillId: "skill.manual.bp",
            sourceConfidence: 1.0,
            referenceTime: timestamp,
            payload: encodePayload(["systolic": systolic, "diastolic": diastolic])
        )
        do {
            try await graphStore.writeReadings([sysReading, diaReading])
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "BP \(Int(systolic))/\(Int(diastolic)) mmHg logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Fluid
    // -------------------------------------------------------------------------

    public func logFluidIntake(volumeML: Double, timestamp: Date) async -> SkillLogResult {
        let reading = Reading(
            metricType: .fluidIntake, value: volumeML,
            unit: MetricType.fluidIntake.unit, timestamp: timestamp,
            sourceSkillId: "skill.manual.fluid", confidence: 1.0
        )
        let episode = Episode(
            episodeType: .fluidEvent,
            sourceSkillId: "skill.manual.fluid",
            sourceConfidence: 1.0,
            referenceTime: timestamp,
            payload: encodePayload(["volume_ml": volumeML])
        )
        do {
            try await graphStore.writeReading(reading)
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "\(Int(volumeML)) mL logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Food
    // -------------------------------------------------------------------------

    public func logFoodEntry(result: FoodAnalysisResult, timestamp: Date) async -> SkillLogResult {
        let readings = [
            Reading(metricType: .calories, value: result.totalCalories,
                    unit: MetricType.calories.unit, timestamp: timestamp,
                    sourceSkillId: "skill.manual.food", confidence: result.confidence),
            Reading(metricType: .carbs, value: result.totalCarbsG,
                    unit: MetricType.carbs.unit, timestamp: timestamp,
                    sourceSkillId: "skill.manual.food", confidence: result.confidence),
            Reading(metricType: .protein, value: result.totalProteinG,
                    unit: MetricType.protein.unit, timestamp: timestamp,
                    sourceSkillId: "skill.manual.food", confidence: result.confidence),
            Reading(metricType: .fat, value: result.totalFatG,
                    unit: MetricType.fat.unit, timestamp: timestamp,
                    sourceSkillId: "skill.manual.food", confidence: result.confidence)
        ]
        let itemNames = result.recognisedItems.map(\.name).joined(separator: ", ")
        let episode = Episode(
            episodeType: .nutritionEvent,
            sourceSkillId: "skill.manual.food",
            sourceConfidence: result.confidence,
            referenceTime: timestamp,
            payload: encodePayload(["items": itemNames, "calories": result.totalCalories, "carbs": result.totalCarbsG])
        )
        do {
            try await graphStore.writeReadings(readings)
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "\(itemNames) (\(Int(result.totalCalories)) kcal) logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Weight
    // -------------------------------------------------------------------------

    public func logWeight(valueKg: Double, timestamp: Date) async -> SkillLogResult {
        let reading = Reading(
            metricType: .weight, value: valueKg,
            unit: MetricType.weight.unit, timestamp: timestamp,
            sourceSkillId: "skill.manual.weight", confidence: 1.0
        )
        let episode = Episode(
            episodeType: .weightReading,
            sourceSkillId: "skill.manual.weight",
            sourceConfidence: 1.0,
            referenceTime: timestamp,
            payload: encodePayload(["weight_kg": valueKg])
        )
        do {
            try await graphStore.writeReading(reading)
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "\(String(format: "%.1f", valueKg)) kg logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Manual Entry — Symptom Note
    // -------------------------------------------------------------------------

    public func logSymptomNote(text: String, timestamp: Date) async -> SkillLogResult {
        let episode = Episode(
            episodeType: .symptomNote,
            sourceSkillId: "skill.manual.note",
            sourceConfidence: 1.0,
            referenceTime: timestamp,
            payload: encodePayload(["text": text])
        )
        do {
            try await graphStore.writeEpisode(episode)
            return SkillLogResult(success: true, message: "Note logged")
        } catch {
            return SkillLogResult(success: false, message: error.localizedDescription)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Payload helper
    // -------------------------------------------------------------------------

    private func encodePayload(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}
