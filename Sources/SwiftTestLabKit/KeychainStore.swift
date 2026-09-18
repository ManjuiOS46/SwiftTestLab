//
//  KeychainStore.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Security

public enum KeychainError: LocalizedError, Sendable, Equatable {
    case unhandled(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "Keychain error \(status): \(message)"
        }
    }
}

/// Stores the API key in the login keychain. The key is never written to disk in
/// plain text, never logged, and never included in an error message.
public struct KeychainStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.swifttestlab.anthropic", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    /// Each provider gets its own item, so switching between them doesn't lose a key.
    public static func store(for kind: ProviderKind) -> KeychainStore {
        switch kind {
        case .anthropic: KeychainStore(account: "api-key")
        case .openAICompatible: KeychainStore(account: "openai-compatible-key")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status: status)
        }
    }

    public func hasKey() -> Bool {
        ((try? read()) ?? nil)?.isEmpty == false
    }

    public func save(_ key: String) throws {
        let data = Data(key.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(status: addStatus)
            }
        default:
            throw KeychainError.unhandled(status: status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }
}
