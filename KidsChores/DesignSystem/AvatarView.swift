//
//  AvatarView.swift
//  KidsChores
//
//  A colorful initials avatar — warmth without cartoon mascots. Each member
//  gets a stable, deterministic color from a friendly palette (seeded by id so
//  it never changes between launches).
//

import SwiftUI

struct AvatarView: View {
    let name: String
    /// Stable color seed (pass the member id so the color is consistent).
    var seed: String?
    var size: CGFloat = 48

    var body: some View {
        let base = Self.color(for: seed ?? name)
        Circle()
            .fill(
                LinearGradient(colors: [base.opacity(0.95), base.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                Text(Self.initials(name))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(
                // Subtle top highlight for depth.
                Circle().stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .shadow(color: base.opacity(0.35), radius: size * 0.08, y: size * 0.04)
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private static let palette: [Color] = [
        Color(red: 0.90, green: 0.45, blue: 0.35),   // coral
        Color(red: 0.30, green: 0.66, blue: 0.62),   // teal
        Color(red: 0.95, green: 0.66, blue: 0.24),   // amber
        Color(red: 0.55, green: 0.45, blue: 0.80),   // violet
        Color(red: 0.36, green: 0.60, blue: 0.32),   // green
        Color(red: 0.30, green: 0.56, blue: 0.82),   // blue
        Color(red: 0.88, green: 0.48, blue: 0.62),   // pink
        Color(red: 0.80, green: 0.52, blue: 0.30),   // clay
    ]

    static func color(for seed: String) -> Color {
        // Deterministic (String.hashValue is randomized per launch, so sum scalars).
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(["Arjun", "Meera", "Sam Lee", "Priya"], id: \.self) {
            AvatarView(name: $0, seed: $0, size: 56)
        }
    }
    .padding()
}
