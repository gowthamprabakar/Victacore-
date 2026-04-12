import Foundation
import VitaCoreContracts

public final class MockSkillBus: SkillBusProtocol {

    public init() {}

    // MARK: - Registered Skills

    private let registeredSkills: [SkillDescriptor] = {
        let now = Date()
        return [
            SkillDescriptor(
                id: "appleWatch",
                displayName: "Apple Watch",
                iconName: "applewatch",
                status: .connected,
                lastSyncDescription: "1 min ago",
                confidence: 0.92,
                supportedMetrics: [.heartRate, .heartRateVariability, .steps, .spo2, .inactivityDuration, .sleep]
            ),
            SkillDescriptor(
                id: "dexcomG7",
                displayName: "Dexcom G7",
                iconName: "drop.fill",
                status: .connected,
                lastSyncDescription: "3 min ago",
                confidence: 0.95,
                supportedMetrics: [.glucose]
            ),
            SkillDescriptor(
                id: "freestyleLibre3",
                displayName: "FreeStyle Libre 3",
                iconName: "drop.circle.fill",
                status: .disconnected,
                lastSyncDescription: nil,
                confidence: nil,
                supportedMetrics: [.glucose]
            ),
            SkillDescriptor(
                id: "withingsBPM",
                displayName: "Withings BPM Connect",
                iconName: "heart.fill",
                status: .connected,
                lastSyncDescription: "2 hrs ago",
                confidence: 0.91,
                supportedMetrics: [.bloodPressureSystolic, .bloodPressureDiastolic, .heartRate]
            ),
            SkillDescriptor(
                id: "omron",
                displayName: "Omron",
                iconName: "heart.circle.fill",
                status: .disconnected,
                lastSyncDescription: nil,
                confidence: nil,
                supportedMetrics: [.bloodPressureSystolic, .bloodPressureDiastolic]
            ),
            SkillDescriptor(
                id: "fitbitCharge6",
                displayName: "Fitbit Charge 6",
                iconName: "figure.run",
                status: .authExpired,
                lastSyncDescription: "1 day ago",
                confidence: nil,
                supportedMetrics: [.steps, .heartRate, .sleep]
            ),
            SkillDescriptor(
                id: "whoop5",
                displayName: "Whoop 5.0",
                iconName: "waveform.path.ecg.rectangle",
                status: .disconnected,
                lastSyncDescription: nil,
                confidence: nil,
                supportedMetrics: [.heartRateVariability, .sleep, .heartRate]
            ),
            SkillDescriptor(
                id: "ouraRing",
                displayName: "Oura Ring Gen 4",
                iconName: "circle.dotted",
                status: .connected,
                lastSyncDescription: "30 min ago",
                confidence: 0.90,
                supportedMetrics: [.heartRateVariability, .sleep, .heartRate, .spo2]
            ),
            SkillDescriptor(
                id: "garmin",
                displayName: "Garmin",
                iconName: "figure.outdoor.cycle",
                status: .disconnected,
                lastSyncDescription: nil,
                confidence: nil,
                supportedMetrics: [.steps, .heartRate, .sleep]
            )
        ]
    }()

    // MARK: - SkillBusProtocol

    public func getRegisteredSkills() async -> [SkillDescriptor] {
        registeredSkills
    }

    public func getSkill(id: String) async -> SkillDescriptor? {
        registeredSkills.first { $0.id == id }
    }

    public func syncSkill(id: String) async throws -> SkillLogResult {
        print("[MockSkillBus] syncSkill: \(id)")
        return SkillLogResult(success: true, message: "Sync triggered for \(id)")
    }

    public func disconnectSkill(id: String) async throws {
        print("[MockSkillBus] disconnectSkill: \(id)")
    }

    public func logGlucose(value: Double, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logGlucose: \(value) mg/dL at \(timestamp)")
        return SkillLogResult(success: true, message: "Glucose \(value) mg/dL logged")
    }

    public func logBloodPressure(systolic: Double, diastolic: Double, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logBP: \(systolic)/\(diastolic) at \(timestamp)")
        return SkillLogResult(success: true, message: "BP \(Int(systolic))/\(Int(diastolic)) mmHg logged")
    }

    public func logFluidIntake(volumeML: Double, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logFluid: \(volumeML) mL at \(timestamp)")
        return SkillLogResult(success: true, message: "\(Int(volumeML)) mL logged")
    }

    public func logFoodEntry(result: FoodAnalysisResult, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logFood: \(result.totalCalories) kcal at \(timestamp)")
        return SkillLogResult(success: true, message: "\(Int(result.totalCalories)) kcal logged")
    }

    public func logWeight(valueKg: Double, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logWeight: \(valueKg) kg at \(timestamp)")
        return SkillLogResult(success: true, message: "\(valueKg) kg logged")
    }

    public func logSymptomNote(text: String, timestamp: Date) async -> SkillLogResult {
        print("[MockSkillBus] logSymptom: \(text) at \(timestamp)")
        return SkillLogResult(success: true, message: "Symptom note saved")
    }
}
