//
//  SplashView.swift
//  KidsChores
//
//  Launch animation (ios-prd §1 — a teen judges the app's legitimacy in the
//  first 10 seconds). Restrained, brand-driven motion: the star springs in, the
//  check draws on, the wordmark rises. Honors Reduce Motion. Calls `onFinished`
//  once the beat is done, which restores the session and dismisses the splash.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markIn = false
    @State private var checkProgress: CGFloat = 0
    @State private var titleIn = false

    var body: some View {
        ZStack {
            Brand.backdrop.ignoresSafeArea()

            VStack(spacing: 22) {
                BrandMark(size: 132, checkProgress: checkProgress)
                    .scaleEffect(markIn ? 1 : 0.6)
                    .opacity(markIn ? 1 : 0)
                    .rotationEffect(.degrees(markIn ? 0 : -12))

                VStack(spacing: 6) {
                    Text("KidsChores")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Brand.cream)
                    Text("Get it done. Get paid.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.cream.opacity(0.85))
                }
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)
            }
        }
        .onAppear(perform: run)
    }

    private func run() {
        if reduceMotion {
            markIn = true
            checkProgress = 1
            titleIn = true
            finish(after: 0.9)
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { markIn = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.35)) { checkProgress = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(0.55)) { titleIn = true }
        finish(after: 1.7)
    }

    private func finish(after seconds: Double) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
