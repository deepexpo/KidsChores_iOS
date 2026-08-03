//
//  LedgerDetailView.swift
//  KidsChores
//
//  Detail for a single ledger entry (ios-prd §7.3 — "tap a ledger row for a
//  detail sheet"). On iPad this is the Wallet's detail pane; on iPhone it's a
//  pushed screen. The `reason` is server-formatted and rendered verbatim.
//

import SwiftUI

struct LedgerDetailView: View {
    let entry: LedgerEntry

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    PointPill(value: entry.delta)
                        .scaleEffect(1.4)
                        .padding(.vertical, 8)
                    Text(entry.reason)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Type", value: Self.label(for: entry.entryType))
                LabeledContent("Balance after") {
                    Text("\(entry.balanceAfter)").monospacedDigit()
                }
                LabeledContent("When") {
                    Text(entry.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func label(for type: LedgerEntryType) -> String {
        switch type {
        case .taskCompleted: "Task completed"
        case .seriesBonus: "Series bonus"
        case .excusedPartial: "Excused (partial)"
        case .claimFulfilled: "Claim fulfilled"
        case .manualAdjustment: "Adjustment"
        case .reversal: "Reversal"
        case .unknown: "—"
        }
    }
}
