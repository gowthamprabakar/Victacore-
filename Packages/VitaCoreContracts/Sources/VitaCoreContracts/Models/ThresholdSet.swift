import Foundation

// MARK: - ThresholdBand

/// Severity classification for a metric value relative to safe operating ranges.
public enum ThresholdBand: String, Codable, Sendable, Hashable, CaseIterable {
    case safe
    case watch
    case alert
    case critical

    public var priority: Int {
        switch self {
        case .safe:     return 0
        case .watch:    return 1
        case .alert:    return 2
        case .critical: return 3
        }
    }
}

// MARK: - MetricThreshold

/// Defines the tiered safety bands for a single metric.
public struct MetricThreshold: Identifiable, Codable, Sendable, Hashable {
    public var id: MetricType { metricType }
    public let metricType: MetricType
    /// The ideal operating range — values here are `safe`.
    public let safeBand: ClosedRange<Double>
    /// Values here warrant increased monitoring.
    public let watchBand: ClosedRange<Double>
    /// Values here require a user alert.
    public let alertBand: ClosedRange<Double>
    /// Values here trigger emergency guidance.
    public let criticalBand: ClosedRange<Double>
    /// Higher priority thresholds override lower ones when composing threshold sets.
    public let priority: Int

    public init(
        metricType: MetricType,
        safeBand: ClosedRange<Double>,
        watchBand: ClosedRange<Double>,
        alertBand: ClosedRange<Double>,
        criticalBand: ClosedRange<Double>,
        priority: Int = 0
    ) {
        self.metricType = metricType
        self.safeBand = safeBand
        self.watchBand = watchBand
        self.alertBand = alertBand
        self.criticalBand = criticalBand
        self.priority = priority
    }

    /// Classifies a scalar value against the defined bands.
    /// Bands are checked from tightest (safe) to widest (critical).
    /// A value inside the safe band is safe; outside safe but inside
    /// watch is watch; outside watch but inside alert is alert;
    /// anything else is critical.
    public func classify(value: Double) -> ThresholdBand {
        if safeBand.contains(value)  { return .safe }
        if watchBand.contains(value) { return .watch }
        if alertBand.contains(value) { return .alert }
        return .critical
    }
}

// MARK: - ThresholdSet

/// An ordered collection of metric thresholds that together define a user's safety envelope.
public struct ThresholdSet: Codable, Sendable, Hashable {
    public let thresholds: [MetricThreshold]

    public init(thresholds: [MetricThreshold] = []) {
        self.thresholds = thresholds
    }

    /// Returns the threshold for the requested metric, if configured.
    public func threshold(for metricType: MetricType) -> MetricThreshold? {
        thresholds.first { $0.metricType == metricType }
    }

    /// Classifies a value for a given metric, returning `.safe` when no threshold is defined.
    public func classify(value: Double, for metricType: MetricType) -> ThresholdBand {
        threshold(for: metricType)?.classify(value: value) ?? .safe
    }
}
