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
        List(vm.rows) { row in
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
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }
}
