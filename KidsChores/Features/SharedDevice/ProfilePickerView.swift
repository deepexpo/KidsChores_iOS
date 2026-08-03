//
//  ProfilePickerView.swift
//  KidsChores
//
//  Shared-device launch surface (ios-prd §4.4): an avatar grid of the
//  household's teens. Tapping one unlocks it via PIN (if set locally); with no
//  local PIN the profile opens directly (the parent may not have set one, or
//  the profile was created on another device).
//

import SwiftUI

struct ProfilePickerView: View {
    @Environment(AppSession.self) private var session

    @State private var teens: [Member] = []
    @State private var state: LoadState = .loading
    @State private var pinTarget: Member?
    @State private var showParentGate = false

    private enum LoadState: Equatable { case loading, loaded, failed(String) }

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 20)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Who's using the app?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Parent") { exitToParent() }
                    }
                }
                .task { await load() }
                .fullScreenCover(item: $pinTarget) { teen in
                    PINEntryView(
                        memberName: teen.displayName,
                        onVerify: { pin in await verify(pin, for: teen) },
                        onSuccess: { pinTarget = nil; session.selectTeen(teen) },
                        onCancel: { pinTarget = nil })
                }
                .fullScreenCover(isPresented: $showParentGate) {
                    PINEntryView(
                        memberName: "Parent",
                        prompt: "Enter parent passcode",
                        onVerify: { code in session.verifyParentPasscode(code) ? .valid : .wrong },
                        onSuccess: { showParentGate = false; session.disableFamilyDevice() },
                        onCancel: { showParentGate = false })
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load profiles",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await load() } })
        case .loaded:
            if teens.isEmpty {
                EmptyStateView(icon: "person.2", headline: "No teen profiles yet",
                               subline: "Switch to Parent to add one.", kind: .neutral)
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(teens) { teen in
                    Button { select(teen) } label: { tile(teen) }
                        .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func tile(_ teen: Member) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Text(initials(teen.displayName))
                    .font(.title.bold())
                    .foregroundStyle(.tint)
            }
            .frame(width: 96, height: 96)
            .overlay(alignment: .bottomTrailing) {
                if teen.hasPIN {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .padding(6)
                        .background(.regularMaterial, in: Circle())
                }
            }
            Text(teen.displayName).font(.headline)
        }
    }

    /// Leaving family mode requires the parent passcode (so a kid can't switch
    /// to the parent controls). If none was ever set, allow the exit directly.
    private func exitToParent() {
        if session.hasParentPasscode {
            showParentGate = true
        } else {
            session.disableFamilyDevice()
        }
    }

    private func select(_ teen: Member) {
        // `pin_set` from the member list tells us whether a gate is needed
        // without a verify round-trip (auth-endpoints §5).
        if teen.hasPIN {
            pinTarget = teen
        } else {
            session.selectTeen(teen)
        }
    }

    /// Verify server-side, falling back to the local PINStore when offline.
    private func verify(_ pin: String, for teen: Member) async -> PINVerifyResult {
        do {
            let result = try await session.api.verifyPIN(memberID: teen.id, pin: pin)
            return result.valid ? .valid : .wrong
        } catch APIError.rateLimited {
            return .rateLimited
        } catch APIError.transport {
            // Offline: fall back to a PIN this device set locally, if any.
            if let local = session.pinStore.pin(for: teen.id) {
                return local == pin ? .valid : .wrong
            }
            return .error
        } catch {
            return .error
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func load() async {
        do {
            teens = try await session.api.members().filter { $0.role == .teen }
            state = .loaded
        } catch {
            state = .failed("Check your connection and try again.")
        }
    }
}
