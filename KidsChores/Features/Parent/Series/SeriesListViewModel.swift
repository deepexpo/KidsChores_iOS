//
//  SeriesListViewModel.swift
//  KidsChores
//
//  Series list (ios-prd §8.4) with the active window's progress per series.
//

import Foundation

@MainActor
@Observable
final class SeriesListViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    struct Row: Identifiable {
        let series: Series
        let assigneeName: String
        /// Parsed from the active instance's "X of Y complete" string, if any.
        let completed: Int
        let total: Int
        var id: String { series.id }
        var hasProgress: Bool { total > 0 }
    }

    private(set) var state: ViewState = .loading
    private(set) var rows: [Row] = []
    private(set) var assignees: [Member] = []
    var errorMessage: String?

    private let seriesService: SeriesService
    private let householdService: HouseholdService
    private var membersByID: [String: Member] = [:]

    init(seriesService: SeriesService, householdService: HouseholdService) {
        self.seriesService = seriesService
        self.householdService = householdService
    }

    func load() async {
        if rows.isEmpty { state = .loading }
        do {
            async let membersCall = householdService.members()
            async let seriesCall = seriesService.series(includeArchived: false)
            let (members, series) = try await (membersCall, seriesCall)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            assignees = members.filter { $0.role == .teen }

            var built: [Row] = []
            for s in series {
                let instances = (try? await seriesService.seriesInstances(seriesID: s.id)) ?? []
                let active = instances.first { $0.status == .active } ?? instances.last
                let (done, total) = Self.parseProgress(active?.progress)
                built.append(Row(series: s,
                                 assigneeName: membersByID[s.assigneeID]?.displayName ?? "Unknown",
                                 completed: done, total: total))
            }
            rows = built.sorted { $0.series.name < $1.series.name }
            state = rows.isEmpty ? .empty : .loaded
        } catch {
            if rows.isEmpty { state = .failed(Self.message(for: error)) }
        }
    }

    /// Archive (delete) a series — `DELETE /v1/series/{id}`.
    func archive(seriesID: String) async {
        do {
            try await seriesService.archiveSeries(id: seriesID)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Edit a series' name/bonus. Returns true on success.
    func update(seriesID: String, name: String, bonusPoints: Int) async -> Bool {
        do {
            _ = try await seriesService.updateSeries(
                id: seriesID, SeriesUpdateRequest(name: name, bonusPoints: bonusPoints))
            await load()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// "2 of 3 complete" → (2, 3). Returns (0, 0) when nil/unparseable.
    static func parseProgress(_ string: String?) -> (Int, Int) {
        guard let parts = string?.split(separator: " "),
              parts.count >= 3,
              let done = Int(parts[0]), let total = Int(parts[2]) else { return (0, 0) }
        return (done, total)
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
