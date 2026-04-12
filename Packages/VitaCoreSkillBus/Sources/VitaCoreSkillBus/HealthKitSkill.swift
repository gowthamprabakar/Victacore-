// HealthKitSkill.swift
// VitaCoreSkillBus — C04 HealthKitSkill.
//
// Sprint 2.B. Reads health data from Apple HealthKit and writes
// normalised `Reading` records to `GraphStoreProtocol` via the SkillBus.
//
// Architecture:
//   1. `requestAuthorization()` — asks for read access to glucose, HR,
//      steps, sleep, BP, weight, SpO2, HRV.
//   2. `startObserving()` — sets up `HKObserverQuery` + background
//      delivery for HR + steps (the highest-frequency metrics).
//   3. `performBackfill(days:)` — pulls the last N days of historical
//      data on first authorization.
//   4. Each observed delivery writes readings to the injected GraphStore.
//
// iOS-only: HealthKit is not available on macOS. This file is guarded
// by `#if canImport(HealthKit)` so VitaCoreSkillBus still compiles
// for macOS test targets.

#if canImport(HealthKit)
import Foundation
import HealthKit
import VitaCoreContracts

// MARK: - HealthKitSkill

public final class HealthKitSkill: @unchecked Sendable {

    private let healthStore: HKHealthStore
    private let graphStore: GraphStoreProtocol
    private let skillBus: VitaCoreSkillBus

    /// The types we request read access for.
    private static let readTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        if let glucose = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) { types.insert(glucose) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let bpSys = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) { types.insert(bpSys) }
        if let bpDia = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) { types.insert(bpDia) }
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(weight) }
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(spo2) }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }()

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(graphStore: GraphStoreProtocol, skillBus: VitaCoreSkillBus) {
        self.healthStore = HKHealthStore()
        self.graphStore = graphStore
        self.skillBus = skillBus

        // Register self as a device skill in the bus.
        skillBus.registerSkill(SkillDescriptor(
            id: "skill.healthKit",
            displayName: "Apple Health",
            iconName: "heart.fill",
            status: .disconnected,
            supportedMetrics: [.glucose, .heartRate, .steps, .sleep,
                               .bloodPressureSystolic, .bloodPressureDiastolic,
                               .weight, .spo2, .heartRateVariability]
        ))
    }

    // -------------------------------------------------------------------------
    // MARK: Authorization
    // -------------------------------------------------------------------------

    /// Requests HealthKit read authorization. Returns true if the user
    /// granted access to at least some types. Updates the skill status
    /// in the bus.
    @discardableResult
    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        try await healthStore.requestAuthorization(
            toShare: [],
            read: Self.readTypes
        )

        // Update skill status in the bus.
        skillBus.registerSkill(SkillDescriptor(
            id: "skill.healthKit",
            displayName: "Apple Health",
            iconName: "heart.fill",
            status: .connected,
            lastSyncDescription: "Just authorised",
            confidence: 0.95,
            supportedMetrics: [.glucose, .heartRate, .steps, .sleep,
                               .bloodPressureSystolic, .bloodPressureDiastolic,
                               .weight, .spo2, .heartRateVariability]
        ))

        return true
    }

    // -------------------------------------------------------------------------
    // MARK: Background Observers (AD-04 path 1)
    // -------------------------------------------------------------------------

    /// Starts HKObserverQuery + background delivery for heart rate and
    /// step count. These are the highest-frequency metrics that benefit
    /// from push-style delivery via Apple Watch.
    public func startObserving() {
        observeQuantity(.heartRate, metric: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        observeQuantity(.stepCount, metric: .steps, unit: HKUnit.count())

        // Enable background delivery so we get woken up even when
        // the app is suspended. AD-04: HealthKit observer = primary path.
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in }
        }
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
        }
    }

    private func observeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        metric: MetricType,
        unit: HKUnit
    ) {
        guard let qType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        let query = HKObserverQuery(sampleType: qType, predicate: nil) { [weak self] _, completionHandler, _ in
            guard let self else { completionHandler(); return }
            Task {
                await self.fetchLatest(type: qType, metric: metric, unit: unit, limit: 10)
                completionHandler()
            }
        }
        healthStore.execute(query)
    }

    // -------------------------------------------------------------------------
    // MARK: Historical Backfill
    // -------------------------------------------------------------------------

    /// Pulls the last `days` days of data for all authorised metric types.
    /// Called once after authorization to seed the graph with historical data.
    public func performBackfill(days: Int = 14) async {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // Glucose
        if let t = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
            await fetchRange(type: t, metric: .glucose, unit: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)), from: start)
        }
        // Heart rate
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            await fetchRange(type: t, metric: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start)
        }
        // Steps
        if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            await fetchRange(type: t, metric: .steps, unit: HKUnit.count(), from: start)
        }
        // BP systolic
        if let t = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            await fetchRange(type: t, metric: .bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), from: start)
        }
        // BP diastolic
        if let t = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            await fetchRange(type: t, metric: .bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), from: start)
        }
        // Weight
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            await fetchRange(type: t, metric: .weight, unit: HKUnit.gramUnit(with: .kilo), from: start)
        }
        // SpO2
        if let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            await fetchRange(type: t, metric: .spo2, unit: HKUnit.percent(), from: start)
        }

        // Update sync timestamp
        skillBus.registerSkill(SkillDescriptor(
            id: "skill.healthKit",
            displayName: "Apple Health",
            iconName: "heart.fill",
            status: .connected,
            lastSyncDescription: "Backfill complete",
            confidence: 0.95,
            supportedMetrics: [.glucose, .heartRate, .steps, .sleep,
                               .bloodPressureSystolic, .bloodPressureDiastolic,
                               .weight, .spo2, .heartRateVariability]
        ))
    }

    // -------------------------------------------------------------------------
    // MARK: HealthKit → Reading conversion
    // -------------------------------------------------------------------------

    private func fetchLatest(
        type: HKQuantityType,
        metric: MetricType,
        unit: HKUnit,
        limit: Int
    ) async {
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),
            end: Date(),
            options: .strictEndDate
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDesc]
            ) { [weak self] _, samples, _ in
                guard let self, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                Task {
                    let readings = samples.map { sample in
                        Reading(
                            metricType: metric,
                            value: sample.quantity.doubleValue(for: unit),
                            unit: metric.unit,
                            timestamp: sample.endDate,
                            sourceSkillId: "skill.healthKit.\(sample.sourceRevision.source.bundleIdentifier)",
                            confidence: 0.95,
                            trendDirection: .stable
                        )
                    }
                    if !readings.isEmpty {
                        try? await self.graphStore.writeReadings(readings)
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchRange(
        type: HKQuantityType,
        metric: MetricType,
        unit: HKUnit,
        from start: Date
    ) async {
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDesc]
            ) { [weak self] _, samples, _ in
                guard let self, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                Task {
                    // Batch in chunks of 500 to stay within GraphStore batch SLA.
                    let readings = samples.map { sample in
                        Reading(
                            metricType: metric,
                            value: sample.quantity.doubleValue(for: unit),
                            unit: metric.unit,
                            timestamp: sample.endDate,
                            sourceSkillId: "skill.healthKit.\(sample.sourceRevision.source.bundleIdentifier)",
                            confidence: 0.95,
                            trendDirection: .stable
                        )
                    }
                    for chunk in readings.chunked(into: 500) {
                        try? await self.graphStore.writeReadings(chunk)
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#endif // canImport(HealthKit)
