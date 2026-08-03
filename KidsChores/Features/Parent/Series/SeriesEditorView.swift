//
//  SeriesEditorView.swift
//  KidsChores
//
//  Series creation form (ios-prd §8.4).
//

import SwiftUI

struct SeriesEditorView: View {
    @State private var vm: SeriesEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(assignees: [Member],
         seriesService: SeriesService,
         definitionService: DefinitionService,
         onSaved: @escaping () -> Void) {
        _vm = State(initialValue: SeriesEditorViewModel(
            assignees: assignees, seriesService: seriesService,
            definitionService: definitionService, onSaved: onSaved))
    }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("New Series")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await vm.save(); if vm.errorMessage == nil { dismiss() } }
                        }
                        .disabled(!vm.isValid || vm.isSaving)
                    }
                }
                .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var form: some View {
        @Bindable var vm = vm
        Form {
            Section("Details") {
                TextField("Name (e.g. Weekend Reset)", text: $vm.name)
                Picker("Assignee", selection: $vm.assigneeID) {
                    ForEach(vm.assignees) { Text($0.displayName).tag($0.id) }
                }
                .onChange(of: vm.assigneeID) { _, _ in vm.assigneeChanged() }
                Stepper(value: $vm.bonusPoints, in: 1...10_000) {
                    HStack {
                        Text("Bonus")
                        Spacer()
                        Text("\(vm.bonusPoints)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Payout", selection: $vm.payoutMode) {
                    Text("Each + bonus").tag(SeriesPayoutMode.individualPlusBonus)
                    Text("All or nothing").tag(SeriesPayoutMode.allOrNothing)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Payout mode")
            } footer: {
                Text(vm.explainer(for: vm.payoutMode))
            }

            Section("Window") {
                Picker("Repeats", selection: $vm.windowType) {
                    Text("Weekly").tag(SeriesWindowType.weekly)
                    Text("Monthly").tag(SeriesWindowType.monthly)
                }
                .pickerStyle(.segmented)
            }

            Section {
                if vm.availableDefinitions.isEmpty {
                    Text("This teen has no tasks to bundle yet. Create some tasks first.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(vm.availableDefinitions) { def in
                        Button {
                            vm.toggle(def.id)
                        } label: {
                            HStack {
                                Image(systemName: vm.selectedDefinitionIDs.contains(def.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(vm.selectedDefinitionIDs.contains(def.id) ? Color.accentColor : Color.secondary)
                                Text(def.title)
                                Spacer()
                                PointPill(value: def.pointValue, showsSign: false)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Tasks in this series")
            } footer: {
                Text("These existing tasks will be bundled into the series.")
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
        }
    }
}
