//
//  Outbox.swift
//  KidsChores
//
//  Drains queued task mutations FIFO (ios-prd §12). Depends only on
//  `TaskService` (DIP) so it's testable without a live network. Draining is
//  triggered after each enqueue and on foreground/pull-to-refresh; a proper
//  NWPathMonitor connectivity trigger is a follow-up.
//

import Foundation
import SwiftData

/// Reported when a queued action can never succeed (e.g. the task was cancelled
/// by a parent while the teen was offline → 422 illegal transition). The caller
/// reverts the optimistic state and shows a non-blocking inline notice.
struct OutboxConflict: Identifiable {
    let id: String          // instanceID
    let message: String
}

@MainActor
@Observable
final class Outbox {
    private let context: ModelContext
    private let taskService: TaskService

    private(set) var pendingCount: Int = 0
    private var isDraining = false

    init(container: ModelContainer, taskService: TaskService) {
        self.context = ModelContext(container)
        self.taskService = taskService
        refreshCount()
    }

    /// Persist an action. Safe to call from an optimistic UI write.
    func enqueue(kind: OutboxActionKind, instanceID: String, text: String?, key: String) {
        let action = OutboxAction(idempotencyKey: key, instanceID: instanceID, kind: kind, text: text)
        context.insert(action)
        try? context.save()
        refreshCount()
    }

    /// Attempt to send every queued action, oldest first. Returns the set of
    /// permanent conflicts the caller should reconcile. Transport/auth failures
    /// stop the drain silently — the queue survives for the next attempt.
    @discardableResult
    func drain() async -> [OutboxConflict] {
        guard !isDraining else { return [] }
        isDraining = true
        defer { isDraining = false; refreshCount() }

        var conflicts: [OutboxConflict] = []
        let pending = (try? context.fetch(
            FetchDescriptor<OutboxAction>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )) ?? []

        for action in pending {
            action.attempts += 1
            do {
                try await send(action)
                context.delete(action)
            } catch let error as APIError {
                switch error {
                case .unprocessable(let detail):
                    // Illegal transition — will never succeed. Drop + report.
                    conflicts.append(OutboxConflict(
                        id: action.instanceID,
                        message: detail ?? "This task changed and couldn't be updated."))
                    context.delete(action)
                case .forbidden, .notFound:
                    context.delete(action)               // unrecoverable, drop
                case .unauthorized, .transport, .server, .decoding, .rateLimited:
                    try? context.save()                  // keep; retry later
                    return conflicts                     // stop draining now
                }
            } catch {
                try? context.save()
                return conflicts
            }
        }
        try? context.save()
        return conflicts
    }

    private func send(_ action: OutboxAction) async throws {
        let key = action.idempotencyKey
        switch action.kind {
        case .complete:
            _ = try await taskService.complete(
                instanceID: action.instanceID,
                CompleteTaskRequest(idempotencyKey: key, note: action.text))
        case .excuse:
            _ = try await taskService.excuse(
                instanceID: action.instanceID,
                ExcuseTaskRequest(idempotencyKey: key, excuseText: action.text ?? ""))
        case .cancel:
            _ = try await taskService.cancel(
                instanceID: action.instanceID,
                CancelTaskRequest(idempotencyKey: key, reason: action.text))
        }
    }

    private func refreshCount() {
        pendingCount = (try? context.fetchCount(FetchDescriptor<OutboxAction>())) ?? 0
    }
}
