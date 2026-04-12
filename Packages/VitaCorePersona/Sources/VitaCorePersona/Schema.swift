// Schema.swift
// VitaCorePersona — GRDB migration stack for the persona store.
//
// Deliberately minimal: one row per user, full PersonaContext
// serialised as JSON in a `blob` column. Rationale for the blob-not-
// normalised approach:
//
//   • PersonaContext is a frozen Codable contract shared with every
//     other component. Splitting it into normalised tables would
//     require a migration on every field addition; the blob approach
//     is backward-compatible with any forward `Codable` change.
//   • PersonaContext is small (< 4 kB for realistic users) and read
//     as a single unit from the UI. There's no query pattern that
//     would benefit from normalisation.
//   • Graph-grade metrics (readings / episodes) still live in the
//     separate `VitaCoreGraph` SQLite file — this file is *only* for
//     persona state, so there's no cross-table join risk.
//
// If we ever need indexed queries on individual fields (e.g., "all
// users on metformin"), we can add derived columns in a later
// migration without breaking the blob.

import Foundation
import GRDB

// MARK: - PersonaMigrator

public enum PersonaMigrator {

    /// Returns a configured `DatabaseMigrator` ready to apply to a new
    /// or existing persona store. Callers invoke `migrator.migrate(db)`
    /// from `GRDBPersonaStore.init`.
    public static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        // --------------------------------------------------------------
        // v1_initial_schema
        // --------------------------------------------------------------
        m.registerMigration("v1_initial_schema") { db in
            try db.create(table: "persona_context") { t in
                t.column("user_id", .text).primaryKey()      // UUID string
                t.column("blob", .blob).notNull()            // JSON-encoded PersonaContext
                t.column("updated_at", .datetime).notNull()
            }
        }

        return m
    }
}

// MARK: - PersonaContextRow

/// GRDB row binding for the `persona_context` table. Kept separate from
/// `PersonaContext` itself (which is the frozen cross-package contract)
/// so the on-disk representation can evolve without churning the
/// contract surface.
struct PersonaContextRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "persona_context"

    let userId: String
    let blob: Data
    let updatedAt: Date

    // Explicit column coding keys: snake_case on disk, camelCase in code.
    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case blob
        case updatedAt = "updated_at"
    }
}
