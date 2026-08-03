//
//  Enums.swift
//  KidsChores
//
//  Wire enums, verbatim from API reference §4. Values are lowercase snake_case
//  strings on the wire. Every enum carries an `unknown` fallback for
//  forward-compatibility (see ForwardCompatibleEnum).
//

import Foundation

enum MemberRole: String, ForwardCompatibleEnum {
    case parent
    case teen
    case unknown
}

enum TaskStatus: String, ForwardCompatibleEnum {
    case pending
    case reviewPending = "review_pending"
    case complete
    case overdue
    case excusePending = "excuse_pending"
    case excused
    case missed
    case cancelled
    case unknown
}

enum ScheduleType: String, ForwardCompatibleEnum {
    case oneTime = "one_time"
    case daily
    case weekdays
    case weekly
    case unknown
}

enum ExcusedPayoutPolicy: String, ForwardCompatibleEnum {
    case excusedPaysNothing = "excused_pays_nothing"
    case excusedPaysPartial = "excused_pays_partial"
    case excusedPaysFull = "excused_pays_full"
    case unknown
}

enum SeriesPayoutMode: String, ForwardCompatibleEnum {
    case individualPlusBonus = "individual_plus_bonus"
    case allOrNothing = "all_or_nothing"
    case unknown
}

enum SeriesWindowType: String, ForwardCompatibleEnum {
    case weekly
    case monthly
    /// ⚠️ Server currently falls back to a 7-day window for `custom`; do not
    /// offer it as a picker option in v1 UI (API reference §9).
    case custom
    case unknown
}

enum SeriesStatus: String, ForwardCompatibleEnum {
    case active
    case complete
    case expired
    case unknown
}

enum LedgerEntryType: String, ForwardCompatibleEnum {
    case taskCompleted = "task_completed"
    case seriesBonus = "series_bonus"
    case excusedPartial = "excused_partial"
    case claimFulfilled = "claim_fulfilled"
    case manualAdjustment = "manual_adjustment"
    case reversal
    case unknown
}

enum ClaimStatus: String, ForwardCompatibleEnum {
    case pending
    case fulfilled
    case declined
    case unknown
}

/// The two kinds of item that appear in the parent inbox (`GET /v1/approvals`).
enum ApprovalType: String, ForwardCompatibleEnum {
    case completion
    case excuse
    case unknown
}
