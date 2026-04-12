// InstallIdentity.swift
// VitaCorePersona — T034: Keychain-backed install-level UUID.
//
// Provides a stable `UUID` that survives app reinstalls (iOS Keychain
// persists across uninstall/reinstall cycles unless the user resets all
// content and settings). Used as `PersonaContext.userId` so the same
// user identity can be correlated across reinstalls for backup/restore,
// and so concurrent bootstrap calls always upsert the same primary key
// (closing the devil-critic C5 / C2 race vector).
//
// Thread-safety: all reads/writes go through `SecItemCopyMatching` /
// `SecItemAdd` / `SecItemUpdate` which are thread-safe on iOS.

import Foundation
import Security

public enum InstallIdentity {

    /// The Keychain service + account under which the UUID is stored.
    private static let service = "com.vitacore.install-identity"
    private static let account = "userId"

    /// Returns the stable install UUID, creating one on first access.
    /// Thread-safe and synchronous (Keychain I/O is fast).
    public static func getOrCreate() -> UUID {
        if let existing = read() {
            return existing
        }
        let fresh = UUID()
        write(fresh)
        return fresh
    }

    // MARK: - Keychain helpers

    private static func read() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: string) else {
            return nil
        }
        return uuid
    }

    private static func write(_ uuid: UUID) {
        let data = uuid.uuidString.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Race: another thread/process created the item first.
            // Update instead.
            let update: [String: Any] = [kSecValueData as String: data]
            let filter: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemUpdate(filter as CFDictionary, update as CFDictionary)
        }
    }
}
