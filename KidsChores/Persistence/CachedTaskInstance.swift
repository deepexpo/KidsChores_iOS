//
//  CachedTaskInstance.swift
//  KidsChores
//
//  Local mirror of a TaskInstance for the offline read path (ios-prd §12). The
//  UI always renders from this store; the network refreshes it. Tagged by
//  `scope` (today/week) + `memberID` so a shared iPad's teens don't collide.
//

import Foundation
import SwiftData

enum TaskCacheScope: String, Codable {
    case today
    case week
}

@Model
final class CachedTaskInstance {
    var instanceID: String
    var scopeRaw: String
    var memberID: String
    var sortIndex: Int

    var definitionID: String
    var assigneeID: String
    var dueAt: Date
    var pointValue: Int
    var statusRaw: String
    var completedAt: Date?
    var completionNote: String?
    var excuseText: String?
    var reviewComment: String?
    var seriesInstanceID: String?

    init(instance: TaskInstance, scope: TaskCacheScope, memberID: String, sortIndex: Int) {
        self.instanceID = instance.id
        self.scopeRaw = scope.rawValue
        self.memberID = memberID
        self.sortIndex = sortIndex
        self.definitionID = instance.definitionID
        self.assigneeID = instance.assigneeID
        self.dueAt = instance.dueAt
        self.pointValue = instance.pointValue
        self.statusRaw = instance.status.rawValue
        self.completedAt = instance.completedAt
        self.completionNote = instance.completionNote
        self.excuseText = instance.excuseText
        self.reviewComment = instance.reviewComment
        self.seriesInstanceID = instance.seriesInstanceID
    }

    /// Rebuild the API model from the cached row (title/description stay nil,
    /// exactly as the API returns them — joined via DefinitionCache).
    var taskInstance: TaskInstance {
        TaskInstance(
            id: instanceID,
            definitionID: definitionID,
            assigneeID: assigneeID,
            dueAt: dueAt,
            pointValue: pointValue,
            status: TaskStatus(rawValue: statusRaw) ?? .unknown,
            completedAt: completedAt,
            completionNote: completionNote,
            excuseText: excuseText,
            reviewComment: reviewComment,
            seriesInstanceID: seriesInstanceID,
            title: nil,
            description: nil)
    }
}
