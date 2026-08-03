//
//  WalletView.swift
//  KidsChores
//
//  The wallet (ios-prd §7.3): big rounded balance, active goal (or a one-line
//  "set a goal" prompt), a primary Claim button, and the full transaction
//  history rendered verbatim from the server (reasons are pre-formatted).
//

import SwiftUI

struct WalletView: View {
    @State private var vm: WalletViewModel
    @State private var showClaim = false
    @State private var showGoal = false
    @State private var goalPromptDismissed = false
    /// Selected ledger entry → detail pane on iPad, push on iPhone (§7.3).
    @State private var selectedLedgerID: String?

    init(memberID: String, walletService: WalletService) {
        _vm = State(initialValue: WalletViewModel(memberID: memberID, walletService: walletService))
    }

    var body: some View {
        NavigationSplitView {
            content
                .navigationTitle("Wallet")
                .task { await vm.load() }
                .refreshable { await vm.refresh() }
                .sheet(isPresented: $showClaim) {
                    ClaimComposerView(balance: vm.balance, pointsLabel: vm.pointsLabel) { points, item in
                        await vm.submitClaim(points: points, item: item)
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showGoal) {
                    SetGoalSheet(pointsLabel: vm.pointsLabel) { title, target in
                        await vm.createGoal(title: title, target: target)
                    }
                    .presentationDetents([.medium])
                }
                .alert("Couldn't complete", isPresented: errorBinding) {
                    Button("OK", role: .cancel) { vm.errorMessage = nil }
                } message: { Text(vm.errorMessage ?? "") }
        } detail: {
            if let id = selectedLedgerID, let entry = vm.ledgerEntry(for: id) {
                LedgerDetailView(entry: entry)
            } else {
                DetailPlaceholder(title: "Your wallet",
                                  subtitle: "Tap a transaction to see where those points came from.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load your wallet",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .loaded:
            walletList
        }
    }

    private var walletList: some View {
        List(selection: $selectedLedgerID) {
            Section {
                balanceHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                goalSection
                Button {
                    showClaim = true
                } label: {
                    Label("Claim \(vm.pointsLabel)", systemImage: "gift")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            ledgerSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Balance (themed hero)

    private var balanceHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: "star.circle.fill")
                .font(.title2)
                .foregroundStyle(Brand.cream.opacity(0.9))
            Text("\(vm.balance)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Brand.cream)
                .contentTransition(.numericText(value: Double(vm.balance)))
                .animation(.snappy, value: vm.balance)
            Text(vm.pointsLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Brand.cream.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Brand.backdrop)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Brand.clayDark.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Goal

    @ViewBuilder
    private var goalSection: some View {
        if let goal = vm.goal {
            GoalProgressBar(title: goal.title, balance: vm.balance,
                            target: goal.targetPoints, pointsLabel: vm.pointsLabel)
                .padding(.vertical, 4)
        } else if !goalPromptDismissed {
            HStack {
                Label("Set a savings goal to track your progress.", systemImage: "target")
                    .font(.subheadline)
                Spacer()
                Button("Set") { showGoal = true }
                    .font(.subheadline.weight(.semibold))
                Button {
                    goalPromptDismissed = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Ledger

    @ViewBuilder
    private var ledgerSection: some View {
        Section("History") {
            if vm.ledgerIsEmpty {
                Text("No history yet. Completed tasks will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.ledger) { entry in
                    LedgerRow(entry: entry)
                        .tag(entry.id)
                        .task { await vm.loadMoreIfNeeded(currentItem: entry) }
                }
                if vm.isLoadingPage {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }
}

/// A single ledger row — signed point pill + server-formatted reason + time.
private struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.reason)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            PointPill(value: entry.delta)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
