//
//  SeriesListView.swift
//  KidsChores
//
//  Series list (ios-prd §8.4) with a progress ring per active window. Reached
//  from the Tasks screen; "+" opens the creation form.
//

import SwiftUI

struct SeriesListView: View {
    @State private var vm: SeriesListViewModel
    @State private var showEditor = false
    @State private var editTarget: Series?
    @State private var deleteTarget: Series?

    private let seriesService: SeriesService
    private let definitionService: DefinitionService

    init(seriesService: SeriesService,
         householdService: HouseholdService,
         definitionService: DefinitionService) {
        self.seriesService = seriesService
        self.definitionService = definitionService
        _vm = State(initialValue: SeriesListViewModel(
            seriesService: seriesService, householdService: householdService))
    }

    var body: some View {
        content
            .navigationTitle("Series")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                        .disabled(vm.assignees.isEmpty)
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .sheet(isPresented: $showEditor) {
                SeriesEditorView(
                    assignees: vm.assignees,
                    seriesService: seriesService,
                    definitionService: definitionService,
                    onSaved: { Task { await vm.load() } })
            }
            .sheet(item: $editTarget) { series in
                SeriesEditSheet(series: series) { name, bonus in
                    await vm.update(seriesID: series.id, name: name, bonusPoints: bonus)
                }
            }
            .confirmationDialog("Delete this series?",
                                isPresented: deleteBinding, titleVisibility: .visible,
                                presenting: deleteTarget) { series in
                Button("Delete \(series.name)", role: .destructive) {
                    Task { await vm.archive(seriesID: series.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { series in
                Text("Individually-earned points are kept; the series and its bonus stop. This can't be undone.")
            }
            .alert("Couldn't complete", isPresented: errorBinding) {
                Button("OK", role: .cancel) { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }
    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load series",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .empty:
            EmptyStateView(icon: "rosette", headline: "No series yet",
                           subline: "Bundle tasks into a series with a bonus payout.", kind: .neutral)
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(vm.rows) { row in
                Button { editTarget = row.series } label: { rowContent(row) }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteTarget = row.series } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editTarget = row.series } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func rowContent(_ row: SeriesListViewModel.Row) -> some View {
        HStack(spacing: 14) {
            if row.hasProgress {
                SeriesProgressRing(completed: row.completed, total: row.total,
                                   lineWidth: 6, diameter: 52)
            } else {
                Image(systemName: "rosette").font(.title2).foregroundStyle(.tint)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(row.series.name).font(.headline)
                Text("\(row.assigneeName) · +\(row.series.bonusPoints) bonus")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
