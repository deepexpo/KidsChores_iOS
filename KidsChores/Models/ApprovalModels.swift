//
//  ApprovalModels.swift
//  KidsChores
//
//  Parent inbox — API reference §8. Unlike TaskInstance, `taskTitle` IS
//  populated here; treat this as the source of truth for inbox rows.
//

import Foundation

/// One item awaiting parent action — `GET /v1/approvals` (oldest-first).
struct ApprovalItem: Decodable, Identifiable, Hashable {
    let type: ApprovalType
    let taskInstanceID: String
    let taskTitle: String
    let assigneeName: String
    let pointValue: Int
    let submittedAt: Date
    /// Present for excuses; `nil` for completions.
    let excuseText: String?

    /// Stable identity for SwiftUI lists — one approval per task instance.
    var id: String { taskInstanceID }

    enum CodingKeys: String, CodingKey {
        case type
        case taskInstanceID = "task_instance_id"
        case taskTitle = "task_title"
        case assigneeName = "assignee_name"
        case pointValue = "point_value"
        case submittedAt = "submitted_at"
        case excuseText = "excuse_text"
    }
}

/// Per-item outcome from `POST /v1/approvals/bulk` (always HTTP 200; inspect
/// each item's `success`). A batch of 10 with 1 failure is the expected case.
struct BulkApprovalResult: Decodable, Identifiable, Hashable {
    let taskInstanceID: String
    let success: Bool
    let status: TaskStatus?
    let error: String?

    var id: String { taskInstanceID }

    enum CodingKeys: String, CodingKey {
        case taskInstanceID = "task_instance_id"
        case success, status, error
    }
}

struct BulkApprovalResponse: Decodable {
    let results: [BulkApprovalResult]
}
