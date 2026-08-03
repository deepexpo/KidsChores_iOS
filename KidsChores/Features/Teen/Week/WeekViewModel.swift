//
//  WeekViewModel.swift
//  KidsChores
//
//  Drives the Week screen (ios-prd §7.2): a 7-day window grouped by day,
//  mirroring Today's row style and reusing the same optimistic-write path
//  (overlay + Outbox). Series progress cards inserted inline are a follow-up
//  (needs per-window series-instance data).
//
//  NOTE: day bucketing uses the device calendar for now; it should use the
//  household timezone (GET /v1/household → timezone) once that's threaded here.
//

import Foundation

@MainActor
@Observable
final class WeekViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    struct DayGroup: Identifiable, Equatable {
        let id: Date            // start-of-day
        let date: Date
        var rows: [WeekRow]
        var isToday: Bool
    }

    struct WeekRow: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String?
        let dueAt: Date
        let pointValue: Int
        let status: TaskStatus
        let requiresReview: Bool
        let inSeries: Bool
        /// Due on a day after today.
        let isFuture: Bool
        var conflictNote: String?

        var canComplete: Bool {
            guard status == .pending || status == .overdue else { return false }
            // A future-dated task can be completed early only as part of a
            // series (so a teen can knock the whole series out ahead of time);
            // a stand-alone future task waits until its day.
            return isFuture ? inSeries : true
        }
        // Excusing an upcoming task is allowed (PRD §6.3 / API §7).
        var canExcuse: Bool { status == .pending || status == .overdue }

        var detail: TaskDetail {
            TaskDetail(id: id, title: title, description: description, dueAt: dueAt,
                       pointValue: pointValue, status: status, requiresReview: requiresReview,
                       inSeries: inSeries, conflictNote: conflictNote,
                       canComplete: canComplete, canExcuse: canExcuse)
        }
    }

    /// Look up a row across all day groups (for the detail pane).
    func row(for id: String) -> WeekRow? {
        for day in days {
            if let match = day.rows.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    private(set) var state: ViewState = .loading
    private(set) var days: [DayGroup] = []
    private(set) var weekStart: Date
    private(set) var isOffline = false

    private let memberID: String
    private let taskService: TaskService
    private let definitionCache: DefinitionCache
    private let outbox: Outbox
    private let taskCache: TaskCache
    private let calendar: Calendar

    private var instances: [TaskInstance] = []
    private var statusOverride: [String: TaskStatus] = [:]
    private var conflictNote: [String: String] = [:]

    init(memberID: String,
         taskService: TaskService,
         definitionCache: DefinitionCache,
         outbox: Outbox,
         taskCache: TaskCache,
         calendar: Calendar = .current) {
        self.memberID = memberID
        self.taskService = taskService
        self.definitionCache = definitionCache
        self.outbox = outbox
        self.taskCache = taskCache
        self.calendar = calendar
        self.weekStart = Self.startOfWeek(for: .now, calendar: calendar)
    }

    var todayID: Date { calendar.startOfDay(for: .now) }

    // MARK: - Loading

    func load() async {
        if instances.isEmpty {
            let cached = taskCache.load(scope: .week, memberID: memberID)
            if cached.isEmpty {
                state = .loading
            } else {
                instances = cached
                await rebuild()
            }
        }
        await definitionCache.refreshIfNeeded()
        do {
            let fetched = try await taskService.week(start: Self.apiDate(weekStart), memberID: memberID)
            instances = fetched
            isOffline = false
            taskCache.save(scope: .week, memberID: memberID, instances: fetched)
            await rebuild()
            reconcile(await outbox.drain())
        } catch {
            if instances.isEmpty {
                state = .failed(Self.message(for: error))
            } else {
                isOffline = true
            }
        }
    }

    func refresh() async {
        await definitionCache.refresh()
        await load()
    }

    // MARK: - Actions (optimistic, shared pattern with Today)

    func complete(_ row: WeekRow) async {
        guard row.canComplete else { return }
        let requiresReview = await definitionRequiresReview(row.id)
        applyOptimistic(row.id, status: requiresReview ? .reviewPending : .complete)
        Haptics.success()
        let key = UUID().uuidString
        outbox.enqueue(kind: .complete, instanceID: row.id, text: nil, key: key)
        reconcile(await outbox.drain())
    }

    func excuse(_ row: WeekRow, text: String) async {
        guard row.canExcuse else { return }
        applyOptimistic(row.id, status: .excusePending)
        Haptics.impact()
        let key = UUID().uuidString
        outbox.enqueue(kind: .excuse, instanceID: row.id, text: text, key: key)
        reconcile(await outbox.drain())
    }

    private func applyOptimistic(_ id: String, status: TaskStatus) {
        statusOverride[id] = status
        conflictNote[id] = nil
        Task { await rebuild() }
    }

    private func reconcile(_ conflicts: [OutboxConflict]) {
        guard !conflicts.isEmpty else { return }
        for conflict in conflicts {
            statusOverride[conflict.id] = nil
            conflictNote[conflict.id] = conflict.message
        }
        Task { await rebuild() }
    }

    // MARK: - Assembly

    private func rebuild() async {
        // Seven empty day buckets first, so days with no tasks still render.
        var buckets: [Date: [WeekRow]] = [:]
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                buckets[calendar.startOfDay(for: day)] = []
            }
        }

        let today = todayID
        for instance in instances {
            let status = statusOverride[instance.id] ?? instance.status
            if status == .cancelled { continue }
            let day = calendar.startOfDay(for: instance.dueAt)
            guard buckets[day] != nil else { continue }
            let definition = await definitionCache.definition(for: instance.definitionID)
            let row = WeekRow(
                id: instance.id,
                title: await definitionCache.title(for: instance),
                description: definition?.description,
                dueAt: instance.dueAt,
                pointValue: instance.pointValue,
                status: status,
                requiresReview: definition?.requiresReview ?? false,
                inSeries: instance.seriesInstanceID != nil,
                isFuture: day > today,
                conflictNote: conflictNote[instance.id])
            buckets[day, default: []].append(row)
        }

        days = buckets.keys.sorted().map { day in
            DayGroup(id: day, date: day,
                     rows: (buckets[day] ?? []).sorted { $0.dueAt < $1.dueAt },
                     isToday: calendar.isDate(day, inSameDayAs: today))
        }
        state = .loaded
    }

    private func definitionRequiresReview(_ instanceID: String) async -> Bool {
        guard let instance = instances.first(where: { $0.id == instanceID }) else { return false }
        return await definitionCache.definition(for: instance.definitionID)?.requiresReview ?? false
    }

    // MARK: - Helpers

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
