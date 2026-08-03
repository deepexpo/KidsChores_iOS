//
//  RequestBodies.swift
//  KidsChores
//
//  Encodable request bodies for mutating endpoints.
//

import Foundation

/// Marks a request that carries an idempotency key. Only the five task/approval
/// mutations enforce it server-side today (API §2); the key is generated once
/// per user action and reused verbatim on every retry.
protocol IdempotentRequest: Encodable {
    var idempotencyKey: String { get }
}

// MARK: - Task actions

struct CompleteTaskRequest: IdempotentRequest {
    let idempotencyKey: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case note
    }
}

struct ExcuseTaskRequest: IdempotentRequest {
    let idempotencyKey: String
    /// Min 10 characters (enforced client-side before hitting the API).
    let excuseText: String

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case excuseText = "excuse_text"
    }
}

struct ReviewRequest: IdempotentRequest {
    let idempotencyKey: String
    let approve: Bool
    /// Required when `approve == false` (422 otherwise).
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case approve, comment
    }
}

struct CancelTaskRequest: IdempotentRequest {
    let idempotencyKey: String
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case reason
    }
}

struct BulkApprovalItemRequest: Encodable {
    let taskInstanceID: String
    let approve: Bool
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case taskInstanceID = "task_instance_id"
        case approve, comment
    }
}

struct BulkApprovalRequest: IdempotentRequest {
    let idempotencyKey: String
    let items: [BulkApprovalItemRequest]

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case items
    }
}

// MARK: - Definitions & series (no idempotency key yet — disable button on send)

struct CreateDefinitionRequest: Encodable {
    let assigneeID: String
    let title: String
    let description: String?
    let pointValue: Int
    let scheduleType: ScheduleType
    let weekdayMask: Int?
    let startDate: String
    let endDate: String?
    let dueTime: String
    let requiresReview: Bool
    let seriesID: String?

    enum CodingKeys: String, CodingKey {
        case assigneeID = "assignee_id"
        case title, description
        case pointValue = "point_value"
        case scheduleType = "schedule_type"
        case weekdayMask = "weekday_mask"
        case startDate = "start_date"
        case endDate = "end_date"
        case dueTime = "due_time"
        case requiresReview = "requires_review"
        case seriesID = "series_id"
    }
}

struct CreateSeriesRequest: Encodable {
    let name: String
    let assigneeID: String
    let bonusPoints: Int
    let payoutMode: SeriesPayoutMode
    let windowType: SeriesWindowType
    let taskDefinitionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case assigneeID = "assignee_id"
        case bonusPoints = "bonus_points"
        case payoutMode = "payout_mode"
        case windowType = "window_type"
        case taskDefinitionIDs = "task_definition_ids"
    }
}

// MARK: - Wallet actions

struct AdjustWalletRequest: Encodable {
    /// Redundant with the path param (server ignores the body value) — mirror
    /// the path value here to satisfy the schema (API §10).
    let memberID: String
    let delta: Int
    /// Mandatory, min 5 chars.
    let reason: String

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case delta, reason
    }
}

struct CreateClaimRequest: Encodable {
    let points: Int
    let requestedItem: String

    enum CodingKeys: String, CodingKey {
        case points
        case requestedItem = "requested_item"
    }
}

struct ResolveClaimRequest: Encodable {
    let approve: Bool
    let parentNote: String?

    enum CodingKeys: String, CodingKey {
        case approve
        case parentNote = "parent_note"
    }
}

struct CreateGoalRequest: Encodable {
    let title: String
    let targetPoints: Int

    enum CodingKeys: String, CodingKey {
        case title
        case targetPoints = "target_points"
    }
}

struct CreateTeenRequest: Encodable {
    let displayName: String
    /// YYYY-MM-DD. Server rejects under-13.
    let birthdate: String
    /// Exactly 4 digits. Shared-device PIN, not a security boundary.
    let pin: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case birthdate, pin
    }
}

/// Body for `POST /v1/household/members/{id}/verify-pin`.
struct VerifyPINRequest: Encodable {
    /// Exactly 4 digits.
    let pin: String
}

/// Body for setting/changing/clearing a teen's shared-device PIN.
/// ⚠️ Assumed contract `PUT /v1/household/members/{id}/pin` — not in the API
/// reference yet (see docs/auth-endpoints.md). `nil` clears the PIN.
struct MemberPINUpdateRequest: Encodable {
    let pin: String?

    enum CodingKeys: String, CodingKey { case pin }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode explicit null when clearing (not an omitted key).
        try container.encode(pin, forKey: .pin)
    }
}
