import Foundation
import VitaCoreContracts

public final class MockGraphStore: GraphStoreProtocol {

    public init() {}

    // MARK: - getLatestReading

    public func getLatestReading(for metricType: MetricType) async throws -> Reading? {
        let now = Date()
        switch metricType {
        case .glucose:
            return Reading(
                metricType: .glucose,
                value: 142,
                unit: "mg/dL",
                timestamp: now.addingTimeInterval(-300),
                sourceSkillId: "dexcomG7",
                confidence: 0.95,
                trendDirection: .stable,
                trendVelocity: -0.3
            )
        case .bloodPressureSystolic:
            return Reading(
                metricType: .bloodPressureSystolic,
                value: 124,
                unit: "mmHg",
                timestamp: now.addingTimeInterval(-7200),
                sourceSkillId: "withingsBPM",
                confidence: 0.91,
                trendDirection: .stable
            )
        case .bloodPressureDiastolic:
            return Reading(
                metricType: .bloodPressureDiastolic,
                value: 82,
                unit: "mmHg",
                timestamp: now.addingTimeInterval(-7200),
                sourceSkillId: "withingsBPM",
                confidence: 0.91,
                trendDirection: .stable
            )
        case .heartRate:
            return Reading(
                metricType: .heartRate,
                value: 68,
                unit: "bpm",
                timestamp: now.addingTimeInterval(-60),
                sourceSkillId: "appleWatch",
                confidence: 0.92,
                trendDirection: .stable
            )
        case .heartRateVariability:
            return Reading(
                metricType: .heartRateVariability,
                value: 42,
                unit: "ms",
                timestamp: now.addingTimeInterval(-3600),
                sourceSkillId: "ouraRing",
                confidence: 0.90,
                trendDirection: .stable
            )
        case .spo2:
            return Reading(
                metricType: .spo2,
                value: 98,
                unit: "%",
                timestamp: now.addingTimeInterval(-600),
                sourceSkillId: "appleWatch",
                confidence: 0.92,
                trendDirection: .stable
            )
        case .steps:
            return Reading(
                metricType: .steps,
                value: 7520,
                unit: "steps",
                timestamp: now,
                sourceSkillId: "appleWatch",
                confidence: 0.92,
                trendDirection: .rising
            )
        case .sleep:
            return Reading(
                metricType: .sleep,
                value: 7.2,
                unit: "hr",
                timestamp: now.addingTimeInterval(-25200),
                sourceSkillId: "ouraRing",
                confidence: 0.90,
                trendDirection: .stable
            )
        case .fluidIntake:
            return Reading(
                metricType: .fluidIntake,
                value: 1200,
                unit: "mL",
                timestamp: now.addingTimeInterval(-1800),
                sourceSkillId: "manual",
                confidence: 1.0,
                trendDirection: .stable
            )
        case .calories:
            return Reading(
                metricType: .calories,
                value: 1450,
                unit: "kcal",
                timestamp: now,
                sourceSkillId: "manual",
                confidence: 0.85,
                trendDirection: .rising
            )
        case .carbs:
            return Reading(
                metricType: .carbs,
                value: 165,
                unit: "g",
                timestamp: now,
                sourceSkillId: "manual",
                confidence: 0.85,
                trendDirection: .stable
            )
        case .protein:
            return Reading(
                metricType: .protein,
                value: 72,
                unit: "g",
                timestamp: now,
                sourceSkillId: "manual",
                confidence: 0.85,
                trendDirection: .stable
            )
        case .fat:
            return Reading(
                metricType: .fat,
                value: 48,
                unit: "g",
                timestamp: now,
                sourceSkillId: "manual",
                confidence: 0.85,
                trendDirection: .stable
            )
        case .inactivityDuration:
            return Reading(
                metricType: .inactivityDuration,
                value: 45,
                unit: "min",
                timestamp: now.addingTimeInterval(-900),
                sourceSkillId: "appleWatch",
                confidence: 0.92,
                trendDirection: .rising
            )
        case .weight:
            return Reading(
                metricType: .weight,
                value: 82.4,
                unit: "kg",
                timestamp: now.addingTimeInterval(-86400),
                sourceSkillId: "manual",
                confidence: 1.0,
                trendDirection: .stable
            )
        }
    }

    // MARK: - getRangeReadings

    public func getRangeReadings(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Reading] {
        switch metricType {
        case .glucose:
            return MockGlucoseData.generate()
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return MockBPData.generate().filter { $0.metricType == metricType }
        case .steps:
            return MockActivityData.generateHourlyBuckets()
        case .sleep:
            return MockSleepData.generateStageReadings()
        default:
            // Return a pair of boundary readings for unsupported range queries
            guard let latest = try? await getLatestReading(for: metricType) else { return [] }
            return [latest]
        }
    }

