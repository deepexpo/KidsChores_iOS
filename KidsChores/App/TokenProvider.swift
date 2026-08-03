//
//  TokenProvider.swift
//  KidsChores
//
//  Supplies the access token to the HTTP transport, refreshing pre-emptively
//  from the JWT `exp` (ios-prd §11) via `POST /v1/auth/refresh`.
//
//  An actor so concurrent requests coalesce onto a single in-flight refresh
//  (a "thundering herd" of 401-avoidance calls would otherwise rotate the
//  single-use refresh token multiple times and invalidate itself). The refresh
//  call is made with a bare URLSession, not the app's HTTPClient, to avoid the
//  client ↔ provider dependency cycle.
//

import Foundation

actor TokenProvider: AuthTokenProviding {
    private let store: TokenStore
    private let baseURL: URL
    private let session: URLSession
    /// Refresh this many seconds before the access token's `exp`.
    private let skew: TimeInterval = 120

    private var inFlight: Task<String?, Never>?

    init(store: TokenStore, baseURL: URL, session: URLSession = .shared) {
        self.store = store
        self.baseURL = baseURL
        self.session = session
    }

    func currentAccessToken() async -> String? {
        guard let tokens = store.read() else { return nil }

        // Still valid with margin — use as-is.
        if let exp = Self.expiry(of: tokens.accessToken),
           exp.timeIntervalSinceNow > skew {
            return tokens.accessToken
        }

        // Coalesce concurrent refreshes onto one task.
        if let inFlight { return await inFlight.value }
        let task = Task { await self.performRefresh(using: tokens.refreshToken) }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    // MARK: - Refresh

    private func performRefresh(using refreshToken: String) async -> String? {
        guard let body = try? JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken)) else {
            return store.read()?.accessToken
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                // Refresh permanently rejected (expired/rotated/revoked). Clear the
                // session and signal the UI to return to sign-in, so the app can't
                // get stuck showing an authenticated screen that silently 401s.
                store.clear()
                await MainActor.run {
                    NotificationCenter.default.post(name: .sessionExpired, object: nil)
                }
                return nil
            }
            let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
            store.save(tokens)
            return tokens.accessToken
        } catch {
            // Network failure — keep the (stale) token; the request may still 401
            // and be retried later once connectivity returns.
            return store.read()?.accessToken
        }
    }

    // MARK: - JWT

    /// Reads the `exp` claim (seconds since epoch) from a JWT without verifying
    /// the signature — we only trust it to schedule refresh, never for auth.
    private static func expiry(of jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        guard let payload = base64URLDecode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}
