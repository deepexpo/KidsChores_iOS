//
//  AdjustPointsSheet.swift
//  KidsChores
//
//  Manual point adjustment (ios-prd §8.2 / PRD §6.6). Reason is mandatory
//  (min 5 chars) and always visible to the teen afterward via the ledger.
//  Adjustments can be positive or negative.
//

import SwiftUI

struct AdjustPointsSheet: View {
    let memberName: String
    let pointsLabel: String
    /// Returns true on success.
    let onAdjust: (_ delta: Int, _ reason: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isCredit = true
    @State private var amount = 10
    @State private var reason = ""
    @State private var isSubmitting = false

    private var delta: Int { isCredit ? amount : -amount }
    private var isValid: Bool {
        amount >= 1 && reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Direction", selection: $isCredit) {
                        Text("Add").tag(true)
                        Text("Remove").tag(false)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $amount, in: 1...10_000) {
                        HStack {
                            Text(isCredit ? "Add" : "Remove")
                            Spacer()
                            Text("\(amount)").monospacedDigit().foregroundStyle(.secondary)
                            Text(pointsLabel).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    TextField("Reason (the teen will see this)", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Required — at least 5 characters.")
                }
            }
            .navigationTitle("Adjust \(memberName)'s \(pointsLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSubmitting = true
                            let ok = await onAdjust(delta, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                            isSubmitting = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }
}