    // MARK: - getAggregatedMetric

    public func getAggregatedMetric(
        for metricType: MetricType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> AggregatedMetric? {
        let windowDuration = endDate.timeIntervalSince(startDate)
        switch metricType {
        case .glucose:
            return AggregatedMetric(
                metricType: .glucose,
                min: 82,
                max: 198,
                average: 138,
                count: 288,
                windowStart: startDate,
                windowEnd: endDate
            )
        case .bloodPressureSystolic:
            return AggregatedMetric(
                metricType: .bloodPressureSystolic,
                min: 116,
                max: 158,
                average: 128,
                count: 30,
                windowStart: startDate,
                windowEnd: endDate
            )
        case .bloodPressureDiastolic:
            return AggregatedMetric(
                metricType: .bloodPressureDiastolic,
                min: 74,
                max: 98,
                average: 82,
                count: 30,
                windowStart: startDate,
                windowEnd: endDate
            )
        case .heartRate:
            return AggregatedMetric(
                metricType: .heartRate,
                min: 52,
                max: 112,
                average: 68,
                count: 144,
                windowStart: startDate,
                windowEnd: endDate
            )
        case .steps:
            return AggregatedMetric(
                metricType: .steps,
                min: 3200,
                max: 12800,
                average: 7520,
                count: 7,
                windowStart: startDate,
                windowEnd: endDate
            )
        case .sleep:
            return AggregatedMetric(
                metricType: .sleep,
                min: 5.8,
                max: 8.2,
                average: 7.1,
                count: 7,
                windowStart: startDate,
                windowEnd: endDate
            )
        default:
            return AggregatedMetric(
                metricType: metricType,
                min: 0,
                max: 100,
                average: 50,
                count: Int(windowDuration / 3600),
                windowStart: startDate,
                windowEnd: endDate
            )
        }
    }

    // MARK: - getCurrentSnapshot

    public func getCurrentSnapshot() async throws -> MonitoringSnapshot {
        let glucose = try await getLatestReading(for: .glucose)
        let bpSys = try await getLatestReading(for: .bloodPressureSystolic)
        let bpDia = try await getLatestReading(for: .bloodPressureDiastolic)
        let hr = try await getLatestReading(for: .heartRate)
        let hrv = try await getLatestReading(for: .heartRateVariability)
        let spo2 = try await getLatestReading(for: .spo2)
        let steps = try await getLatestReading(for: .steps)
        let sleep = try await getLatestReading(for: .sleep)
        let fluid = try await getLatestReading(for: .fluidIntake)
        let calories = try await getLatestReading(for: .calories)
        let carbs = try await getLatestReading(for: .carbs)
        let protein = try await getLatestReading(for: .protein)
        let fat = try await getLatestReading(for: .fat)
        let inactivity = try await getLatestReading(for: .inactivityDuration)
        let weight = try await getLatestReading(for: .weight)

        return MonitoringSnapshot(
            glucose: glucose,
            glucoseTrend: .stable,
            bloodPressureSystolic: bpSys,
            bloodPressureDiastolic: bpDia,
            heartRate: hr,
            heartRateVariability: hrv,
            spo2: spo2,
            steps: steps,
            inactivityDuration: inactivity,
            sleep: sleep,
            fluidIntake: fluid,
            calories: calories,
            carbs: carbs,
            protein: protein,
            fat: fat,
            weight: weight,
            dataQuality: .good,
            timestamp: Date(),
            evaluationAge: 300
        )
    }

    // MARK: - Write Methods

    public func writeReading(_ reading: Reading) async throws {
        // No-op for mock — data is static
    }

    public func writeReadings(_ readings: [Reading]) async throws {
        // No-op for mock
    }

    // MARK: - Episodes

    public func getEpisodes(
        from startDate: Date,
        to endDate: Date,
        types: [EpisodeType]
    ) async throws -> [Episode] {
        // Return a small set of representative mock episodes
        let now = Date()
        let payload = Data("{\"value\":\"mock\"}".utf8)
        let filtered = EpisodeType.allCases
            .filter { types.isEmpty || types.contains($0) }
            .prefix(5)
            .enumerated()
            .map { idx, type in
                Episode(
                    episodeType: type,
                    sourceSkillId: "mock",
                    sourceConfidence: 0.90,
                    referenceTime: now.addingTimeInterval(Double(-idx) * 3600),
                    ingestionTime: now,
                    payload: payload
                )
            }
        return Array(filtered)
    }

    public func writeEpisode(_ episode: Episode) async throws {
        // No-op for mock
    }

    public func purgeReadings(for metricType: MetricType, olderThan date: Date) async throws {
        // No-op for mock
    }
}
