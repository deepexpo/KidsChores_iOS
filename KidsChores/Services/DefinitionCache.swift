//
//  DefinitionCache.swift
//  KidsChores
//
//  Works around the API §7 gap: TaskInstance.title/description are always nil,
//  so the client caches definitions and joins on `definitionID` for display.
//
//  An actor so the cache is safely shared across concurrent screen loads
//  (SRP: its one job is "resolve a definition id to its template").
//

import Foundation

actor DefinitionCache {
    private let service: DefinitionService
    private var byID: [String: TaskDefinition] = [:]
    private var lastRefresh: Date?

    init(service: DefinitionService) {
        self.service = service
    }

    /// Ensures the cache is warm, refreshing if empty or older than `maxAge`.
    /// The teen device never opens a definition-management screen, so the
    /// refresh trigger lives here (called from Today/Week load), not there.
    func refreshIfNeeded(maxAge: TimeInterval = 300) async {
        if let last = lastRefresh, Date().timeIntervalSince(last) < maxAge, !byID.isEmpty {
            return
        }
        await refresh()
    }

    /// Force a refresh (e.g. pull-to-refresh).
    func refresh() async {
        guard let defs = try? await service.definitions(includeArchived: true) else { return }
        byID = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
        lastRefresh = Date()
    }

    func definition(for id: String) -> TaskDefinition? { byID[id] }

    /// Display title for an instance, preferring the instance's own title if the
    /// backend ever starts populating it, then the joined definition, then a
    /// stable placeholder (never an empty row).
    func title(for instance: TaskInstance) -> String {
        instance.title ?? byID[instance.definitionID]?.title ?? "Task"
    }
}
