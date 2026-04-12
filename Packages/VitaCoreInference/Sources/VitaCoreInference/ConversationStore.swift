// ConversationStore.swift
// VitaCoreInference — GRDB persistence for conversation sessions.
//
// Principle III: owns its own SQLite file `vitacore_conversations.sqlite`,
// separate from graph and persona stores. Stores full ConversationSession
// (with turns) as JSON blobs — same pattern as PersonaStore, same
// rationale (Codable evolution without migration).

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - ConversationStore

public actor ConversationStore {

    private let writer: any DatabaseWriter
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrate(writer)
    }

    private static func migrate(_ writer: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_sessions") { db in
            try db.create(table: "conversation_sessions") { t in
                t.column("session_id", .text).primaryKey()
                t.column("blob", .blob).notNull()
                t.column("started_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
        }
        try migrator.migrate(writer)
    }

    // -------------------------------------------------------------------------
    // MARK: Factories
    // -------------------------------------------------------------------------

    public static func defaultStore() throws -> ConversationStore {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VitaCore", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let file = dir.appendingPathComponent("vitacore_conversations.sqlite")
        let pool = try DatabasePool(path: file.path)
        return try ConversationStore(writer: pool)
    }

    public static func inMemory() throws -> ConversationStore {
        try ConversationStore(writer: DatabaseQueue())
    }

    // -------------------------------------------------------------------------
    // MARK: CRUD
    // -------------------------------------------------------------------------

    public func getAllSessions() async throws -> [ConversationSession] {
        let decoder = self.decoder
        return try await writer.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT blob FROM conversation_sessions ORDER BY updated_at DESC")
            return rows.compactMap { row -> ConversationSession? in
                guard let data = row["blob"] as? Data else { return nil }
                return try? decoder.decode(ConversationSession.self, from: data)
            }
        }
    }

    public func getSession(id: UUID) async throws -> ConversationSession? {
        let decoder = self.decoder
        return try await writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT blob FROM conversation_sessions WHERE session_id = ?", arguments: [id.uuidString]) else {
                return nil
            }
            guard let data = row["blob"] as? Data else { return nil }
            return try? decoder.decode(ConversationSession.self, from: data)
        }
    }

    public func saveSession(_ session: ConversationSession) async throws {
        let blob = try encoder.encode(session)
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO conversation_sessions (session_id, blob, started_at, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [session.sessionId.uuidString, blob, session.startedAt, Date()]
            )
        }
    }

    public func deleteSession(id: UUID) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM conversation_sessions WHERE session_id = ?", arguments: [id.uuidString])
        }
    }
}
