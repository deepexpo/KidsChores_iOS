//
//  ApprovalCard.swift
//  KidsChores
//
//  The parent-inbox card (ios-prd §6.5 / §8.1): type icon, teen name, task
//  title, point value, and — for excuses — the full excuse text inline (no
//  tap-to-expand; reading it is the whole point of the screen). Deny requires
//  a comment, so the deny action is a signal to the parent screen to collect
//  one, not a fire-and-forget.
//

import SwiftUI

struct ApprovalCard: View {
    let item: ApprovalItem
    var onApprove: () -> Void = {}
    var onDeny: () -> Void = {}

    private var isExcuse: Bool { item.type == .excuse }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isExcuse ? "text.bubble" : "checkmark.circle")
                    .foregroundStyle(.tint)
                Text(item.assigneeName).font(.subheadline.weight(.semibold))
                Spacer()
                PointPill(value: item.pointValue, showsSign: false)
            }

            Text(item.taskTitle).font(.headline)

            if let excuse = item.excuseText, isExcuse {
                Text(excuse)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(role: .destructive, action: onDeny) {
                    Label("Deny", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ApprovalCard(item: ApprovalItem(
        type: .excuse,
        taskInstanceID: "1",
        taskTitle: "Wash the car",
        assigneeName: "Arjun",
        pointValue: 50,
        submittedAt: .now,
        excuseText: "Was at Dev's birthday all afternoon, will do it Monday."
    ))
    .padding()
}
