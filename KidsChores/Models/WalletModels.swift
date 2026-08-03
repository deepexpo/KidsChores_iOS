//
//  WalletModels.swift
//  KidsChores
//
//  Wallet, Ledger, Claims, Savings Goals — API reference §10.
//

import Foundation

/// `GET /v1/wallet/{member_id}`. `balance` is always server-computed as
/// SUM(delta) — never cache it beyond a single screen's lifetime.
struct Wallet: Decodable, Hashable {
    let memberID: String
    let balance: Int
    let pointsLabel: String
    /// Most recent goal not yet achieved, or `nil`.
    let activeSavingsGoal: SavingsGoal?

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case balance
        case pointsLabel = "points_label"
        case activeSavingsGoal = "active_savings_goal"
    }
}

/// One immutable ledger row — `GET /v1/wallet/{member_id}/ledger`.
struct LedgerEntry: Decodable, Identifiable, Hashable {
    let id: String
    /// Signed. Render negative for `claimFulfilled`/`reversal` (and a negative
    /// `manualAdjustment`).
    let delta: Int
    /// Denormalised convenience for rendering history — not the source of truth.
    let balanceAfter: Int
    let entryType: LedgerEntryType
    /// Pre-formatted, human-readable string — render verbatim, no client
    /// formatting (e.g. "Completed: Wash dishes").
    let reason: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, delta
        case balanceAfter = "balance_after"
        case entryType = "entry_type"
        case reason
        case createdAt = "created_at"
    }
}

/// `GET /v1/wallet/{member_id}` embeds this; there is no fetch-by-id yet.
struct SavingsGoal: Decodable, Identifiable, Hashable {
    let id: String
    let memberID: String
    let title: String
    let targetPoints: Int
    let createdAt: Date
    /// Column exists but nothing sets it yet — treat goals as create-and-display
    /// only; compute progress client-side as `balance / targetPoints`.
    let achievedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case title
        case targetPoints = "target_points"
        case createdAt = "created_at"
        case achievedAt = "achieved_at"
    }
}

/// A teen's request to convert points into a real-world reward.
struct Claim: Decodable, Identifiable, Hashable {
    let id: String
    let memberID: String
    /// The teen's display name — populated by the list endpoint for the parent
    /// inbox (nil on the single-claim create response).
    let memberName: String?
    let points: Int
    let requestedItem: String
    let status: ClaimStatus
    let parentNote: String?
    let requestedAt: Date
    let resolvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case memberName = "member_name"
        case points
        case requestedItem = "requested_item"
        case status
        case parentNote = "parent_note"
        case requestedAt = "requested_at"
        case resolvedAt = "resolved_at"
    }
}
