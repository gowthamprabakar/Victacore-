import Foundation
import VitaCoreContracts

/// Generates 60 blood-pressure readings (systolic + diastolic pairs) over 30 days.
/// Simulates mild-to-moderate hypertension in a T2D patient on Lisinopril.
public enum MockBPData {

    // Base systolic / diastolic values with daily variation
    private static let baseSystolic: Double = 128
    private static let baseDiastolic: Double = 82

    /// Returns all 60 readings (30 systolic + 30 diastolic — one measurement pair per day).
    public static func generate() -> [Reading] {
        var readings: [Reading] = []
        readings.reserveCapacity(60)

        let now = Date()

        for dayOffset in 0..<30 {
            // Morning measurement — typically higher
            let baseTime = now.addingTimeInterval(-Double(dayOffset) * 86400)

            // Simulate day-to-day BP variability
            let seed = Double(dayOffset)
            let systolicVariation = 8.0 * sin(seed * 0.7) + 4.0 * cos(seed * 1.3)
            let diastolicVariation = 4.0 * sin(seed * 0.9) + 2.0 * cos(seed * 1.1)

            // Occasional higher readings (3 in 30 days)
            let spikeBonus: Double
            switch dayOffset {
            case 3:  spikeBonus = 30   // BP spike: 158/98
            case 8:  spikeBonus = 18
            case 20: spikeBonus = 12
            default: spikeBonus = 0
            }

            let systolic = (baseSystolic + systolicVariation + spikeBonus).rounded()
            let diastolic = (baseDiastolic + diastolicVariation + spikeBonus * 0.6).rounded()

            readings.append(
                Reading(
                    metricType: .bloodPressureSystolic,
                    value: systolic,
                    unit: "mmHg",
                    timestamp: baseTime,
                    sourceSkillId: "withingsBPM",
                    confidence: 0.91,
                    trendDirection: spikeBonus > 0 ? .risingFast : .stable
                )
            )

            readings.append(
                Reading(
                    metricType: .bloodPressureDiastolic,
                    value: diastolic,
                    unit: "mmHg",
                    timestamp: baseTime,
                    sourceSkillId: "withingsBPM",
                    confidence: 0.91,
                    trendDirection: spikeBonus > 0 ? .rising : .stable
                )
            )
        }

        return readings.sorted { $0.timestamp < $1.timestamp }
    }
}
