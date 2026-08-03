//
//  TokenStore.swift
//  KidsChores
//
//  Session-token persistence. Per PRD §11.4 / ios-prd §11, raw tokens live in
//  the Keychain, never UserDefaults. The protocol keeps storage swappable
//  (Keychain in the app, in-memory in tests) behind a stable seam.
//

import Foundation
import Security

/// Where the session tokens live. Abstracted so the auth layer depends on the
/// capability, not on Keychain APIs (DIP).
protocol TokenStore: Sendable {
    func read() -> AuthTokens?
    func save(_ tokens: AuthTokens)
    func clear()
}

/// Keychain-backed store. Persists the decoded `AuthTokens` as a JSON blob
/// under a single generic-password item.
final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account = "session"

    init(service: String = "com.kidschores.session") {
        self.service = service
    }

    func read() -> AuthTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Volatile store for previews and unit tests.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var tokens: AuthTokens?
    init(_ tokens: AuthTokens? = nil) { self.tokens = tokens }
    func read() -> AuthTokens? { tokens }
    func save(_ tokens: AuthTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}

// `AuthTokens` is Decodable per the API; add Encodable so it can be persisted.
extension AuthTokens: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(memberID, forKey: .memberID)
        try container.encode(householdID, forKey: .householdID)
        try container.encode(role.rawValue, forKey: .role)
    }
}
