//
//  BrandMark.swift
//  KidsChores
//
//  The app's star-and-check mark (matching the app icon), reused on the splash
//  and sign-in screens. The checkmark can "draw on" via `checkProgress` for a
//  satisfying, purposeful entrance — motion with a job, not decoration (§6.4).
//

import SwiftUI

/// Brand palette drawn from the app icon. Intentionally hardcoded — this is
/// brand identity, not content (content uses system color roles).
enum Brand {
    static let cream = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let forest = Color(red: 0.30, green: 0.42, blue: 0.18)
    static let clay = Color(red: 0.71, green: 0.40, blue: 0.18)
    static let clayDark = Color(red: 0.52, green: 0.28, blue: 0.13)

    static let backdrop = LinearGradient(
        colors: [clay, clayDark],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The check path, drawn inside a unit-ish rect so it can be trimmed on.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.18 * w, y: 0.55 * h))
        p.addLine(to: CGPoint(x: 0.42 * w, y: 0.78 * h))
        p.addLine(to: CGPoint(x: 0.84 * w, y: 0.28 * h))
        return p
    }
}

struct BrandMark: View {
    var size: CGFloat = 120
    /// 0 → 1 draws the checkmark on. Default 1 (fully drawn).
    var checkProgress: CGFloat = 1

    var body: some View {
        ZStack {
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Brand.cream)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.15), radius: size * 0.04, y: size * 0.02)

            CheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(Brand.forest,
                        style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.44, height: size * 0.44)
                .offset(y: -size * 0.01)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Brand.backdrop.ignoresSafeArea()
        BrandMark(size: 140)
    }
}
