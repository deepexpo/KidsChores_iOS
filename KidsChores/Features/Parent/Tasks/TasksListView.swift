//
//  TasksListView.swift
//  KidsChores
//
//  Definition list (ios-prd §8.3): grouped by assignee, archived filtered out
//  by default. "+" opens the create form; tapping a row opens the editor;
//  swipe archives.
//

import SwiftUI

struct TasksListView: View {
    @State private var vm: TasksViewModel
    @State private var editorTarget: EditorTarget?

    private let definitionService: DefinitionService
    private let householdService: HouseholdService
    private let seriesService: SeriesService

    init(definitionService: DefinitionService,
         householdService: HouseholdService,
         seriesService: SeriesService) {
        self.definitionService = definitionService
        self.householdService = householdService
        self.seriesService = seriesService
        _vm = State(initialValue: TasksViewModel(
            definitionService: definitionService, householdService: householdService))
    }

    /// Distinguishes "new" from "edit existing" for the editor sheet.
    private enum EditorTarget: Identifiable {
        case new
        case edit(TaskDefinition)
        var id: String {
            switch self {
            case .new: "new"
            case .edit(let def): def.id
            }
        }
        var definition: TaskDefinition? {
            if case .edit(let def) = self { return def }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tasks")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Toggle("Archived", isOn: $vm.showArchived)
                            .toggleStyle(.button)
                            .font(.subheadline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SeriesListView(seriesService: seriesService,
                                           householdService: householdService,
                                           definitionService: definitionService)
                        } label: { Image(systemName: "rosette") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editorTarget = .new
                        } label: { Image(systemName: "plus") }
                        .disabled(vm.assignees.isEmpty)
                    }
                }
                .task { await vm.load() }
                .refreshable { await vm.load() }
                .sheet(item: $editorTarget) { target in
                    DefinitionEditorView(
                        service: definitionService,
                        assignees: vm.assignees,
                        existing: target.definition,
                        onSaved: { Task { await vm.load() } })
                }
                .alert("Couldn't complete", isPresented: errorBinding) {
                    Button("OK", role: .cancel) { vm.errorMessage = nil }
                } message: { Text(vm.errorMessage ?? "") }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load tasks",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .empty:
            EmptyStateView(icon: "list.bullet.rectangle",
                           headline: vm.assignees.isEmpty ? "Add a teen first" : "No tasks yet",
                           subline: vm.assignees.isEmpty
                             ? "Create a teen profile in Family, then add tasks here."
                             : "Tap + to create your first task.",
                           kind: .neutral)
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(vm.groups) { group in
                Section(group.assigneeName) {
                    ForEach(group.definitions) { def in
                        Button { editorTarget = .edit(def) } label: { row(def) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                if !def.isArchived {
                                    Button(role: .destructive) {
                                        Task { await vm.archive(def) }
                                    } label: { Label("Archive", systemImage: "archivebox") }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ def: TaskDefinition) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title).font(.headline)
                    if def.isArchived {
                        Text("Archived")
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(scheduleSummary(def))
                    if def.requiresReview {
                        Label("Review", systemImage: "checkmark.shield").labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            PointPill(value: def.pointValue, showsSign: false)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }
}
