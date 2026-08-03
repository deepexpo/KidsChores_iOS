//
//  TodayViewModel.swift
//  KidsChores
//
//  Drives the Today screen (ios-prd §7.1). Reads via TaskService, joins titles
//  through DefinitionCache (API §7 gap), and writes optimistically through the
//  Outbox. Immutable `TaskInstance`s are never mutated — an override map layers
//  the optimistic status on top, so reverting a failed write is just a removal.
//

import Foundation

@MainActor
@Observable
final class TodayViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        /// `isGood` distinguishes "all done / nothing due" (affirming) from a
        /// brand-new teen with no tasks yet (neutral) — ios-prd §14.
        case empty(isGood: Bool)
        case failed(String)
    }

    /// A resolved row ready for `TaskRow`.
    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String?
        let dueAt: Date
        let pointValue: Int
        let status: TaskStatus
        let requiresReview: Bool
        let inSeries: Bool
        var conflictNote: String?

        var canComplete: Bool { status == .pending || status == .overdue }
        var canExcuse: Bool { status == .pending || status == .overdue }

        var detail: TaskDetail {
            TaskDetail(id: id, title: title, description: description, dueAt: dueAt,
                       pointValue: pointValue, status: status, requiresReview: requiresReview,
                       inSeries: inSeries, conflictNote: conflictNote,
                       canComplete: canComplete, canExcuse: canExcuse)
        }
    }

    /// Look up a row by id across both sections (for the detail pane).
    func row(for id: String) -> Row? {
        overdue.first { $0.id == id } ?? dueToday.first { $0.id == id }
    }

    private(set) var state: ViewState = .loading
    private(set) var overdue: [Row] = []
    private(set) var dueToday: [Row] = []
    private(set) var balance: Int?
    private(set) var pointsLabel: String = "points"
    /// True when we're showing cached tasks because the network fetch failed.
    private(set) var isOffline = false
    /// Set to the extra points when completing a task finishes a series (bonus /
    /// all-or-nothing payout), so the view can celebrate it (§6.4). Auto-clears.
    private(set) var seriesBonus: Int?

    private let memberID: String
    private let taskService: TaskService
    private let walletService: WalletService
    private let definitionCache: DefinitionCache
    private let outbox: Outbox
    private let taskCache: TaskCache

    // Raw instances plus the optimistic overlay.
    private var instances: [TaskInstance] = []
    private var statusOverride: [String: TaskStatus] = [:]
    private var conflictNote: [String: String] = [:]

    init(memberID: String,
         taskService: TaskService,
         walletService: WalletService,
         definitionCache: DefinitionCache,
         outbox: Outbox,
         taskCache: TaskCache) {
        self.memberID = memberID
        self.taskService = taskService
        self.walletService = walletService
        self.definitionCache = definitionCache
        self.outbox = outbox
        self.taskCache = taskCache
    }

    // MARK: - Loading

    func load() async {
        // Cold-launch offline: render the last-synced list immediately (§12).
        if instances.isEmpty {
            let cached = taskCache.load(scope: .today, memberID: memberID)
            if cached.isEmpty {
                state = .loading
            } else {
                instances = cached
                await rebuild()
            }
        }
        await definitionCache.refreshIfNeeded()
        do {
            let fetched = try await taskService.today(memberID: memberID)
            instances = fetched
            isOffline = false
            taskCache.save(scope: .today, memberID: memberID, instances: fetched)
            await rebuild()
            await loadWallet()
            // Drain anything left from a prior offline session.
            reconcile(await outbox.drain())
        } catch {
            // Keep showing cached content; flag offline rather than failing hard.
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

    private func loadWallet() async {
        if let wallet = try? await walletService.wallet(memberID: memberID) {
            balance = wallet.balance
            pointsLabel = wallet.pointsLabel
        }
    }

    // MARK: - Actions (optimistic)

    func complete(_ row: Row) async {
        guard row.canComplete else { return }
        let requiresReview = await definitionRequiresReview(row.id)
        let optimistic: TaskStatus = requiresReview ? .reviewPending : .complete
        applyOptimistic(row.id, status: optimistic)
        Haptics.success()

        let balanceBefore = balance ?? 0
        let key = UUID().uuidString
        outbox.enqueue(kind: .complete, instanceID: row.id, text: nil, key: key)
        reconcile(await outbox.drain())

        // A completed series task may have fired a bonus server-side (API §7).
        // If the balance jumped by more than this task's own value, a series
        // payout landed — celebrate the extra.
        if instanceInSeries(row.id) {
            await loadWallet()
            let gained = (balance ?? 0) - balanceBefore
            let extra = gained - row.pointValue
            if extra > 0 {
                seriesBonus = extra
                Haptics.celebrate()
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2.4))
                    self?.seriesBonus = nil
                }
            }
        }
    }

    func dismissSeriesBonus() { seriesBonus = nil }

    func excuse(_ row: Row, text: String) async {
        guard row.canExcuse else { return }
        applyOptimistic(row.id, status: .excusePending)
        Haptics.impact()
        let key = UUID().uuidString
        outbox.enqueue(kind: .excuse, instanceID: row.id, text: text, key: key)
        reconcile(await outbox.drain())
    }

    // MARK: - Overlay + reconciliation

    private func applyOptimistic(_ id: String, status: TaskStatus) {
        statusOverride[id] = status
        conflictNote[id] = nil
        Task { await rebuild() }
    }

    private func reconcile(_ conflicts: [OutboxConflict]) {
        guard !conflicts.isEmpty else { return }
        for conflict in conflicts {
            statusOverride[conflict.id] = nil      // revert optimistic state
            conflictNote[conflict.id] = conflict.message
        }
        Task { await rebuild() }
    }

    // MARK: - Row assembly

    private func rebuild() async {
        var overdueRows: [Row] = []
        var todayRows: [Row] = []

        for instance in instances {
            let status = statusOverride[instance.id] ?? instance.status
            if status == .cancelled { continue }
            let definition = await definitionCache.definition(for: instance.definitionID)
            let row = Row(
                id: instance.id,
                title: await definitionCache.title(for: instance),
                description: definition?.description,
                dueAt: instance.dueAt,
                pointValue: instance.pointValue,
                status: status,
                requiresReview: definition?.requiresReview ?? false,
                inSeries: instance.seriesInstanceID != nil,
                conflictNote: conflictNote[instance.id])
            if status == .overdue {
                overdueRows.append(row)
            } else {
                todayRows.append(row)
            }
        }

        overdueRows.sort { $0.dueAt < $1.dueAt }
        todayRows.sort { $0.dueAt < $1.dueAt }
        self.overdue = overdueRows
        self.dueToday = todayRows

        if instances.isEmpty {
            state = .empty(isGood: false)          // new teen, nothing assigned
        } else if overdueRows.isEmpty && todayRows.allSatisfy(\.isSettled) {
            state = .empty(isGood: true)           // everything handled — good
        } else {
            state = .loaded
        }
    }

    private func definitionRequiresReview(_ instanceID: String) async -> Bool {
        guard let instance = instances.first(where: { $0.id == instanceID }) else { return false }
        return await definitionCache.definition(for: instance.definitionID)?.requiresReview ?? false
    }

    private func instanceInSeries(_ id: String) -> Bool {
        instances.first(where: { $0.id == id })?.seriesInstanceID != nil
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}

private extension TodayViewModel.Row {
    /// A row that no longer needs action from the teen (kept visible per §7.1).
    var isSettled: Bool {
        switch status {
        case .complete, .excused, .missed, .reviewPending, .excusePending: return true
        case .pending, .overdue, .cancelled, .unknown: return false
        }
    }
}
