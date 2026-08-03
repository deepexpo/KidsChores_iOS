//
//  TasksViewModel.swift
//  KidsChores
//
//  Task-definition management list (ios-prd §8.3): definitions grouped by
//  assignee, archived hidden by default. Needs members for the assignee picker
//  and for name lookup.
//

import Foundation

@MainActor
@Observable
final class TasksViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    struct Group: Identifiable {
        let id: String          // assignee id
        let assigneeName: String
        let definitions: [TaskDefinition]
    }

    private(set) var state: ViewState = .loading
    private(set) var groups: [Group] = []
    var showArchived = false {
        didSet { Task { await load() } }
    }

    /// Teens, for the editor's assignee picker.
    private(set) var assignees: [Member] = []
    var errorMessage: String?

    private let definitionService: DefinitionService
    private let householdService: HouseholdService
    private var membersByID: [String: Member] = [:]

    init(definitionService: DefinitionService, householdService: HouseholdService) {
        self.definitionService = definitionService
        self.householdService = householdService
    }

    func load() async {
        if groups.isEmpty { state = .loading }
        do {
            async let membersCall = householdService.members()
            async let defsCall = definitionService.definitions(includeArchived: showArchived)
            let (members, defs) = try await (membersCall, defsCall)

            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            assignees = members.filter { $0.role == .teen }
            rebuild(defs)
        } catch {
            if groups.isEmpty { state = .failed(Self.message(for: error)) }
        }
    }

    func archive(_ definition: TaskDefinition) async {
        do {
            try await definitionService.archiveDefinition(id: definition.id)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func rebuild(_ defs: [TaskDefinition]) {
        let visible = showArchived ? defs : defs.filter { !$0.isArchived }
        let grouped = Dictionary(grouping: visible, by: \.assigneeID)
        groups = grouped
            .map { assigneeID, defs in
                Group(id: assigneeID,
                      assigneeName: membersByID[assigneeID]?.displayName ?? "Unassigned",
                      definitions: defs.sorted { $0.title < $1.title })
            }
            .sorted { $0.assigneeName < $1.assigneeName }
        state = groups.isEmpty ? .empty : .loaded
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}

/// Short human summary of a definition's schedule for list rows.
func scheduleSummary(_ def: TaskDefinition) -> String {
    switch def.scheduleType {
    case .oneTime: return "One-time"
    case .daily: return "Daily"
    case .weekly: return "Weekly"
    case .weekdays: return WeekdayMask(mask: def.weekdayMask ?? 0).summary
    case .unknown: return "—"
    }
}
