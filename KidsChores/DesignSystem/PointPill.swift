//
//  PointPill.swift
//  KidsChores
//
//  "+40" / "−20" in a capsule, colored by sign, monospaced digits so the pill
//  doesn't reflow as values change (ios-prd §6.2/§6.5). Points render in the
//  accent color — never green-and-dollar-sign styled (§6.1).
//

import SwiftUI

struct PointPill: View {
    let value: Int
    /// When true, always shows an explicit sign (ledger deltas). When false,
    /// a plain reward value with no leading "+".
    var showsSign: Bool = true

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(accessibilityText)
    }

    private var text: String {
        guard showsSign else { return "\(value)" }
        return value >= 0 ? "+\(value)" : "−\(abs(value))"
    }

    private var color: Color {
        value < 0 ? .red : .accentColor
    }

    private var accessibilityText: String {
        value < 0 ? "minus \(abs(value)) points" : "\(value) points"
    }
}

#Preview {
    HStack {
        PointPill(value: 40, showsSign: false)
        PointPill(value: 40)
        PointPill(value: -20)
    }
    .padding()
}
