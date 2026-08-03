//
//  OutboxAction.swift
//  KidsChores
//
//  A durably-queued mutating task action (ios-prd §12 "write path"). The
//  idempotency key is generated once at optimistic-write time and persisted
//  here, then reused verbatim on every retry — this is what makes indefinite
//  retry safe against double-completion (API §2).
//

import Foundation
import SwiftData

enum OutboxActionKind: String, Codable {
    case complete
    case excuse
    case cancel
}

@Model
final class OutboxAction {
    /// One key per user action; unique so an action can't be enqueued twice.
    @Attribute(.unique) var idempotencyKey: String
    var instanceID: String
    var kindRaw: String
    /// Excuse text / completion note / cancel reason, as applicable.
    var text: String?
    var createdAt: Date
    var attempts: Int

    init(idempotencyKey: String, instanceID: String, kind: OutboxActionKind,
         text: String?, createdAt: Date = .now) {
        self.idempotencyKey = idempotencyKey
        self.instanceID = instanceID
        self.kindRaw = kind.rawValue
        self.text = text
        self.createdAt = createdAt
        self.attempts = 0
    }

    var kind: OutboxActionKind { OutboxActionKind(rawValue: kindRaw) ?? .complete }
}
