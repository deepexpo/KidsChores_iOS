//
//  ReportModels.swift
//  KidsChores
//
//  Per-teen weekly report (ios-prd §8.5). ⚠️ No report endpoint exists in the
//  API yet — these model an assumed `GET /v1/reports/{member_id}?weeks=`
//  response (spec'd in docs/auth-endpoints.md).
//

import Foundation

/// One week's aggregates for a teen.
struct ReportWeek: Decodable, Identifiable {
    /// Week start, `YYYY-MM-DD` (household-local).
    let weekStart: String
    /// Completion rate 0…1 (completed / non-cancelled tasks that week).
    let completionRate: Double
    /// Number of excuses submitted that week.
    let excuseCount: Int
    /// Net points earned that week.
    let pointsEarned: Int

    var id: String { weekStart }

    /// Parsed week-start for chart axes.
    var date: Date { Self.formatter.date(from: weekStart) ?? .now }

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case completionRate = "completion_rate"
        case excuseCount = "excuse_count"
        case pointsEarned = "points_earned"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

struct Report: Decodable {
    let weeks: [ReportWeek]
}
