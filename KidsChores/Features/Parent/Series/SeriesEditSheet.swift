//
//  SeriesEditSheet.swift
//  KidsChores
//
//  Edit an existing series' name and bonus. Structural fields (assignee, window,
//  payout mode, member tasks) aren't editable after creation — changing them
//  mid-window is semantically messy and the backend doesn't support it; archive
//  and recreate for those.
//

import SwiftUI

struct SeriesEditSheet: View {
    let series: Series
    /// Returns true on success.
    let onSave: (_ name: String, _ bonus: Int) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var bonus: Int
    @State private var isSaving = false

    init(series: Series, onSave: @escaping (_ name: String, _ bonus: Int) async -> Bool) {
        self.series = series
        self.onSave = onSave
        _name = State(initialValue: series.name)
        _bonus = State(initialValue: series.bonusPoints)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && bonus >= 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Stepper(value: $bonus, in: 1...10_000) {
                        HStack {
                            Text("Bonus")
                            Spacer()
                            Text("\(bonus)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    LabeledContent("Payout", value: payoutLabel)
                    LabeledContent("Repeats", value: series.windowType == .monthly ? "Monthly" : "Weekly")
                } footer: {
                    Text("Assignee, payout mode, window, and the bundled tasks can't be changed after a series is created — archive and recreate to change those.")
                }
            }
            .navigationTitle("Edit Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let ok = await onSave(name.trimmingCharacters(in: .whitespaces), bonus)
                            isSaving = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private var payoutLabel: String {
        switch series.payoutMode {
        case .individualPlusBonus: "Each + bonus"
        case .allOrNothing: "All or nothing"
        case .unknown: "—"
        }
    }
}
