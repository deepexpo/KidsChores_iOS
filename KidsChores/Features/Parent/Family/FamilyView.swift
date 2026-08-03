//
//  FamilyView.swift
//  KidsChores
//
//  Per-teen summary cards (ios-prd §8.2). Tap a teen for their detail (balance,
//  completion, adjust points, recent ledger).
//

import SwiftUI

struct FamilyView: View {
    @Environment(AppSession.self) private var session
    @State private var vm: FamilyViewModel
    @State private var showSettings = false
    @State private var showAddTeen = false
    private let walletService: WalletService
    private let householdService: HouseholdService

    init(householdService: HouseholdService,
         walletService: WalletService,
         taskService: TaskService) {
        self.walletService = walletService
        self.householdService = householdService
        _vm = State(initialValue: FamilyViewModel(
            householdService: householdService,
            walletService: walletService,
            taskService: taskService))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Family")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddTeen = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
                .task { await vm.load() }
                .refreshable { await vm.load() }
                .sheet(isPresented: $showSettings) {
                    HouseholdSettingsView(service: householdService)
                }
                .sheet(isPresented: $showAddTeen) {
                    AddTeenView(householdService: householdService,
                                pinStore: session.pinStore,
                                onCreated: { Task { await vm.load() } })
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load your family",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .empty:
            EmptyStateView(icon: "person.2", headline: "No teens yet",
                           subline: "Teen profiles you add will show up here.", kind: .neutral)
        case .loaded:
            list
        }
    }

    private var list: some View {
        List(vm.teens) { teen in
            NavigationLink {
                FamilyMemberDetailView(
                    member: teen.member,
                    completedThisWeek: teen.completedThisWeek,
                    totalThisWeek: teen.totalThisWeek,
                    walletService: walletService,
                    householdService: householdService,
                    pinStore: session.pinStore,
                    onDeleted: { Task { await vm.load() } })
            } label: {
                card(teen)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func card(_ teen: FamilyViewModel.TeenSummary) -> some View {
        HStack(spacing: 14) {
            SeriesProgressRing(completed: teen.completedThisWeek,
                               total: teen.totalThisWeek, lineWidth: 6, diameter: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(teen.member.displayName).font(.headline)
                Text("\(teen.balance) \(teen.pointsLabel)")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                Text("\(teen.completedThisWeek) of \(teen.totalThisWeek) done this week")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
