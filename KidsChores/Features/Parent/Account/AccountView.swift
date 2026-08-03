//
//  AccountView.swift
//  KidsChores
//
//  The parent's *personal account* — separate from Household settings. Manage
//  the login itself: change password, sign out, delete account. (Household-wide
//  config lives in HouseholdSettingsView.)
//

import SwiftUI

struct AccountView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(name: session.accountEmail ?? "You",
                                   seed: session.accountEmail ?? "you", size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent account").font(.headline)
                            if let email = session.accountEmail {
                                Text(email).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("Change Password", systemImage: "key")
                    }
                }

                Section {
                    Button {
                        session.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } footer: {
                    Text("Deleting your account removes your household and everything in it — teens, tasks, and history. This can't be undone.")
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay { if isDeleting { ProgressView() } }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet(service: session.api)
            }
            .confirmationDialog("Delete your account?",
                                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your household, all teens, tasks, and history.")
            }
            .alert("Couldn't complete", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await session.api.deleteAccount()
            session.signOut()   // returns to sign-in
        } catch {
            errorMessage = "Couldn't delete your account. Please try again."
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
