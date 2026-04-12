// Schema.swift
// VitaCoreGraph — Database schema and migrations for the SQLite-backed
// temporal knowledge graph that replaces the archived Kuzu implementation.
//
// Schema philosophy:
//   nodes(id, type, props_json, valid_from, valid_to)
//     — Generic entity table for UserProfile, Condition, Goal, Medication, Allergy, etc.
//     — Temporal validity via valid_from/valid_to (null valid_to = currently valid)
//
//   edges(src_id, dst_id, type, props_json, valid_from, valid_to)
//     — Generic relationship table for HAS_CONDITION, SUPERSEDES, FOLLOWS_MEAL, etc.
//
//   readings(id, metric_type, value, unit, timestamp, source_skill,
//            confidence, trend_direction, trend_velocity)
//     — Hot path optimisation for time-series metrics (glucose, HR, steps, etc.)
//     — Indexed on (metric_type, timestamp DESC) for fast getLatestReading
//
//   episodes(id, episode_type, source_skill, source_confidence,
//            reference_time, ingestion_time, payload)
//     — Discrete event log (conversations, simulations, alerts, symptom notes, etc.)
//     — Indexed on (episode_type, reference_time DESC)
//
// Multi-hop graph traversal uses SQLite recursive CTEs — equivalent to
// Cypher MATCH patterns up to 5 hops deep for RCA queries.

import Foundation
import GRDB

// MARK: - DatabaseMigrator

public enum VitaCoreGraphSchema {

    /// Returns a GRDB migrator configured with the full VitaCoreGraph schema.
    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Enable foreign keys in production — future migrations can drop/rebuild tables
        migrator.eraseDatabaseOnSchemaChange = false

        // -------------------------------------------------------------------
        // v1 — Initial schema
        // -------------------------------------------------------------------
        migrator.registerMigration("v1_initial_schema") { db in

            // ── nodes ────────────────────────────────────────────────────────
            try db.create(table: "nodes") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull().indexed()
                t.column("props_json", .text).notNull()
                t.column("valid_from", .datetime).notNull().indexed()
                t.column("valid_to", .datetime)
            }
            try db.create(
                index: "idx_nodes_type_validity",
                on: "nodes",
                columns: ["type", "valid_from", "valid_to"]
            )

            // ── edges ────────────────────────────────────────────────────────
            try db.create(table: "edges") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("src_id", .text).notNull()
                t.column("dst_id", .text).notNull()
                t.column("type", .text).notNull()
                t.column("props_json", .text).notNull()
                t.column("valid_from", .datetime).notNull()
                t.column("valid_to", .datetime)
            }
            try db.create(
                index: "idx_edges_src_type",
                on: "edges",
                columns: ["src_id", "type"]
            )
            try db.create(
                index: "idx_edges_dst_type",
                on: "edges",
                columns: ["dst_id", "type"]
            )

            // ── readings (hot-path time-series) ──────────────────────────────
            try db.create(table: "readings") { t in
                t.column("id", .text).primaryKey()
                t.column("metric_type", .text).notNull()
                t.column("value", .double).notNull()
                t.column("unit", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("source_skill_id", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("trend_direction", .text).notNull()
                t.column("trend_velocity", .double)
            }
            try db.create(
                index: "idx_readings_metric_timestamp",
                on: "readings",
                columns: ["metric_type", "timestamp"]
            )

            // ── episodes (discrete event log) ────────────────────────────────
            try db.create(table: "episodes") { t in
                t.column("id", .text).primaryKey()
                t.column("episode_type", .text).notNull()
                t.column("source_skill_id", .text).notNull()
                t.column("source_confidence", .double).notNull()
                t.column("reference_time", .datetime).notNull()
                t.column("ingestion_time", .datetime).notNull()
                t.column("payload", .blob).notNull()
            }
            try db.create(
                index: "idx_episodes_type_reference_time",
                on: "episodes",
                columns: ["episode_type", "reference_time"]
            )
        }

        return migrator
    }
}
