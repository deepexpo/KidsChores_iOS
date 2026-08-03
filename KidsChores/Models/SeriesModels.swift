//
//  SeriesModels.swift
//  KidsChores
//
//  Series & Series Instances — API reference §9.
//

import Foundation

/// A bundle of definitions paying a bonus on full completion within a window —
/// `GET /v1/series`.
struct Series: Decodable, Identifiable, Hashable {
    let id: String
    let householdID: String
    let name: String
    let assigneeID: String
    let bonusPoints: Int
    let payoutMode: SeriesPayoutMode
    let windowType: SeriesWindowType
    let archivedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case name
        case assigneeID = "assignee_id"
        case bonusPoints = "bonus_points"
        case payoutMode = "payout_mode"
        case windowType = "window_type"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }
}

/// One window of a series — `GET /v1/series/{id}/instances`.
struct SeriesInstance: Decodable, Identifiable, Hashable {
    let id: String
    let seriesID: String
    let windowStart: Date
    let windowEnd: Date
    let status: SeriesStatus
    let completedAt: Date?
    /// e.g. "2 of 3 complete". `nil` until the nightly job materialises tasks
    /// into the window.
    let progress: String?

    enum CodingKeys: String, CodingKey {
        case id
        case seriesID = "series_id"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case status
        case completedAt = "completed_at"
        case progress
    }
}
