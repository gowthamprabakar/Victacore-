// GRDBGraphStore+Default.swift
// VitaCoreGraph — Convenient factory for the app's production store location.

import Foundation

public extension GRDBGraphStore {

    /// Returns a production store rooted at `<Application Support>/vitacore.sqlite`.
    ///
    /// The parent directory is created if it doesn't exist. The SQLite file
    /// (and its WAL/SHM siblings) are tagged with `FileProtectionType.completeUnlessOpen`
    /// so they are encrypted at rest by iOS Data Protection while still being
    /// accessible to background-running code after first unlock.
    static func defaultStore() throws -> GRDBGraphStore {
        let fm = FileManager.default
        let baseURL = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDir = baseURL.appendingPathComponent("VitaCore", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        let dbURL = appDir.appendingPathComponent("vitacore.sqlite")
        return try GRDBGraphStore(path: dbURL.path)
    }
}
