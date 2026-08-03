//
//  ExcuseComposerView.swift
//  KidsChores
//
//  Quick in-context sheet (ios-prd §7.5). Min-10-char enforced client-side
//  before the API's own validation; the countdown only appears near the
//  minimum (don't nag from character 1). No confirmation alert — the row's
//  state change is the confirmation.
//

import SwiftUI

struct ExcuseComposerView: View {
    let taskTitle: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private let minimum = 10
    private var remaining: Int { minimum - text.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var isValid: Bool { remaining <= 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What happened?", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused)
                } header: {
                    Text("Excuse for \(taskTitle)")
                } footer: {
                    // Only surface the counter as the teen approaches the minimum.
                    if remaining > 0 && !text.isEmpty {
                        Text("\(remaining) more character\(remaining == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add excuse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSubmit(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { focused = true }
        }
    }
}

#Preview {
    ExcuseComposerView(taskTitle: "Wash the car") { _ in }
}
