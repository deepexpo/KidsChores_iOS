//
//  EmptyStateView.swift
//  KidsChores
//
//  Reused everywhere per ios-prd §14. The key rule: an empty state must
//  communicate whether "empty" is good, neutral, or bad — never a bare
//  "No data". `kind` encodes that intent.
//

import SwiftUI

struct EmptyStateView: View {
    enum Kind {
        /// A *good* outcome (Today done, Inbox clear). Calm/affirming.
        case good
        /// Neutral (new user, no history yet). Explain + a single next action.
        case neutral
        /// Something failed (network/server). Offer a retry.
        case error
    }

    let icon: String
    let headline: String
    let subline: String?
    var kind: Kind = .neutral
    /// Shown only for `.error`, or when a next action is provided.
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .padding(20)
                .background(tint.opacity(0.12), in: Circle())
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
            Text(headline)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let subline {
                Text(subline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
            }
        }
    }

    private var tint: Color {
        switch kind {
        case .good: return .green
        case .neutral: return .secondary
        case .error: return .orange
        }
    }
}

#Preview {
    VStack {
        EmptyStateView(icon: "checkmark.circle", headline: "You're all caught up.",
                       subline: nil, kind: .good)
        EmptyStateView(icon: "tray", headline: "No tasks yet",
                       subline: "Ask a parent to add your first task.", kind: .neutral)
        EmptyStateView(icon: "wifi.slash", headline: "Couldn't load",
                       subline: "Check your connection and try again.", kind: .error,
                       actionTitle: "Retry", action: {})
    }
}
