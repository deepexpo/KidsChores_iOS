//
//  PINEntryView.swift
//  KidsChores
//
//  4-digit PIN gate for a shared-device profile (ios-prd §4.4 / §5.4). Verified
//  server-side via `POST .../verify-pin` (auth-endpoints §5), with a local
//  `PINStore` fallback when offline. Not a security boundary — just friction.
//

import SwiftUI

enum PINVerifyResult {
    case valid
    case wrong
    case rateLimited
    case error
}

struct PINEntryView: View {
    let memberName: String
    /// Overrides the default "Enter <name>'s PIN" prompt (e.g. for the parent gate).
    var prompt: String? = nil
    /// Verifies the entered PIN (server call + offline fallback live in the caller).
    let onVerify: (String) async -> PINVerifyResult
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var entry = ""
    @State private var message: String?
    @State private var shake = false
    @State private var isVerifying = false
    @FocusState private var focused: Bool

    private let length = 4

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(prompt ?? "Enter \(memberName)'s PIN")
                .font(.headline)

            dots
                .modifier(Shake(animatableData: shake ? 1 : 0))

            if isVerifying {
                ProgressView()
            } else if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Spacer()
            Button("Cancel", action: onCancel)
                .padding(.bottom)
        }
        .padding()
        .background(
            TextField("", text: $entry)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0.01)
                .disabled(isVerifying)
                .onChange(of: entry) { _, new in handle(new) }
        )
        .onAppear { focused = true }
    }

    private var dots: some View {
        HStack(spacing: 20) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.5)
                    .background(Circle().fill(index < entry.count ? Color.accentColor : .clear))
                    .frame(width: 18, height: 18)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func handle(_ new: String) {
        let digits = String(new.filter(\.isNumber).prefix(length))
        if digits != new { entry = digits; return }
        // Clear a prior error only when the user *starts a new* PIN — not when
        // we programmatically reset `entry` to "" after a failed attempt (that
        // would wipe the error message before it's ever seen).
        if !digits.isEmpty { message = nil }
        guard digits.count == length, !isVerifying else { return }
        Task { await verify(digits) }
    }

    private func verify(_ pin: String) async {
        isVerifying = true
        let result = await onVerify(pin)
        isVerifying = false
        switch result {
        case .valid:
            onSuccess()
        case .wrong:
            fail("Wrong PIN — try again.")
        case .rateLimited:
            fail("Too many tries — wait a moment.")
        case .error:
            fail("Couldn't check the PIN. Try again.")
        }
    }

    private func fail(_ text: String) {
        withAnimation { shake.toggle() }
        message = text
        entry = ""
        focused = true
    }
}

/// Horizontal shake for a wrong PIN.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 8 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
