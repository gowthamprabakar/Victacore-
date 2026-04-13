// HeartbeatEngine.swift
// VitaCoreHeartbeat — C09 HeartbeatEngine Lite.
//
// Sprint 3.A. The monitoring loop:
//   1. Polls GraphStore every `cycleInterval` seconds when foregrounded.
//   2. Evaluates latest readings against resolved ThresholdSet.
//   3. Detects threshold crossings (safe→watch, watch→alert, alert→critical).
//   4. On crossing: builds an InferenceRequest, calls onThresholdCrossing.
//   5. Fast-path: glucose <70 or HR >120/<40 → immediate alert callback.
//   6. Writes MONITORING_RESULT episodes to GraphStore for audit trail.
//
// This is a "lite" engine — no BGAppRefreshTask (requires app target
// entitlement), no absence-of-event rules (Sprint 3.B MiroFish owns
// those), no alert fatigue manager. Those are Phase 3 completion items.

import Foundation
import VitaCoreContracts
import VitaCoreThreshold

// MARK: - ThresholdCrossing

/// Represents a detected threshold band change for a metric.
public struct ThresholdCrossing: Sendable, Hashable {
    public let metricType: MetricType
    public let previousBand: ThresholdBand
    public let currentBand: ThresholdBand
    public let currentValue: Double
    public let timestamp: Date

    public var isEscalation: Bool {
        currentBand.priority > previousBand.priority
    }
}

// MARK: - AlertLevel

/// Alert urgency for dispatch to the UI / notification system.
public enum AlertLevel: String, Sendable, Hashable, CaseIterable {
    case watch      // In-app banner, auto-dismiss 6s
    case alert      // Bottom sheet, swipe-to-dismiss
    case critical   // Full-screen red modal, no swipe-dismiss, heavy haptic

    public init(from band: ThresholdBand) {
        switch band {
        case .safe:     self = .watch  // shouldn't happen, but safe default
        case .watch:    self = .watch
        case .alert:    self = .alert
        case .critical: self = .critical
        }
    }
}

// MARK: - HeartbeatAlert

/// An alert event ready for dispatch to the UI layer.
public struct HeartbeatAlert: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let level: AlertLevel
    public let metricType: MetricType
    public let value: Double
    public let unit: String
    public let band: ThresholdBand
    public let message: String
    public let timestamp: Date
    public let isFastPath: Bool

    public init(
        level: AlertLevel, metricType: MetricType, value: Double,
        unit: String, band: ThresholdBand, message: String,
        timestamp: Date = Date(), isFastPath: Bool = false
    ) {
        self.id = UUID()
        self.level = level
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.band = band
        self.message = message
        self.timestamp = timestamp
        self.isFastPath = isFastPath
    }
}

// MARK: - HeartbeatEngine

public final class HeartbeatEngine: @unchecked Sendable {

    public let graphStore: GraphStoreProtocol
    private let thresholdEngine: VitaCoreThresholdEngine
    private let cycleInterval: TimeInterval

    /// Previous band per metric — used to detect crossings.
    private var previousBands: [MetricType: ThresholdBand] = [:]

    /// Callback fired on threshold crossing. The app wires this to
    /// the alert presentation layer and/or MiroFish analysis trigger.
    public var onAlert: (@Sendable (HeartbeatAlert) -> Void)?

    /// Callback fired with the full InferenceRequest when a crossing
    /// is detected, so MiroFish can generate a prescription card.
    public var onInferenceRequest: (@Sendable (InferenceRequest) -> Void)?

    /// The metrics we monitor on each cycle.
    private static let monitoredMetrics: [MetricType] = [
        .glucose, .heartRate, .bloodPressureSystolic,
        .bloodPressureDiastolic, .spo2
    ]

