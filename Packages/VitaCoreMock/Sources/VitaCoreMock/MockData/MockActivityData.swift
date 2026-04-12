import Foundation
import VitaCoreContracts

/// Generates hourly step-count buckets for a single day, totalling 7,520 steps.
public enum MockActivityData {

    // Distribution of steps across 24 hours (index = hour 0–23)
    // Total sums to 7,520 steps
    private static let hourlyDistribution: [Double] = [
        0,    // 00:00 — asleep
        0,    // 01:00
        0,    // 02:00
        0,    // 03:00
        0,    // 04:00
        120,  // 05:00 — early wakeup
        380,  // 06:00 — morning walk
        620,  // 07:00 — commute / gym
        480,  // 08:00 — post-breakfast activity
        320,  // 09:00 — light movement
        250,  // 10:00
        180,  // 11:00 — desk work
        400,  // 12:00 — lunch walk
        350,  // 13:00
        210,  // 14:00 — current hour (partial)
        280,  // 15:00
        320,  // 16:00
        480,  // 17:00 — evening walk
        560,  // 18:00
        380,  // 19:00
        290,  // 20:00
        180,  // 21:00
        90,   // 22:00
        30    // 23:00 — winding down
    ]

    /// Returns one Reading per hour, each holding that hour's cumulative step count.
    public static func generateHourlyBuckets() -> [Reading] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return hourlyDistribution.enumerated().map { hour, steps in
            let timestamp = today.addingTimeInterval(Double(hour) * 3600)
            return Reading(
                metricType: .steps,
                value: steps,
                unit: "steps",
                timestamp: timestamp,
                sourceSkillId: "appleWatch",
                confidence: 0.92,
                trendDirection: steps > 300 ? .rising : .stable
            )
        }
    }

    /// Total steps across the day — 7,520.
    public static var totalSteps: Double {
        hourlyDistribution.reduce(0, +)
    }
}
