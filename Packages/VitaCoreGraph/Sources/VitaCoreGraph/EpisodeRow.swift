// EpisodeRow.swift
// VitaCoreGraph — SQLite row representation of Episode for GRDB fetch/insert.

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - EpisodeRow

struct EpisodeRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "episodes"

    var id: String
    var episode_type: String
    var source_skill_id: String
    var source_confidence: Double
    var reference_time: Date
    var ingestion_time: Date
    var payload: Data

    // MARK: - Conversion

    init(from episode: Episode) {
        self.id                 = episode.id.uuidString
        self.episode_type       = episode.episodeType.rawValue
        self.source_skill_id    = episode.sourceSkillId
        self.source_confidence  = Double(episode.sourceConfidence)
        self.reference_time     = episode.referenceTime
        self.ingestion_time     = episode.ingestionTime
        self.payload            = episode.payload
    }

    /// Returns the domain `Episode`, or nil if rawValues are malformed.
    func toEpisode() -> Episode? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        guard let type = EpisodeType(rawValue: episode_type) else { return nil }

        return Episode(
            id:               uuid,
            episodeType:      type,
            sourceSkillId:    source_skill_id,
            sourceConfidence: Float(source_confidence),
            referenceTime:    reference_time,
            ingestionTime:    ingestion_time,
            payload:          payload
        )
    }
}
