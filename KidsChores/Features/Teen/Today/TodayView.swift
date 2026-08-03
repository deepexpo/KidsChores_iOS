//
//  TodayView.swift
//  KidsChores
//
//  The most important teen screen (ios-prd §7.1): a 3-second glance-and-tap.
//  Balance pill in the nav bar, overdue pinned on top, swipe-to-complete and
//  swipe-to-excuse both backed by full-swipe and the revealed button (don't
//  require gesture precision). Skeleton loading, and good/neutral/error empty
//  states per §14.
//

import SwiftUI

struct TodayView: View {
    @State private var vm: TodayViewModel
    @State private var excuseTarget: TodayViewModel.Row?
    /// Selected task drives the detail pane on iPad and push nav on iPhone.
    @State private var selectedRowID: String?

    init(memberID: String,
         taskService: TaskService,
         walletService: WalletService,
         definitionCache: DefinitionCache,
         outbox: Outbox,
         taskCache: TaskCache) {
        _vm = State(initialValue: TodayViewModel(
            memberID: memberID,
            taskService: taskService,
            walletService: walletService,
            definitionCache: definitionCache,
            outbox: outbox,
            taskCache: taskCache))
    }

    var body: some View {
        // NavigationSplitView is adaptive: 2-column on iPad (list | detail),
        // auto-collapsing to push navigation on iPhone (ios-prd §4.4 / §7.4).
        NavigationSplitView {
            VStack(spacing: 0) {
                if vm.isOffline { OfflineBanner() }
                content
            }
                .overlay(alignment: .top) { seriesBonusBadge }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: vm.seriesBonus)
                .navigationTitle("Today")
                .toolbar {
                    if let balance = vm.balance {
                        ToolbarItem(placement: .topBarTrailing) {
                            balancePill(balance)
                        }
                    }
                }
                .task { await vm.load() }
                .refreshable { await vm.refresh() }
                .sheet(item: $excuseTarget) { row in
                    ExcuseComposerView(taskTitle: row.title) { text in
                        Task { await vm.excuse(row, text: text) }
                    }
                    .presentationDetents([.medium])
                }
        } detail: {
            detailPane
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedRowID, let row = vm.row(for: id) {
            TaskDetailView(
                detail: row.detail,
                onComplete: { Task { await vm.complete(row) } },
                onExcuse: { excuseTarget = row })
        } else {
            DetailPlaceholder(title: "Your day",
                              subtitle: "Tap a task to see the details and complete it.")
        }
    }

    // MARK: - State switch

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            SkeletonList()
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load today",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .empty(let isGood):
            if isGood {
                EmptyStateView(icon: "checkmark.circle", headline: "Nothing due today.",
                               subline: "Enjoy it — check Week to see what's coming up.",
                               kind: .good)
            } else {
                EmptyStateView(icon: "tray", headline: "No tasks yet",
                               subline: "Ask a parent to add your first task.", kind: .neutral)
            }
        case .loaded:
            taskList
        }
    }

    // Celebratory "+N" badge when a series completes (§6.4).
    @ViewBuilder
    private var seriesBonusBadge: some View {
        if let bonus = vm.seriesBonus {
            Label("Series bonus +\(bonus)", systemImage: "rosette")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(.tint)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { vm.dismissSeriesBonus() }
        }
    }

    private var taskList: some View {
        List(selection: $selectedRowID) {
            if !vm.overdue.isEmpty {
                Section("Overdue") {
                    ForEach(vm.overdue) { row($0).tag($0.id) }
                }
            }
            if !vm.dueToday.isEmpty {
                Section("Today") {
                    ForEach(vm.dueToday) { row($0).tag($0.id) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.overdue)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.dueToday)
    }

    // MARK: - Row + swipe actions

    @ViewBuilder
    private func row(_ row: TodayViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TaskRow(title: row.title, dueAt: row.dueAt, pointValue: row.pointValue,
                    status: row.status, secondaryBadges: row.inSeries ? ["Series"] : [])
            if let note = row.conflictNote {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if row.canComplete {
                Button { Task { await vm.complete(row) } } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if row.canExcuse {
                Button { excuseTarget = row } label: {
                    Label("Excuse", systemImage: "text.bubble")
                }
                .tint(.orange)
            }
        }
        // VoiceOver: swipe actions aren't discoverable, so expose them here (§13).
        .accessibilityActions {
            if row.canComplete {
                Button("Complete \(row.title)") { Task { await vm.complete(row) } }
            }
            if row.canExcuse {
                Button("Excuse \(row.title)") { excuseTarget = row }
            }
        }
    }

    // MARK: - Balance pill

    private func balancePill(_ balance: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.circle")
            Text("\(balance)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(balance)))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.tint)
        .animation(.snappy, value: balance)
        .accessibilityLabel("Balance \(balance) \(vm.pointsLabel)")
    }
}

/// Skeleton rows matching the eventual layout (ios-prd §14) — not a spinner.
private struct SkeletonList: View {
    var body: some View {
        List {
            Section("Today") {
                ForEach(0..<5, id: \.self) { _ in
                    TaskRow(title: "Placeholder task", dueAt: .now, pointValue: 0, status: .pending)
                        .redacted(reason: .placeholder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .allowsHitTesting(false)
    }
}
