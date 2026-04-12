import Foundation
import VitaCoreContracts

public final class MockAlertRouter: AlertRouterProtocol {

    public init() {}

    // MARK: - Static Alert History (12 alerts over 7 days)

    private static let alertHistory: [AlertEvent] = {
        let now = Date()
        func daysAgo(_ n: Double) -> Date { now.addingTimeInterval(-n * 86400) }
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

        return [
            // CRITICAL: glucose 65 mg/dL falling fast, 2 days ago, acknowledged
            AlertEvent(
                urgency: .critical,
                metricType: .glucose,
                value: 65,
                trendDirection: .fallingFast,
                explanation: "Glucose critically low at 65 mg/dL and falling fast. Immediate action required.",
                evidence: ["65 mg/dL < critical threshold 70 mg/dL", "Trend: falling fast at -2.1 mg/dL/min"],
                timestamp: daysAgo(2),
                acknowledgedAt: daysAgo(2).addingTimeInterval(120),
                userAction: .acknowledged
            ),

            // ALERT: BP 158/98, 3 days ago
            AlertEvent(
                urgency: .alert,
                metricType: .bloodPressureSystolic,
                value: 158,
                trendDirection: .rising,
                explanation: "Blood pressure elevated at 158/98 mmHg. This exceeds your alert threshold.",
                evidence: ["158 mmHg > alert upper limit 140 mmHg"],
                timestamp: daysAgo(3),
                acknowledgedAt: daysAgo(3).addingTimeInterval(600),
                userAction: .acknowledged
            ),

            // ALERT: HR 112 sustained, 5 days ago
            AlertEvent(
                urgency: .alert,
                metricType: .heartRate,
                value: 112,
                trendDirection: .stable,
                explanation: "Heart rate sustained at 112 bpm at rest for more than 10 minutes.",
                evidence: ["112 bpm > alert threshold 100 bpm", "Duration: 12 minutes at rest"],
                timestamp: daysAgo(5),
                acknowledgedAt: daysAgo(5).addingTimeInterval(300),
                userAction: .acknowledged
            ),

            // WATCH: glucose 195 post-meal (instance 1)
            AlertEvent(
                urgency: .watch,
                metricType: .glucose,
                value: 195,
                trendDirection: .rising,
                explanation: "Post-meal glucose reached 195 mg/dL — above your personal watch threshold.",
                evidence: ["195 mg/dL > watch upper limit 180 mg/dL", "Context: 90 min post-lunch"],
                timestamp: daysAgo(1)
            ),

            // WATCH: glucose 195 post-meal (instance 2)
            AlertEvent(
                urgency: .watch,
                metricType: .glucose,
                value: 188,
                trendDirection: .rising,
                explanation: "Post-meal glucose reached 188 mg/dL — above your personal watch threshold.",
                evidence: ["188 mg/dL > watch upper limit 180 mg/dL", "Context: 75 min post-breakfast"],
                timestamp: daysAgo(2).addingTimeInterval(7200)
            ),

            // WATCH: glucose 195 post-meal (instance 3)
            AlertEvent(
                urgency: .watch,
                metricType: .glucose,
                value: 192,
                trendDirection: .stable,
                explanation: "Post-meal glucose reached 192 mg/dL — above your personal watch threshold.",
                evidence: ["192 mg/dL > watch upper limit 180 mg/dL", "Context: 80 min post-dinner"],
                timestamp: daysAgo(4).addingTimeInterval(68400)
            ),

            // WATCH: inactivity >90 min post-meal (instance 1)
            AlertEvent(
                urgency: .watch,
                metricType: .inactivityDuration,
                value: 95,
                trendDirection: .rising,
                explanation: "You've been inactive for 95 minutes after your last meal. A short walk would help.",
                evidence: ["95 min inactivity > 90 min post-meal target", "Last meal: 95 min ago"],
                timestamp: daysAgo(1).addingTimeInterval(14400)
            ),

            // WATCH: inactivity >90 min post-meal (instance 2)
            AlertEvent(
                urgency: .watch,
                metricType: .inactivityDuration,
                value: 102,
                trendDirection: .rising,
                explanation: "You've been inactive for 102 minutes after your last meal.",
                evidence: ["102 min inactivity > 90 min post-meal target"],
                timestamp: daysAgo(3).addingTimeInterval(50400)
            ),

            // WATCH: fluid <1L by 3pm (instance 1)
            AlertEvent(
                urgency: .watch,
                metricType: .fluidIntake,
                value: 650,
                trendDirection: .stable,
                explanation: "Only 650 mL of fluid logged by 3 PM. Aim for at least 1,000 mL by mid-afternoon.",
                evidence: ["650 mL < 1,000 mL mid-afternoon target"],
                timestamp: daysAgo(2).addingTimeInterval(54000) // 3pm 2 days ago
            ),

            // WATCH: fluid <1L by 3pm (instance 2)
            AlertEvent(
                urgency: .watch,
                metricType: .fluidIntake,
                value: 820,
                trendDirection: .stable,
                explanation: "820 mL of fluid logged by 3 PM — slightly under your mid-afternoon target.",
                evidence: ["820 mL < 1,000 mL mid-afternoon target"],
                timestamp: daysAgo(6).addingTimeInterval(54000)
            ),

            // WATCH: sleep <6h
            AlertEvent(
                urgency: .watch,
                metricType: .sleep,
                value: 5.4,
                trendDirection: .falling,
                explanation: "Last night's sleep was 5.4 hours — below your 7-hour target.",
                evidence: ["5.4 hr < sleep goal 7 hr"],
                timestamp: daysAgo(5).addingTimeInterval(28800) // 8am 5 days ago
            ),

            // INFO: weekly digest
            AlertEvent(
                urgency: .info,
                metricType: .glucose,
                value: 138,
                trendDirection: .stable,
                explanation: "Your weekly health digest is ready. Average glucose was 138 mg/dL with TIR at 84%.",
                evidence: ["7-day average glucose: 138 mg/dL", "Time in range: 84%"],
                timestamp: daysAgo(7)
            )
        ]
    }()

    // MARK: - AlertRouterProtocol

    public func getAlertHistory(days: Int) async throws -> [AlertEvent] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return Self.alertHistory.filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func getRecentAlerts(limit: Int) async throws -> [AlertEvent] {
        Array(
            Self.alertHistory
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    public func acknowledgeAlert(id: UUID) async throws {
        print("[MockAlertRouter] acknowledgeAlert: \(id)")
    }

    public func route(_ payload: AlertDeliveryPayload) async {
        print("[MockAlertRouter] route: \(payload.event.urgency.rawValue) — \(payload.event.explanation)")
    }

    public func unacknowledgedCount(minimumUrgency: AlertBand) async -> Int {
        Self.alertHistory
            .filter { !$0.isAcknowledged && $0.urgency.priority >= minimumUrgency.priority }
            .count
    }

    public func purgeAlerts(olderThan days: Int) async throws {
        print("[MockAlertRouter] purgeAlerts olderThan \(days) days — no-op in mock")
    }
}
