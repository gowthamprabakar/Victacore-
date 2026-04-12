// ReadingRow.swift
// VitaCoreGraph — SQLite row representation of Reading for GRDB fetch/insert.
//
// We use a dedicated row struct (rather than conforming Reading directly) for
// two reasons:
//   1. Reading lives in VitaCoreContracts which must not depend on GRDB
//   2. Column naming follows snake_case SQL convention while Reading uses camelCase

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - ReadingRow

struct ReadingRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "readings"

    var id: String
    var metric_type: String
    var value: Double
    var unit: String
    var timestamp: Date
    var source_skill_id: String
    var confidence: Double
    var trend_direction: String
    var trend_velocity: Double?

    // MARK: - Conversion

    init(from reading: Reading) {
        self.id               = reading.id.uuidString
        self.metric_type      = reading.metricType.rawValue
        self.value            = reading.value
        self.unit             = reading.unit
        self.timestamp        = reading.timestamp
        self.source_skill_id  = reading.sourceSkillId
        self.confidence       = Double(reading.confidence)
        self.trend_direction  = reading.trendDirection.rawValue
        self.trend_velocity   = reading.trendVelocity
    }

    /// Returns the domain `Reading` value, or nil if any enum raw value is malformed.
    func toReading() -> Reading? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        guard let metric = MetricType(rawValue: metric_type) else { return nil }
        let trend = TrendDirection(rawValue: trend_direction) ?? .stable

        return Reading(
            id:             uuid,
            metricType:     metric,
            value:          value,
            unit:           unit,
            timestamp:      timestamp,
            sourceSkillId:  source_skill_id,
            confidence:     Float(confidence),
            trendDirection: trend,
            trendVelocity:  trend_velocity
        )
    }
}
