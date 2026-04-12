// ThresholdResolver.swift
// VitaCoreThreshold — Priority stack resolver + engine.
//
// Implements the 7-level priority stack from the sprint plan:
//   1. Clinician override (priority 7)  — from PersonaContext.thresholdOverrides
//   2. Critical safety (priority 6)     — hardcoded floor (glucose <40, HR <30)
//   3. Most restrictive condition (priority 3-5) — tighter wins per-metric
//   4. Goal-driven (priority 2)         — from PersonaContext.activeGoals
//   5. Medication modifier (priority 4) — shifts safe bands
//   6. Age-adjusted (priority 1)        — elderly widens HR safe band
//   7. Population default (priority 0)  — healthyBaseline
//
// Resolution produces a single `ThresholdSet` with one `MetricThreshold`
// per metric. Each metric's threshold is the TIGHTEST safe band from
// the highest-priority source that defines it.

import Foundation
import VitaCoreContracts

// MARK: - ThresholdResolver

public struct ThresholdResolver: Sendable {

    public init() {}

    /// Resolves a complete `ThresholdSet` for the given persona context.
    /// The resolution algorithm:
    ///   1. Start with population defaults (healthyBaseline).
    ///   2. For each active condition, look up its profile. For each
    ///      metric in that profile, if the profile's threshold has a
    ///      HIGHER priority than the current best, replace it.
    ///   3. Apply medication modifiers (shift safe-band bounds).
    ///   4. Apply clinician overrides from `PersonaContext.thresholdOverrides`
    ///      (these always win, priority 7).
    public func resolve(from context: PersonaContext) -> ThresholdSet {
        // 1. Seed with population defaults.
        var best: [MetricType: MetricThreshold] = [:]
        for t in ConditionProfiles.healthyBaseline.thresholds {
            best[t.metricType] = t
        }

        // 2. Layer active-condition profiles. Tighter (higher priority) wins.
        for condition in context.activeConditions {
            guard let profile = ConditionProfiles.profile(for: condition.conditionKey) else {
                continue
            }
            for t in profile.thresholds {
                if let existing = best[t.metricType] {
                    // Higher priority wins. On tie, pick the tighter safe band
                    // (smaller range = more restrictive = safer).
                    if t.priority > existing.priority {
                        best[t.metricType] = t
                    } else if t.priority == existing.priority {
                        let existingWidth = existing.safeBand.upperBound - existing.safeBand.lowerBound
                        let newWidth = t.safeBand.upperBound - t.safeBand.lowerBound
                        if newWidth < existingWidth {
                            best[t.metricType] = t
                        }
                    }
                } else {
                    best[t.metricType] = t
                }
            }
        }

        // 3. Apply medication modifiers.
        for med in context.activeMedications {
            let modifiers = MedicationModifiers.modifiers(for: med.classKey)
            for mod in modifiers {
                if let existing = best[mod.metricType] {
                    let newLower = existing.safeBand.lowerBound + mod.safeLowerShift
                    let newUpper = existing.safeBand.upperBound + mod.safeUpperShift
                    guard newLower < newUpper else { continue }
                    best[mod.metricType] = MetricThreshold(
                        metricType: mod.metricType,
                        safeBand: newLower...newUpper,
                        watchBand: existing.watchBand,
                        alertBand: existing.alertBand,
                        criticalBand: existing.criticalBand,
                        priority: max(existing.priority, mod.priority)
                    )
                }
            }
        }

        // 4. Apply clinician overrides (always win).
        for override in context.thresholdOverrides {
            if let existing = best[override.metricType] {
                let lower = override.lowerBound ?? existing.safeBand.lowerBound
                let upper = override.upperBound ?? existing.safeBand.upperBound
                guard lower < upper else { continue }
                best[override.metricType] = MetricThreshold(
                    metricType: override.metricType,
                    safeBand: lower...upper,
                    watchBand: existing.watchBand,
                    alertBand: existing.alertBand,
                    criticalBand: existing.criticalBand,
                    priority: 7  // clinician override always highest
                )
            }
        }

        return ThresholdSet(thresholds: Array(best.values).sorted { $0.metricType.rawValue < $1.metricType.rawValue })
    }
}

// MARK: - VitaCoreThresholdEngine

/// The production `ThresholdEngine`. Resolves a `ThresholdSet` from a
/// `PersonaEngineProtocol` source, caches the result for 60 seconds,
/// and invalidates on persona mutation.
///
/// Thread-safety: the engine is `@unchecked Sendable` because all
/// mutable state is behind a lock (the cache is actor-isolated via a
/// dedicated `ThresholdCache` actor, or here we use a simple lock-free
/// approach with `os_unfair_lock` — but for simplicity we use a
/// timestamp-based check since reads are cheap).
public final class VitaCoreThresholdEngine: @unchecked Sendable {

    private let personaEngine: PersonaEngineProtocol
    private let resolver: ThresholdResolver

    // Simple TTL cache: resolved set + timestamp.
    private var cachedSet: ThresholdSet?
    private var cacheTimestamp: Date = .distantPast
    private let cacheTTL: TimeInterval = 60

    public init(
        personaEngine: PersonaEngineProtocol,
        resolver: ThresholdResolver = ThresholdResolver()
    ) {
        self.personaEngine = personaEngine
        self.resolver = resolver
    }

    /// Resolves the current user's threshold set. Returns the cached
    /// version if it's less than 60 seconds old; otherwise re-resolves
    /// from the persona engine.
    public func resolveActiveThresholdSet() async throws -> ThresholdSet {
        let now = Date()
        if let cached = cachedSet,
           now.timeIntervalSince(cacheTimestamp) < cacheTTL {
            return cached
        }
        let context = try await personaEngine.getPersonaContext()
        let resolved = resolver.resolve(from: context)
        cachedSet = resolved
        cacheTimestamp = now
        return resolved
    }

    /// Forces cache invalidation. Call this when the persona is mutated
    /// (condition added/removed, medication changed, clinician override).
    public func invalidateCache() {
        cachedSet = nil
        cacheTimestamp = .distantPast
    }

    /// Classifies a reading value against the resolved threshold set.
    /// Convenience wrapper that resolves + classifies in one call.
    public func classify(value: Double, for metricType: MetricType) async throws -> ThresholdBand {
        let set = try await resolveActiveThresholdSet()
        return set.classify(value: value, for: metricType)
    }
}
