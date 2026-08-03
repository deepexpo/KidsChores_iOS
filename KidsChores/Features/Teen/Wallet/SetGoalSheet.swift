//
//  SetGoalSheet.swift
//  KidsChores
//
//  Create a savings goal (ios-prd §7.3). Goals are create-and-display only for
//  now — no edit/achieve endpoint yet (API §10); progress is computed as
//  balance / target.
//

import SwiftUI

struct SetGoalSheet: View {
    let pointsLabel: String
    let onCreate: (_ title: String, _ target: Int) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var target = 500
    @State private var isSubmitting = false

    private var isValid: Bool {
        target >= 1 && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you saving for?") {
                    TextField("e.g. AirPods", text: $title)
                }
                Section("Target") {
                    Stepper(value: $target, in: 1...1_000_000, step: 50) {
                        HStack {
                            Text("\(target)").monospacedDigit().font(.headline)
                            Text(pointsLabel).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Set a goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSubmitting = true
                            await onCreate(title.trimmingCharacters(in: .whitespacesAndNewlines), target)
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }
}
