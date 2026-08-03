//
//  ClaimCard.swift
//  KidsChores
//
//  A pending reward claim in the parent inbox (ios-prd §6.6). Approve = fulfil
//  (debits the points); Deny = decline (no debit). Shows the teen, what they
//  asked for, and the point cost.
//

import SwiftUI

struct ClaimCard: View {
    let claim: Claim
    var onApprove: () -> Void = {}
    var onDeny: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(name: claim.memberName ?? "Teen",
                           seed: claim.memberName ?? claim.memberID, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(claim.memberName ?? "Teen").font(.subheadline.weight(.semibold))
                    Label("Reward claim", systemImage: "gift")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PointPill(value: -claim.points)
            }

            Text(claim.requestedItem)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(role: .destructive, action: onDeny) {
                    Label("Decline", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(action: onApprove) {
                    Label("Fulfil", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ClaimCard(claim: Claim(
        id: "1", memberID: "m1", memberName: "Arjun", points: 500,
        requestedItem: "New headphones", status: .pending,
        parentNote: nil, requestedAt: .now, resolvedAt: nil))
    .padding()
}
