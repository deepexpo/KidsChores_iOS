//
//  FamilyViewModel.swift
//  KidsChores
//
//  Per-teen summary cards (ios-prd §8.2): balance + this-week completion rate.
//  (Outstanding-claims count is omitted — there is no list-claims endpoint in
//  the API today; add it back when one exists.)
//

import Foundation

@MainActor
@Observable
final class FamilyViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    struct TeenSummary: Identifiable {
        let member: Member
        let balance: Int
        let pointsLabel: String
        let completedThisWeek: Int
        let totalThisWeek: Int
        var id: String { member.id }

        var completionFraction: Double {
            totalThisWeek > 0 ? Double(completedThisWeek) / Double(totalThisWeek) : 0
        }
    }

    private(set) var state: ViewState = .loading
    private(set) var teens: [TeenSummary] = []

    private let householdService: HouseholdService
    private let walletService: WalletService
    private let taskService: TaskService
    private let calendar: Calendar

    init(householdService: HouseholdService,
         walletService: WalletService,
         taskService: TaskService,
         calendar: Calendar = .current) {
        self.householdService = householdService
        self.walletService = walletService
        self.taskService = taskService
        self.calendar = calendar
    }

    func load() async {
        if teens.isEmpty { state = .loading }
        do {
            let members = try await householdService.members().filter { $0.role == .teen }
            guard !members.isEmpty else { teens = []; state = .empty; return }

            let weekStart = Self.apiWeekStart(calendar: calendar)
            let summaries = try await withThrowingTaskGroup(of: TeenSummary.self) { group in
                for member in members {
                    group.addTask { [walletService, taskService] in
                        async let wallet = walletService.wallet(memberID: member.id)
                        async let week = taskService.week(start: weekStart, memberID: member.id)
                        let (w, tasks) = try await (wallet, week)
                        let active = tasks.filter { $0.status != .cancelled }
                        let done = active.filter { $0.status == .complete || $0.status == .excused }
                        return TeenSummary(
                            member: member, balance: w.balance, pointsLabel: w.pointsLabel,
                            completedThisWeek: done.count, totalThisWeek: active.count)
                    }
                }
                var result: [TeenSummary] = []
                for try await summary in group { result.append(summary) }
                return result
            }
            teens = summaries.sorted { $0.member.displayName < $1.member.displayName }
            state = .loaded
        } catch {
            if teens.isEmpty { state = .failed(Self.message(for: error)) }
        }
    }

    private static func apiWeekStart(calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: .now)
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
