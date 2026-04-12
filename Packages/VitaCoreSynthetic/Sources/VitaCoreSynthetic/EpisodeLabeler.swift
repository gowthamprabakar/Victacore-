// EpisodeLabeler.swift
// VitaCoreSynthetic — Scans a generated reading stream and emits
// ground-truth `Episode` records so Wave 1 C14 ThresholdEngine can
// measure detection precision/recall against known labels.
//
// This is the *oracle* for the synthetic dataset: anything the labeler
// flags is by definition a real episode; anything ThresholdEngine flags
// that is NOT in the oracle is a false positive; anything in the oracle
// ThresholdEngine misses is a false negative.

import Foundation
import VitaCoreContracts

// MARK: - EpisodeLabeler

public struct EpisodeLabeler {

    public init() {}

    /// Scans the given reading stream and returns every ground-truth
    /// episode it contains. Current rules:
    ///
    ///   • **Hypoglycemia** (cgmGlucose): any glucose < 70 mg/dL.
    ///     Consecutive sub-70 readings are collapsed into a single
    ///     episode anchored at the lowest value.
    ///   • **Hyperglycemia spike** (cgmGlucose): glucose > 200 mg/dL,
    ///     same collapsing rule.
    ///   • **Elevated BP** (bpReading): systolic > 140 OR diastolic > 90.
    ///
    /// The payload is a simple JSON dict with the triggering metric,
    /// value, threshold, and direction, so the ThresholdEngine tests
    /// can introspect without reaching for binary decoders.
    public func label(readings: [Reading]) -> [Episode] {
        var episodes: [Episode] = []

        // --- Glucose episodes -------------------------------------------
        let glucose = readings
            .filter { $0.metricType == .glucose }
            .sorted { $0.timestamp < $1.timestamp }

        // Collapse consecutive sub-70 runs.
        var inHypo = false
        var hypoAnchor: Reading?
        for r in glucose {
            if r.value < 70 {
                if !inHypo {
                    inHypo = true
                    hypoAnchor = r
                } else if let anchor = hypoAnchor, r.value < anchor.value {
                    hypoAnchor = r
                }
            } else if inHypo {
                if let anchor = hypoAnchor {
                    episodes.append(
                        makeGlucoseEpisode(
                            anchor: anchor,
                            threshold: 70,
                            direction: "below"
                        )
                    )
                }
                inHypo = false
                hypoAnchor = nil
            }
        }
        if inHypo, let anchor = hypoAnchor {
            episodes.append(
                makeGlucoseEpisode(anchor: anchor, threshold: 70, direction: "below")
            )
        }

        // Collapse consecutive >200 runs.
        var inHyper = false
        var hyperAnchor: Reading?
        for r in glucose {
            if r.value > 200 {
                if !inHyper {
                    inHyper = true
                    hyperAnchor = r
                } else if let anchor = hyperAnchor, r.value > anchor.value {
                    hyperAnchor = r
                }
            } else if inHyper {
                if let anchor = hyperAnchor {
                    episodes.append(
                        makeGlucoseEpisode(
                            anchor: anchor,
                            threshold: 200,
                            direction: "above"
                        )
                    )
                }
                inHyper = false
                hyperAnchor = nil
            }
        }
        if inHyper, let anchor = hyperAnchor {
            episodes.append(
                makeGlucoseEpisode(anchor: anchor, threshold: 200, direction: "above")
            )
        }

        // --- BP episodes ------------------------------------------------
        // Group BP readings by timestamp so systolic + diastolic pair up.
        let bp = readings.filter {
            $0.metricType == .bloodPressureSystolic ||
            $0.metricType == .bloodPressureDiastolic
        }
        let pairs = Dictionary(grouping: bp, by: { $0.timestamp })
        for (_, readings) in pairs {
            let sys = readings.first { $0.metricType == .bloodPressureSystolic }?.value ?? 0
            let dia = readings.first { $0.metricType == .bloodPressureDiastolic }?.value ?? 0
            if sys > 140 || dia > 90 {
                let anchor = readings.first!
                episodes.append(
                    Episode(
                        episodeType: .bpReading,
                        sourceSkillId: "synthetic.labeler",
                        sourceConfidence: 1.0,
                        referenceTime: anchor.timestamp,
                        payload: encodeBpPayload(systolic: sys, diastolic: dia)
                    )
                )
            }
        }

        return episodes.sorted { $0.referenceTime < $1.referenceTime }
    }

    // -------------------------------------------------------------------------
    // MARK: Payload helpers
    // -------------------------------------------------------------------------

    private func makeGlucoseEpisode(
        anchor: Reading,
        threshold: Double,
        direction: String
    ) -> Episode {
        Episode(
            episodeType: .cgmGlucose,
            sourceSkillId: "synthetic.labeler",
            sourceConfidence: 1.0,
            referenceTime: anchor.timestamp,
            payload: encodeGlucosePayload(
                value: anchor.value,
                threshold: threshold,
                direction: direction
            )
        )
    }

    private func encodeGlucosePayload(
        value: Double,
        threshold: Double,
        direction: String
    ) -> Data {
        let dict: [String: Any] = [
            "metric": "glucose",
            "value": value,
            "threshold": threshold,
            "direction": direction
        ]
        return (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
    }

    private func encodeBpPayload(systolic: Double, diastolic: Double) -> Data {
        let dict: [String: Any] = [
            "metric": "bloodPressure",
            "systolic": systolic,
            "diastolic": diastolic,
            "thresholdSys": 140,
            "thresholdDia": 90
        ]
        return (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
    }
}
