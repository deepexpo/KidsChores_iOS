//
//  HTTPClient.swift
//  KidsChores
//
//  Transport abstraction (DIP): higher layers depend on `HTTPClient`, not on
//  URLSession. Swap in a mock in tests / previews without touching call sites.
//

import Foundation

/// A single HTTP request, decoupled from any endpoint knowledge.
struct HTTPRequest {
    var method: String
    var path: String                 // e.g. "/v1/tasks/today"
    var query: [URLQueryItem] = []
    var body: Data? = nil
    /// Set false for the unauthenticated sign-in call.
    var requiresAuth: Bool = true
}

/// The transport seam. One method, so it's trivially mockable (ISP + DIP).
protocol HTTPClient {
    /// Performs the request and returns the decoded body, or throws `APIError`.
    func send<Response: Decodable>(_ request: HTTPRequest, as type: Response.Type) async throws -> Response

    /// For endpoints that return no meaningful body (204, etc.).
    func send(_ request: HTTPRequest) async throws
}

/// Supplies a bearer token to the transport. Kept separate from `TokenStore`
/// so the client only depends on "give me a token", not on how it's stored.
protocol AuthTokenProviding: Sendable {
    /// Current access token, refreshing silently if needed. `nil` if signed out.
    func currentAccessToken() async -> String?
}

/// Live URLSession-backed transport.
final class URLSessionHTTPClient: HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: AuthTokenProviding
    private let decoder: JSONDecoder

    init(baseURL: URL,
         tokenProvider: AuthTokenProviding,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = Self.makeDecoder()
    }

    func send<Response: Decodable>(_ request: HTTPRequest, as type: Response.Type) async throws -> Response {
        let data = try await perform(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(underlying: String(describing: error))
        }
    }

    func send(_ request: HTTPRequest) async throws {
        _ = try await perform(request)
    }

    // MARK: - Core

    private func perform(_ request: HTTPRequest) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path),
                                       resolvingAgainstBaseURL: false)
        if !request.query.isEmpty { components?.queryItems = request.query }
        guard let url = components?.url else {
            throw APIError.transport(underlying: "Invalid URL for path \(request.path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if request.requiresAuth, let token = await tokenProvider.currentAccessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport(underlying: String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(underlying: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? decoder.decode(APIErrorEnvelope.self, from: data))?.detail
            throw APIError.from(status: http.statusCode, detail: detail)
        }
        return data
    }

    // MARK: - Coding

    /// The API mixes fractional-second and whole-second ISO-8601 timestamps
    /// (e.g. "…:00.788742Z" and "…:00Z"), so we try both.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: raw) ?? whole.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: d.codingPath,
                      debugDescription: "Unrecognised ISO-8601 date: \(raw)"))
        }
        return decoder
    }
}
