//
//  DenyCommentSheet.swift
//  KidsChores
//
//  Denial requires a comment (API §7 — 422 without one), so we always collect
//  it before enabling "Deny". Reused for single and bulk denials.
//

import SwiftUI

struct DenyCommentSheet: View {
    /// Title context — a task name for single deny, or "N items" for bulk.
    let subject: String
    let onDeny: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @FocusState private var focused: Bool

    private var isValid: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reason", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused)
                } header: {
                    Text("Why are you denying \(subject)?")
                } footer: {
                    Text("The teen will see this comment.")
                }
            }
            .navigationTitle("Add a comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Deny", role: .destructive) {
                        onDeny(comment.trimmingCharacters(in: .whitespacesAndNewlines))
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
    DenyCommentSheet(subject: "Wash dishes") { _ in }
}
