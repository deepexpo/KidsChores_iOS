//
//  PINStore.swift
//  KidsChores
//
//  Local storage for shared-device profile PINs. The backend hashes a PIN at
//  teen creation but exposes no verify endpoint and never returns the hash
//  (api-reference §5), so the PIN gate is verified client-side. Per master PRD
//  §6.1 this is "not a security boundary" — just enough friction to stop casual
//  sibling mischief. Stored in the Keychain, keyed by member id.
//

import Foundation
import Security

protocol PINStore: Sendable {
    func pin(for memberID: String) -> String?
    func setPIN(_ pin: String, for memberID: String)
    func clear(for memberID: String)
}

final class KeychainPINStore: PINStore {
    private let service: String

    init(service: String = "com.kidschores.pin") {
        self.service = service
    }

    func pin(for memberID: String) -> String? {
        var query = baseQuery(memberID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setPIN(_ pin: String, for memberID: String) {
        guard let data = pin.data(using: .utf8) else { return }
        SecItemDelete(baseQuery(memberID) as CFDictionary)
        var query = baseQuery(memberID)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear(for memberID: String) {
        SecItemDelete(baseQuery(memberID) as CFDictionary)
    }

    private func baseQuery(_ memberID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: memberID
        ]
    }
}

/// Volatile store for previews/tests.
final class InMemoryPINStore: PINStore, @unchecked Sendable {
    private var pins: [String: String] = [:]
    func pin(for memberID: String) -> String? { pins[memberID] }
    func setPIN(_ pin: String, for memberID: String) { pins[memberID] = pin }
    func clear(for memberID: String) { pins[memberID] = nil }
}
