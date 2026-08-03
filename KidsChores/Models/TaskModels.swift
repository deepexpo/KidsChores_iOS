//
//  TaskModels.swift
//  KidsChores
//
//  Task Definitions (templates) and Task Instances (occurrences) —
//  API reference §6 and §7.
//

import Foundation

/// The reusable template a parent manages — `GET /v1/definitions`.
struct TaskDefinition: Decodable, Identifiable, Hashable {
    let id: String
    let householdID: String
    let assigneeID: String
    let title: String
    let description: String?
    let pointValue: Int
    let scheduleType: ScheduleType
    /// Only meaningful when `scheduleType == .weekdays`. 7-bit mask,
    /// bit 0 = Monday … bit 6 = Sunday (see `Weekday` helpers, not Swift's
    /// Sun=1…Sat=7 ordering — remap before use).
    let weekdayMask: Int?
    let startDate: String
    let endDate: String?
    /// "HH:MM", 24h.
    let dueTime: String
    let requiresReview: Bool
    let seriesID: String?
    let archivedAt: Date?
    let createdAt: Date

    var isArchived: Bool { archivedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
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
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }
}

/// A single occurrence a teen interacts with — every `/v1/tasks/...` endpoint
/// returns this shape.
///
/// ⚠️ Known gap (API §7): `title`/`description` are declared but **not
/// populated** — they are always `nil`. Join against a cached `TaskDefinition`
/// on `definitionID` for display. See `DefinitionCache`.
struct TaskInstance: Decodable, Identifiable, Hashable {
    let id: String
    let definitionID: String
    let assigneeID: String
    let dueAt: Date
    /// Frozen at generation time (PRD §8.4) — never re-derive from the
    /// definition, which may have been re-priced since.
    let pointValue: Int
    let status: TaskStatus
    let completedAt: Date?
    let completionNote: String?
    let excuseText: String?
    let reviewComment: String?
    let seriesInstanceID: String?
    /// Always `nil` today — see the type doc. Prefer a joined definition title.
    let title: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case definitionID = "definition_id"
        case assigneeID = "assignee_id"
        case dueAt = "due_at"
        case pointValue = "point_value"
        case status
        case completedAt = "completed_at"
        case completionNote = "completion_note"
        case excuseText = "excuse_text"
        case reviewComment = "review_comment"
        case seriesInstanceID = "series_instance_id"
        case title, description
    }
}
