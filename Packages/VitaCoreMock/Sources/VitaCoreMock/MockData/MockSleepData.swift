import Foundation
import VitaCoreContracts

/// Generates a realistic 7.2-hour sleep session with stage breakdown.
public enum MockSleepData {

    // MARK: - Sleep Stage Breakdown (minutes)
    // Total: 432 minutes = 7.2 hours
    // Light:  162 min (37.5%)
    // Deep:    90 min (20.8%)
    // REM:    144 min (33.3%)
    // Awake:   36 min ( 8.3%)

    private struct SleepStage {
        let name: String
        let durationMinutes: Double
        let sourceSkillId: String
    }

    private static let stages: [SleepStage] = [
        SleepStage(name: "Light",  durationMinutes: 20,  sourceSkillId: "ouraRing"),   // Fall asleep
        SleepStage(name: "Deep",   durationMinutes: 30,  sourceSkillId: "ouraRing"),   // First deep cycle
        SleepStage(name: "REM",    durationMinutes: 36,  sourceSkillId: "ouraRing"),   // First REM
        SleepStage(name: "Light",  durationMinutes: 18,  sourceSkillId: "ouraRing"),   // Brief light
        SleepStage(name: "Awake",  durationMinutes: 8,   sourceSkillId: "ouraRing"),   // Brief awakening
        SleepStage(name: "Light",  durationMinutes: 22,  sourceSkillId: "ouraRing"),   // Returning to sleep
        SleepStage(name: "Deep",   durationMinutes: 35,  sourceSkillId: "ouraRing"),   // Second deep cycle
        SleepStage(name: "REM",    durationMinutes: 42,  sourceSkillId: "ouraRing"),   // Second REM
        SleepStage(name: "Light",  durationMinutes: 15,  sourceSkillId: "ouraRing"),   // Light
        SleepStage(name: "Deep",   durationMinutes: 25,  sourceSkillId: "ouraRing"),   // Third deep
        SleepStage(name: "REM",    durationMinutes: 48,  sourceSkillId: "ouraRing"),   // Third REM (longest)
        SleepStage(name: "Light",  durationMinutes: 40,  sourceSkillId: "ouraRing"),   // Lighter near wake
        SleepStage(name: "Awake",  durationMinutes: 10,  sourceSkillId: "ouraRing"),   // Brief awakening
        SleepStage(name: "REM",    durationMinutes: 18,  sourceSkillId: "ouraRing"),   // Final REM
        SleepStage(name: "Light",  durationMinutes: 47,  sourceSkillId: "ouraRing"),   // Wake transition
        SleepStage(name: "Awake",  durationMinutes: 18,  sourceSkillId: "ouraRing"),   // Awake in bed
    ]

    // Sleep start: 11:15 PM previous night
    private static var sleepStartTime: Date {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return today.addingTimeInterval(-25200 + 75 * 60)  // 7h 15m before start of today (11:15 PM)
    }

    /// Returns one Reading per sleep stage, representing stage duration.
    public static func generateStageReadings() -> [Reading] {
        var readings: [Reading] = []
        readings.reserveCapacity(stages.count)
        var cursor = sleepStartTime

        for stage in stages {
            let stageEnd = cursor.addingTimeInterval(stage.durationMinutes * 60)
            readings.append(
                Reading(
                    metricType: .sleep,
                    value: stage.durationMinutes / 60.0, // Convert to hours
                    unit: "hr",
                    timestamp: cursor,
                    sourceSkillId: stage.sourceSkillId,
                    confidence: 0.90,
                    trendDirection: .stable
                )
            )
            cursor = stageEnd
        }

        return readings
    }

    /// Total sleep duration in hours: 7.2.
    public static var totalSleepHours: Double {
        stages.map { $0.durationMinutes }.reduce(0, +) / 60.0
    }

    /// Summary Reading representing the whole night's sleep.
    public static var summaryReading: Reading {
        Reading(
            metricType: .sleep,
            value: totalSleepHours,
            unit: "hr",
            timestamp: sleepStartTime,
            sourceSkillId: "ouraRing",
            confidence: 0.90,
            trendDirection: .stable
        )
    }
}
