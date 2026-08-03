//
//  SeriesProgressRing.swift
//  KidsChores
//
//  Circular progress (complete / total) with a center label like "4 of 7"
//  (ios-prd §6.5). Animates on change.
//

import SwiftUI

struct SeriesProgressRing: View {
    let completed: Int
    let total: Int
    var lineWidth: CGFloat = 8
    var diameter: CGFloat = 72

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private var isComplete: Bool { total > 0 && completed >= total }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.65)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.3, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Text("\(completed) of \(total)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { set(animated: !reduceMotion) }
        .onChange(of: fraction) { _, _ in set(animated: !reduceMotion) }
        .accessibilityLabel("Series progress: \(completed) of \(total) complete")
    }

    private func set(animated shouldAnimate: Bool) {
        if shouldAnimate {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { animated = fraction }
        } else {
            animated = fraction
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        SeriesProgressRing(completed: 2, total: 3)
        SeriesProgressRing(completed: 7, total: 7)
    }
    .padding()
}
