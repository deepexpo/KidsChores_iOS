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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedFraction: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(remaining == 0 ? "Reached! 🎉" : "\(remaining) to go")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(remaining == 0 ? Color.green : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * animatedFraction))
                }
            }
            .frame(height: 10)
            Text("\(balance) / \(target) \(pointsLabel)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .onAppear { setFraction(animated: !reduceMotion) }
        .onChange(of: fraction) { _, _ in setFraction(animated: !reduceMotion) }
    }

    private func setFraction(animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { animatedFraction = fraction }
        } else {
            animatedFraction = fraction
        }
    }
}

#Preview {
    GoalProgressBar(title: "AirPods", balance: 1140, target: 2000, pointsLabel: "points")
        .padding()
}
