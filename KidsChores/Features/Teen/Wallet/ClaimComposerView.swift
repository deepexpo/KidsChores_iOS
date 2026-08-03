//
//  ClaimComposerView.swift
//  KidsChores
//
//  Claim composer (ios-prd §7.6). Points amount clamped ≥ 1, with a soft
//  client-side warning (not a hard block) when it exceeds the current balance —
//  the backend doesn't reject over-balance claims. Success copy avoids "pending"
//  jargon.
//

import SwiftUI

struct ClaimComposerView: View {
    let balance: Int
    let pointsLabel: String
    /// Returns true on a successful submit.
    let onSubmit: (_ points: Int, _ item: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var points = 1
    @State private var item = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false

    private var exceedsBalance: Bool { points > balance }
    private var isValid: Bool {
        points >= 1 && !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            if didSucceed {
                successState
            } else {
                form
            }
        }
    }

    private var form: some View {
        Form {
            Section("How many \(pointsLabel)?") {
                Stepper(value: $points, in: 1...max(1, balance == 0 ? 1_000_000 : balance * 4)) {
                    HStack {
                        Text("\(points)").monospacedDigit().font(.headline)
                        Text(pointsLabel).foregroundStyle(.secondary)
                    }
                }
                if exceedsBalance {
                    Label("That's more than your current balance of \(balance).",
                          systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Section("What do you want?") {
                TextField("e.g. $10, an hour of screen time…", text: $item, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Claim \(pointsLabel)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") { Task { await submit() } }
                    .disabled(!isValid || isSubmitting)
            }
        }
        .overlay { if isSubmitting { ProgressView() } }
    }

    private var successState: some View {
        EmptyStateView(icon: "paperplane.circle",
                       headline: "Sent for approval",
                       subline: "You'll get your \(pointsLabel) once a parent approves it.",
                       kind: .good,
                       actionTitle: "Done", action: { dismiss() })
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if await onSubmit(points, trimmed) {
            didSucceed = true
        }
    }
}
