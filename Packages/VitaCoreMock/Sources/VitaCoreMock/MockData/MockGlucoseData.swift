import Foundation
import VitaCoreContracts

/// Generates 288 glucose readings covering a 24-hour period at 5-minute intervals.
/// Simulates a realistic T2D glucose curve for the demo persona (Praba).
public enum MockGlucoseData {

    /// Returns 288 readings from midnight to 11:55 PM anchored to today.
    public static func generate() -> [Reading] {
        var readings: [Reading] = []
        readings.reserveCapacity(288)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Baseline values at key time points (minute offset from midnight, glucose mg/dL)
        // Segments are linearly interpolated between control points.
        let controlPoints: [(minuteOffset: Int, value: Double)] = [
            (0,    95),   // midnight — fasting
            (120,  90),   // 2am — nadir
            (360,  95),   // 6am — waking fasting
            (450,  108),  // 7:30am — pre-breakfast rise
            (480,  140),  // 8:00am — breakfast spike starts
            (510,  165),  // 8:30am — peak post-breakfast
            (540,  155),  // 9:00am — beginning descent
            (600,  120),  // 10:00am — back toward range
            (690,  115),  // 11:30am — pre-lunch plateau
            (720,  130),  // 12:00pm — lunch starts
            (750,  185),  // 12:30pm — lunch peak
            (810,  168),  // 1:30pm — descending
            (840,  142),  // 2:00pm — current value (mock "now")
            (870,  130),  // 2:30pm — continuing down
            (930,  118),  // 3:30pm — near target
            (1020, 115),  // 5:00pm — stable afternoon
            (1080, 120),  // 6:00pm — pre-dinner
            (1110, 145),  // 6:30pm — dinner
            (1140, 172),  // 7:00pm — dinner peak
            (1200, 150),  // 8:00pm — descent
            (1260, 128),  // 9:00pm — evening
            (1320, 110),  // 10:00pm — bedtime approach
            (1380, 100),  // 11:00pm — settling
            (1435, 96)    // 11:55pm — end of day
        ]

        for intervalIndex in 0..<288 {
            let minuteOffset = intervalIndex * 5
            let timestamp = today.addingTimeInterval(Double(minuteOffset) * 60)
            let value = interpolateGlucose(at: minuteOffset, controlPoints: controlPoints)

            // Compute trend from adjacent readings
            let prevValue = intervalIndex > 0
                ? interpolateGlucose(at: (intervalIndex - 1) * 5, controlPoints: controlPoints)
                : value
            let nextValue = intervalIndex < 287
                ? interpolateGlucose(at: (intervalIndex + 1) * 5, controlPoints: controlPoints)
                : value
            let velocity = (nextValue - prevValue) / 10.0  // mg/dL per minute

            let trend: TrendDirection
            switch velocity {
            case let v where v > 2.0:   trend = .risingFast
            case let v where v > 0.5:   trend = .rising
            case let v where v < -2.0:  trend = .fallingFast
            case let v where v < -0.5:  trend = .falling
            default:                     trend = .stable
            }

            readings.append(
                Reading(
                    metricType: .glucose,
                    value: value.rounded(),
                    unit: "mg/dL",
                    timestamp: timestamp,
                    sourceSkillId: "dexcomG7",
                    confidence: 0.95,
                    trendDirection: trend,
                    trendVelocity: velocity
                )
            )
        }

        return readings
    }

    // MARK: - Private helpers

    private static func interpolateGlucose(
        at minuteOffset: Int,
        controlPoints: [(minuteOffset: Int, value: Double)]
    ) -> Double {
        guard !controlPoints.isEmpty else { return 100 }

        // Find bracketing points
        var lower = controlPoints[0]
        var upper = controlPoints[controlPoints.count - 1]

        for i in 0..<(controlPoints.count - 1) {
            let a = controlPoints[i]
            let b = controlPoints[i + 1]
            if minuteOffset >= a.minuteOffset && minuteOffset <= b.minuteOffset {
                lower = a
                upper = b
                break
            }
        }

        if lower.minuteOffset == upper.minuteOffset {
            return lower.value
        }

        let t = Double(minuteOffset - lower.minuteOffset) /
                Double(upper.minuteOffset - lower.minuteOffset)
        // Add a small physiological noise term (±2 mg/dL sinusoidal)
        let noise = 2.0 * sin(Double(minuteOffset) * 0.15)
        return lower.value + t * (upper.value - lower.value) + noise
    }
}
