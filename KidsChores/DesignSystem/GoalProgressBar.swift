//
//  GoalProgressBar.swift
//  KidsChores
//
//  Linear balance vs. target with the remaining delta as trailing text
//  ("860 to go") — ios-prd §6.5. Progress is computed client-side as
//  balance / target (no server "achieved" signal yet — API §10).
//

import SwiftUI

struct GoalProgressBar: View {
    let title: String
    let balance: Int
    let target: Int
    let pointsLabel: String

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(balance) / Double(target), 1)
    }

    private var remaining: Int { max(target - balance, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(remaining == 0 ? "Reached!" : "\(remaining) to go")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: fraction)
                .tint(.accentColor)
            Text("\(balance) / \(target) \(pointsLabel)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    GoalProgressBar(title: "AirPods", balance: 1140, target: 2000, pointsLabel: "points")
        .padding()
}
