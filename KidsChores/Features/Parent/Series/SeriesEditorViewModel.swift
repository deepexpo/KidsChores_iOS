//
//  SeriesEditorViewModel.swift
//  KidsChores
//
//  Create a series (ios-prd §8.4): name, assignee, bonus, payout mode, window
//  type (weekly/monthly — `custom` is omitted per API §9), and a multi-select
//  of the assignee's existing definitions to bundle.
//

import Foundation

@MainActor
@Observable
final class SeriesEditorViewModel {
    var name = ""
    var assigneeID: String
    var bonusPoints = 50
    var payoutMode: SeriesPayoutMode = .individualPlusBonus
    var windowType: SeriesWindowType = .weekly
    var selectedDefinitionIDs: Set<String> = []

    var isSaving = false
    var errorMessage: String?

    let assignees: [Member]
    private(set) var availableDefinitions: [TaskDefinition] = []
    private var allDefinitions: [TaskDefinition] = []

    private let seriesService: SeriesService
    private let definitionService: DefinitionService
    private let onSaved: () -> Void

    init(assignees: [Member],
         seriesService: SeriesService,
         definitionService: DefinitionService,
         onSaved: @escaping () -> Void) {
        self.assignees = assignees
        self.assigneeID = assignees.first?.id ?? ""
        self.seriesService = seriesService
        self.definitionService = definitionService
        self.onSaved = onSaved
    }

    func load() async {
        allDefinitions = (try? await definitionService.definitions(includeArchived: false)) ?? []
        filterForAssignee()
    }

    func assigneeChanged() {
        selectedDefinitionIDs.removeAll()
        filterForAssignee()
    }

    private func filterForAssignee() {
        availableDefinitions = allDefinitions
            .filter { $0.assigneeID == assigneeID }
            .sorted { $0.title < $1.title }
    }

    func toggle(_ id: String) {
        if selectedDefinitionIDs.contains(id) { selectedDefinitionIDs.remove(id) }
        else { selectedDefinitionIDs.insert(id) }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !assigneeID.isEmpty &&
        bonusPoints >= 1 &&
        !selectedDefinitionIDs.isEmpty
    }

    func save() async {
        guard isValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await seriesService.createSeries(
                CreateSeriesRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    assigneeID: assigneeID,
                    bonusPoints: bonusPoints,
                    payoutMode: payoutMode,
                    windowType: windowType,
                    taskDefinitionIDs: Array(selectedDefinitionIDs)))
            onSaved()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func explainer(for mode: SeriesPayoutMode) -> String {
        switch mode {
        case .individualPlusBonus:
            return "Each task pays its own value; the bonus is added when all are done."
        case .allOrNothing:
            return "Tasks pay nothing on their own — the teen gets the full total plus the bonus only when all are done."
        case .unknown:
            return ""
        }
    }

    private static func message(for error: Error) -> String {
        if case APIError.unprocessable(let detail) = error { return detail ?? "Please check the form." }
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Couldn't save. Please try again."
    }
}
