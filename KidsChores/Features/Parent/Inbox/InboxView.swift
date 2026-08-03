//
//  InboxView.swift
//  KidsChores
//
//  The parent's default screen (ios-prd §8.1) — "nearly frictionless". Card
//  stack oldest-first, swipe right to approve (with a 4s undo toast), swipe
//  left to deny (comment required), and a multi-select mode for bulk resolve.
//  The empty state is the success state.
//

import SwiftUI

struct InboxView: View {
    @State private var vm: InboxViewModel
    @State private var denyTarget: ApprovalItem?
    @State private var showBulkDeny = false

    init(approvalService: ApprovalService, taskService: TaskService) {
        _vm = State(initialValue: InboxViewModel(
            approvalService: approvalService, taskService: taskService))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Inbox")
                .toolbar { toolbar }
                .task { await vm.load() }
                .refreshable { await vm.refresh() }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .overlay(alignment: .bottom) { undoToast }
                .sheet(item: $denyTarget) { item in
                    DenyCommentSheet(subject: item.taskTitle) { comment in
                        Task { await vm.deny(item, comment: comment) }
                    }
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showBulkDeny) {
                    DenyCommentSheet(subject: "\(vm.selection.count) item\(vm.selection.count == 1 ? "" : "s")") { comment in
                        Task { await vm.bulkDeny(comment: comment) }
                    }
                    .presentationDetents([.medium])
                }
                .alert("Couldn't complete", isPresented: errorBinding) {
                    Button("OK", role: .cancel) { vm.errorMessage = nil }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load your inbox",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .caughtUp:
            EmptyStateView(icon: "checkmark.circle", headline: "You're all caught up.",
                           subline: "New requests will show up here.", kind: .good)
        case .loaded:
            cardList
        }
    }

    private var cardList: some View {
        List(selection: $vm.selection) {
            ForEach(vm.items) { item in
                ApprovalCard(
                    item: item,
                    onApprove: { withAnimation { vm.approve(item) } },
                    onDeny: { denyTarget = item })
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { withAnimation { vm.approve(item) } } label: {
                        Label("Approve", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { denyTarget = item } label: {
                        Label("Deny", systemImage: "xmark")
                    }
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(vm.isSelecting ? .active : .inactive))
    }

    // MARK: - Toolbar + bulk bar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if vm.state == .loaded || vm.isSelecting {
                Button(vm.isSelecting ? "Done" : "Select") {
                    withAnimation {
                        vm.isSelecting.toggle()
                        if !vm.isSelecting { vm.selection.removeAll() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if vm.isSelecting && !vm.selection.isEmpty {
            HStack {
                Button(role: .destructive) { showBulkDeny = true } label: {
                    Label("Deny \(vm.selection.count)", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { Task { await vm.bulkApprove() } } label: {
                    Label("Approve \(vm.selection.count)", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
        }
    }

    // MARK: - Undo toast

    @ViewBuilder
    private var undoToast: some View {
        if let item = vm.undoItem {
            HStack {
                Text("Approved \(item.taskTitle)")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Button("Undo") { withAnimation { vm.undoApprove() } }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 24).padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }
}
