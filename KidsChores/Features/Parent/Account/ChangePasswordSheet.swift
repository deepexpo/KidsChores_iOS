//
//  ChangePasswordSheet.swift
//  KidsChores
//
//  Change the account password. Requires the current password (so a borrowed
//  unlocked phone can't silently change it) and confirms the new one.
//

import SwiftUI

struct ChangePasswordSheet: View {
    let service: AccountService

    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !current.isEmpty && newPassword.count >= 8 && newPassword == confirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current password", text: $current)
                        .textContentType(.password)
                }
                Section {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirm)
                        .textContentType(.newPassword)
                } footer: {
                    if !newPassword.isEmpty && newPassword.count < 8 {
                        Text("At least 8 characters.").foregroundStyle(.red)
                    } else if !confirm.isEmpty && newPassword != confirm {
                        Text("Passwords don't match.").foregroundStyle(.red)
                    } else {
                        Text("At least 8 characters.")
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
            .overlay { if isSubmitting { ProgressView() } }
        }
    }

    private func save() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await service.changePassword(
                ChangePasswordRequest(currentPassword: current, newPassword: newPassword))
            dismiss()
        } catch APIError.unauthorized {
            errorMessage = "Your current password is incorrect."
        } catch APIError.unprocessable(let detail) {
            errorMessage = detail ?? "Please check your new password."
        } catch {
            errorMessage = "Couldn't change your password. Please try again."
        }
    }
}
