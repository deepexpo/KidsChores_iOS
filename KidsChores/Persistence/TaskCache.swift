//
//  TaskCache.swift
//  KidsChores
//
//  Read-through cache for the teen's Today/Week lists (ios-prd §12 read path).
//  The view model renders from `load(...)` immediately on cold launch, then
//  `save(...)` replaces the scope's rows after a successful network fetch.
//

import Foundation
import SwiftData

@MainActor
final class TaskCache {
    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    /// Cached instances for a scope + member, in their stored order.
    func load(scope: TaskCacheScope, memberID: String) -> [TaskInstance] {
        let scopeRaw = scope.rawValue
        let descriptor = FetchDescriptor<CachedTaskInstance>(
            predicate: #Predicate { $0.scopeRaw == scopeRaw && $0.memberID == memberID },
            sortBy: [SortDescriptor(\.sortIndex, order: .forward)])
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map(\.taskInstance)
    }

    /// Replace the scope's cached rows with a fresh network result.
    func save(scope: TaskCacheScope, memberID: String, instances: [TaskInstance]) {
        let scopeRaw = scope.rawValue
        let existing = FetchDescriptor<CachedTaskInstance>(
            predicate: #Predicate { $0.scopeRaw == scopeRaw && $0.memberID == memberID })
        if let rows = try? context.fetch(existing) {
            for row in rows { context.delete(row) }
        }
        for (index, instance) in instances.enumerated() {
            context.insert(CachedTaskInstance(
                instance: instance, scope: scope, memberID: memberID, sortIndex: index))
        }
        try? context.save()
    }
}
