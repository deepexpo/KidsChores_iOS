//
//  APIError.swift
//  KidsChores
//
//  Typed errors mapped from the API's HTTP status codes (API reference §3).
//

import Foundation

/// A decoded API error. `422` on a task action carries a human-readable
/// sentence in `detail` that is safe to surface directly — but branch on
/// `status` and the task's `TaskStatus`, never pattern-match the string.
enum APIError: Error, Equatable {
    /// Missing/invalid/expired token — trigger the silent re-auth path (§1.3).
    case unauthorized
    /// Authenticated, but this role/member can't perform the action.
    case forbidden
    /// Not found, or belongs to another household (indistinguishable by design).
    case notFound
    /// Validation failure or an illegal state-machine transition.
    case unprocessable(detail: String?)
    /// Rate limit exceeded (repeated PIN/login/register attempts).
    case rateLimited(detail: String?)
    /// Any other non-2xx response.
    case server(status: Int, detail: String?)
    /// Transport-level failure (offline, timeout, DNS).
    case transport(underlying: String)
    /// Response body couldn't be decoded into the expected type.
    case decoding(underlying: String)

    /// Maps a status code + optional decoded detail to a case.
    static func from(status: Int, detail: String?) -> APIError {
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 422: return .unprocessable(detail: detail)
        case 429: return .rateLimited(detail: detail)
        default: return .server(status: status, detail: detail)
        }
    }
}

/// The plain `{ "detail": "..." }` error envelope. (Pydantic 422s can instead
/// return a `[{loc, msg, type}]` array; decoded best-effort.)
struct APIErrorEnvelope: Decodable {
    let detail: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try the simple string form first, fall back to the validation array.
        if let string = try? container.decode(String.self, forKey: .detail) {
            detail = string
        } else if let items = try? container.decode([ValidationDetail].self, forKey: .detail) {
            detail = items.compactMap(\.msg).joined(separator: "\n")
        } else {
            detail = nil
        }
    }

    private enum CodingKeys: String, CodingKey { case detail }

    private struct ValidationDetail: Decodable {
        let msg: String?
    }
}
