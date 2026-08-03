//
//  HouseholdModels.swift
//  KidsChores
//
//  Household & Member — API reference §5.
//

import Foundation

/// `GET /v1/household`. The household is the top-level tenant; its `timezone`
/// governs every "today"/"this week" calculation — never assume device tz.
struct Household: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    /// IANA name, e.g. "America/Los_Angeles".
    let timezone: String
    /// Household's chosen word for points (default "points"). Always render
    /// this; never style it like currency (PRD §10.4).
    let pointsLabel: String
    let excusedPayoutPolicy: ExcusedPayoutPolicy
    /// 1–72.
    let gracePeriodHours: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, timezone
        case pointsLabel = "points_label"
        case excusedPayoutPolicy = "excused_payout_policy"
        case gracePeriodHours = "grace_period_hours"
        case createdAt = "created_at"
    }
}

/// A member of the household — `GET /v1/household/members`.
struct Member: Decodable, Identifiable, Hashable {
    let id: String
    let householdID: String
    let role: MemberRole
    let displayName: String
    let avatar: String?
    let birthdate: String?
    /// Whether this member has a shared-device PIN set (never the hash itself).
    /// Optional for backward-compatibility with responses predating this field.
    let pinSet: Bool?
    let createdAt: Date

    /// True when a PIN gate should be shown for this profile (§4.4).
    var hasPIN: Bool { pinSet == true }

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case role
        case displayName = "display_name"
        case avatar, birthdate
        case pinSet = "pin_set"
        case createdAt = "created_at"
    }
}

/// Response from `POST /v1/household/members/{id}/verify-pin`.
struct VerifyPINResponse: Decodable {
    /// Whether the supplied PIN matched.
    let valid: Bool
    /// Whether the member has a PIN at all (false → open without a gate).
    let pinSet: Bool

    enum CodingKeys: String, CodingKey {
        case valid
        case pinSet = "pin_set"
    }
}