    private var monitorTask: Task<Void, Never>?

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        graphStore: GraphStoreProtocol,
        thresholdEngine: VitaCoreThresholdEngine,
        cycleInterval: TimeInterval = 60
    ) {
        self.graphStore = graphStore
        self.thresholdEngine = thresholdEngine
        self.cycleInterval = cycleInterval
    }

    // -------------------------------------------------------------------------
    // MARK: Lifecycle
    // -------------------------------------------------------------------------

    /// Starts the foreground monitoring loop. Call from `onAppear` or
    /// `scenePhase == .active`.
    public func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runCycle()
                try? await Task.sleep(for: .seconds(self?.cycleInterval ?? 60))
            }
        }
    }

    /// Stops the monitoring loop. Call from `scenePhase == .background`.
    public func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // -------------------------------------------------------------------------
    // MARK: Monitoring Cycle
    // -------------------------------------------------------------------------

    /// Runs one evaluation cycle: read latest → classify → detect crossings.
    public func runCycle() async {
        do {
            let thresholdSet = try await thresholdEngine.resolveActiveThresholdSet()

            for metric in Self.monitoredMetrics {
                guard let reading = try await graphStore.getLatestReading(for: metric) else {
                    continue
                }

                let band = thresholdSet.classify(value: reading.value, for: metric)
                let prevBand = previousBands[metric] ?? .safe

                // Fast-path alerts (AD-08): bypass crossing logic.
                if metric == .glucose && reading.value < 70 {
                    fireAlert(HeartbeatAlert(
                        level: .critical,
                        metricType: .glucose,
                        value: reading.value,
                        unit: reading.unit,
                        band: .critical,
                        message: "Glucose \(Int(reading.value)) mg/dL — possible hypoglycemia. Follow your hypo protocol.",
                        isFastPath: true
                    ))
                } else if metric == .heartRate && (reading.value > 120 || reading.value < 40) {
                    fireAlert(HeartbeatAlert(
                        level: .alert,
                        metricType: .heartRate,
                        value: reading.value,
                        unit: reading.unit,
                        band: band,
                        message: "Heart rate \(Int(reading.value)) bpm is outside normal resting range.",
                        isFastPath: true
                    ))
                }

                // Threshold crossing detection.
                if band != prevBand && band.priority > prevBand.priority {
                    let crossing = ThresholdCrossing(
                        metricType: metric,
                        previousBand: prevBand,
                        currentBand: band,
                        currentValue: reading.value,
                        timestamp: reading.timestamp
                    )

                    fireAlert(HeartbeatAlert(
                        level: AlertLevel(from: band),
                        metricType: metric,
                        value: reading.value,
                        unit: reading.unit,
                        band: band,
                        message: "\(metric.displayName) crossed from \(prevBand.rawValue) to \(band.rawValue): \(Int(reading.value)) \(reading.unit)"
                    ))

                    // Build InferenceRequest for MiroFish.
                    await buildAndDispatchInferenceRequest(crossing: crossing)
                }

                previousBands[metric] = band
            }

            // Write monitoring result episode for audit trail.
            let monitorEpisode = Episode(
                episodeType: .monitoringResult,
                sourceSkillId: "engine.heartbeat",
                sourceConfidence: 1.0,
                referenceTime: Date(),
                payload: encodePayload([
                    "metrics_checked": Self.monitoredMetrics.count,
                    "cycle_interval": cycleInterval
                ])
            )
            try? await graphStore.writeEpisode(monitorEpisode)

        } catch {
            print("⚠️ HeartbeatEngine cycle error: \(error)")
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Alert Dispatch
    // -------------------------------------------------------------------------

    private func fireAlert(_ alert: HeartbeatAlert) {
        onAlert?(alert)
    }

    private func buildAndDispatchInferenceRequest(crossing: ThresholdCrossing) async {
        guard let onInferenceRequest else { return }
        do {
            let snapshot = try await graphStore.getCurrentSnapshot()
            let thresholdSet = try await thresholdEngine.resolveActiveThresholdSet()
            // We need PersonaContext but HeartbeatEngine doesn't hold PersonaEngine
            // directly — the onInferenceRequest callback's consumer (VitaCoreApp)
            // attaches it. For now, use a minimal request.
            let request = InferenceRequest(
                persona: PersonaContext(userId: UUID()),
                snapshot: snapshot,
                thresholdSet: thresholdSet,
                recentEpisodes: [],
                requestedAt: Date(),
                stalenessThreshold: 300,
                conversationalOverride: "Threshold crossing detected: \(crossing.metricType.displayName) is now \(crossing.currentBand.rawValue) at \(Int(crossing.currentValue)) \(crossing.metricType.unit)",
                temperatureHint: 0.5
            )
            onInferenceRequest(request)
        } catch {
            print("⚠️ HeartbeatEngine: failed to build InferenceRequest: \(error)")
        }
    }

    private func encodePayload(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}
