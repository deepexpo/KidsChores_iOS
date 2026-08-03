//
//  PasscodeSetupSheet.swift
//  KidsChores
//
//  Reusable 4-digit set-and-confirm sheet, used for the parent passcode
//  (gating family-mode exit, §4.4) and for setting/changing a teen's PIN.
//  Enter-then-confirm so a typo can't lock anyone out.
//

import SwiftUI

struct PasscodeSetupSheet: View {
    var navTitle: String = "Passcode"
    var setPrompt: String = "Set a passcode"
    var confirmPrompt: String = "Confirm passcode"
    var explanation: String? = nil
    /// Called with the confirmed 4-digit code.
    let onSet: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var entry = ""
    @State private var confirming = false
    @State private var message: String?
    @FocusState private var focused: Bool

    private let length = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "lock.shield")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(confirming ? confirmPrompt : setPrompt)
                    .font(.headline)
                if let explanation {
                    Text(explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                dots
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .background(
                TextField("", text: $entry)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .opacity(0.01)
                    .onChange(of: entry) { _, new in handle(new) }
            )
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
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
    }

    private func handle(_ new: String) {
        let digits = String(new.filter(\.isNumber).prefix(length))
        if digits != new { entry = digits; return }
        if !digits.isEmpty { message = nil }
        guard digits.count == length else { return }

        if !confirming {
            first = digits
            entry = ""
            confirming = true
        } else if digits == first {
            onSet(digits)
            dismiss()
        } else {
            message = "Those didn't match — start again."
            first = ""
            entry = ""
            confirming = false
        }
    }
}
