//
//  ReportsViewModel.swift
//  KidsChores
//
//  Drives the Reports screen (ios-prd §8.5): a teen picker + range toggle
//  (4/12 weeks) over a per-teen weekly report.
//

import Foundation

@MainActor
@Observable
final class ReportsViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case noTeens
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    private(set) var teens: [Member] = []
    var selectedTeenID: String? {
        didSet { if oldValue != selectedTeenID { Task { await loadReport() } } }
    }
    var weeks: Int = 12 {
        didSet { if oldValue != weeks { Task { await loadReport() } } }
    }
    private(set) var report: Report?
    private(set) var isLoadingReport = false

    private let reportService: ReportService
    private let householdService: HouseholdService

    init(reportService: ReportService, householdService: HouseholdService) {
        self.reportService = reportService
        self.householdService = householdService
    }

    var selectedTeen: Member? { teens.first { $0.id == selectedTeenID } }
    /// The report's weeks that actually have data.
    var hasData: Bool { (report?.weeks.isEmpty == false) }

    func load() async {
        state = .loading
        do {
            teens = try await householdService.members().filter { $0.role == .teen }
            guard !teens.isEmpty else { state = .noTeens; return }
            if selectedTeenID == nil { selectedTeenID = teens.first?.id }
            await loadReport()
            state = .loaded
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func loadReport() async {
        guard let id = selectedTeenID else { return }
        isLoadingReport = true
        defer { isLoadingReport = false }
        report = try? await reportService.report(memberID: id, weeks: weeks)
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
