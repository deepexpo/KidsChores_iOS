//
//  InboxViewModel.swift
//  KidsChores
//
//  Drives the parent approval inbox (ios-prd §8.1). Approvals are listed via
//  ApprovalService and resolved via TaskService.review (single) or
//  ApprovalService.bulkResolve (multi-select).
//
//  Undo model: there is no un-approve endpoint (see api-reference), so undo
//  MUST be cancel-before-send — an approved card is removed optimistically and
//  the review call is held for the toast window, then fired (or cancelled).
//

import Foundation

@MainActor
@Observable
final class InboxViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        /// Empty here is the *success* state (ios-prd §8.1 / §10.2).
        case caughtUp
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    private(set) var items: [ApprovalItem] = []

    /// The card currently in its ~4s undo window, if any (drives the toast).
    private(set) var undoItem: ApprovalItem?
    /// Transient error surfaced when a resolve call ultimately fails.
    var errorMessage: String?

    // Multi-select
    var isSelecting = false
    var selection: Set<String> = []

    private let approvalService: ApprovalService
    private let taskService: TaskService
    private var undoTask: Task<Void, Never>?

    init(approvalService: ApprovalService, taskService: TaskService) {
        self.approvalService = approvalService
        self.taskService = taskService
    }

    // MARK: - Loading

    func load() async {
        if items.isEmpty { state = .loading }
        do {
            let fetched = try await approvalService.approvals()
            items = fetched.sorted { $0.submittedAt < $1.submittedAt }   // oldest-first
            state = items.isEmpty ? .caughtUp : .loaded
        } catch {
            if items.isEmpty { state = .failed(Self.message(for: error)) }
        }
    }

    func refresh() async { await load() }

    // MARK: - Single approve (with undo / cancel-before-send)

    func approve(_ item: ApprovalItem) {
        flushPendingUndo()                 // finalize any prior pending approve
        remove(item)
        Haptics.success()
        undoItem = item
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            await self.finalizeApprove(item)
            if self.undoItem?.id == item.id { self.undoItem = nil }
        }
    }

    func undoApprove() {
        undoTask?.cancel()
        undoTask = nil
        if let item = undoItem {
            reinsert(item)
            undoItem = nil
        }
    }

    /// If the user acts again before the toast elapses, commit the pending one now.
    private func flushPendingUndo() {
        guard let pending = undoItem else { return }
        undoTask?.cancel()
        undoTask = nil
        undoItem = nil
        Task { await finalizeApprove(pending) }
    }

    private func finalizeApprove(_ item: ApprovalItem) async {
        do {
            _ = try await taskService.review(
                instanceID: item.taskInstanceID,
                ReviewRequest(idempotencyKey: UUID().uuidString, approve: true, comment: nil))
        } catch {
            reinsert(item)                 // couldn't approve — put it back
            errorMessage = "Couldn't approve \(item.taskTitle). It's back in your inbox."
        }
    }

    // MARK: - Single deny (comment required)

    func deny(_ item: ApprovalItem, comment: String) async {
        remove(item)
        Haptics.warning()
        do {
            _ = try await taskService.review(
                instanceID: item.taskInstanceID,
                ReviewRequest(idempotencyKey: UUID().uuidString, approve: false, comment: comment))
        } catch {
            reinsert(item)
            errorMessage = "Couldn't deny \(item.taskTitle). It's back in your inbox."
        }
    }

    // MARK: - Bulk

    func bulkApprove() async {
        await bulk(approve: true, comment: nil)
    }

    func bulkDeny(comment: String) async {
        await bulk(approve: false, comment: comment)
    }

    private func bulk(approve: Bool, comment: String?) async {
        let ids = selection
        guard !ids.isEmpty else { return }
        let requestItems = ids.map {
            BulkApprovalItemRequest(taskInstanceID: $0, approve: approve, comment: comment)
        }
        do {
            let response = try await approvalService.bulkResolve(
                BulkApprovalRequest(idempotencyKey: UUID().uuidString, items: requestItems))
            // A batch with some failures is expected, not an edge case (API §8).
            let failed = Set(response.results.filter { !$0.success }.map(\.taskInstanceID))
            items.removeAll { ids.contains($0.id) && !failed.contains($0.id) }
            if !failed.isEmpty {
                errorMessage = "\(failed.count) item\(failed.count == 1 ? "" : "s") couldn't be updated."
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
        selection.removeAll()
        isSelecting = false
        if items.isEmpty { state = .caughtUp }
    }

    // MARK: - List helpers

    private func remove(_ item: ApprovalItem) {
        items.removeAll { $0.id == item.id }
        if items.isEmpty && undoItem == nil { state = .caughtUp }
    }

    private func reinsert(_ item: ApprovalItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        items.sort { $0.submittedAt < $1.submittedAt }
        state = .loaded
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
