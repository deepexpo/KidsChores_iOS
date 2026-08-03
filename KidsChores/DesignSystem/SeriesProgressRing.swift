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

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.4), value: fraction)
            Text("\(completed) of \(total)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("Series progress: \(completed) of \(total) complete")
    }
}

#Preview {
    HStack(spacing: 24) {
        SeriesProgressRing(completed: 2, total: 3)
        SeriesProgressRing(completed: 7, total: 7)
    }
    .padding()
}
