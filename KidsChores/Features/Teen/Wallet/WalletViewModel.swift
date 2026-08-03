//
//  WalletViewModel.swift
//  KidsChores
//
//  Drives the Wallet screen (ios-prd §7.3) — the emotional center of the app.
//  Balance + active goal + paginated ledger, plus claim submission and goal
//  creation. Balance is always server-computed; we re-fetch it after any action
//  that could change it (API §10).
//

import Foundation

@MainActor
@Observable
final class WalletViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    private(set) var balance: Int = 0
    private(set) var pointsLabel: String = "points"
    private(set) var goal: SavingsGoal?

    private(set) var ledger: [LedgerEntry] = []
    private(set) var isLoadingPage = false
    private var hasMore = true
    private var offset = 0
    private let pageSize = 50

    var errorMessage: String?

    private let memberID: String
    private let walletService: WalletService

    init(memberID: String, walletService: WalletService) {
        self.memberID = memberID
        self.walletService = walletService
    }

    var goalFraction: Double? {
        guard let goal, goal.targetPoints > 0 else { return nil }
        return min(Double(balance) / Double(goal.targetPoints), 1)
    }

    /// Neutral (not sad) empty ledger — a brand-new teen with no history yet.
    var ledgerIsEmpty: Bool { ledger.isEmpty && !isLoadingPage }

    /// Ledger entry by id, for the iPad detail pane.
    func ledgerEntry(for id: String) -> LedgerEntry? {
        ledger.first { $0.id == id }
    }

    // MARK: - Loading

    func load() async {
        state = ledger.isEmpty ? .loading : .loaded
        await loadWallet()
        await resetLedger()
    }

    func refresh() async {
        await loadWallet()
        await resetLedger()
    }

    private func loadWallet() async {
        do {
            let wallet = try await walletService.wallet(memberID: memberID)
            balance = wallet.balance
            pointsLabel = wallet.pointsLabel
            goal = wallet.activeSavingsGoal
            state = .loaded
        } catch {
            if ledger.isEmpty { state = .failed(Self.message(for: error)) }
        }
    }

    private func resetLedger() async {
        offset = 0
        hasMore = true
        ledger = []
        await loadNextPage()
    }

    func loadMoreIfNeeded(currentItem: LedgerEntry) async {
        guard hasMore, !isLoadingPage,
              currentItem.id == ledger.last?.id else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard hasMore, !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }
        do {
            let page = try await walletService.ledger(memberID: memberID, limit: pageSize, offset: offset)
            ledger.append(contentsOf: page)
            offset += page.count
            hasMore = page.count == pageSize
        } catch {
            hasMore = false
            if ledger.isEmpty && state != .loaded { state = .failed(Self.message(for: error)) }
        }
    }

    // MARK: - Actions

    /// Submits a claim. Points are NOT debited until a parent fulfils it (API
    /// §10), so balance is unchanged here.
    func submitClaim(points: Int, item: String) async -> Bool {
        do {
            _ = try await walletService.createClaim(
                CreateClaimRequest(points: points, requestedItem: item))
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func createGoal(title: String, target: Int) async {
        do {
            _ = try await walletService.createGoal(
                memberID: memberID, CreateGoalRequest(title: title, targetPoints: target))
            await loadWallet()               // surface the new goal card
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
