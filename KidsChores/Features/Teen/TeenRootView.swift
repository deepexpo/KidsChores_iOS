//
//  TeenRootView.swift
//  KidsChores
//
//  iPhone-teen IA (ios-prd §4.1): Today / Week / Wallet. No Inbox tab — teens
//  never see approvals. (Note: an own-device teen login isn't wired server-side
//  yet — API §5 — so in v1 this surface is reached via shared-device mode.)
//

import SwiftUI

struct TeenRootView: View {
    @Environment(AppSession.self) private var session
    let memberID: String
    /// Non-nil only on a shared device — enables the "Switch Profile" tab (§4.4).
    var profileName: String? = nil
    var onSwitchProfile: (() -> Void)? = nil

    var body: some View {
        TabView {
            Tab("Today", systemImage: "checklist") {
                TodayView(memberID: memberID,
                          taskService: session.api,
                          walletService: session.api,
                          definitionCache: session.definitionCache,
                          outbox: session.outbox,
                          taskCache: session.taskCache)
            }
            Tab("Week", systemImage: "calendar") {
                WeekView(memberID: memberID,
                         taskService: session.api,
                         definitionCache: session.definitionCache,
                         outbox: session.outbox,
                         taskCache: session.taskCache)
            }
            Tab("Wallet", systemImage: "star.circle") {
                WalletView(memberID: memberID, walletService: session.api)
            }
            if let onSwitchProfile {
                Tab("Switch", systemImage: "person.crop.circle.badge.xmark") {
                    SwitchProfileView(profileName: profileName ?? "this profile",
                                      onSwitch: onSwitchProfile)
                }
            }
        }
    }
}

/// The "Switch Profile" tab on a shared device — always reachable from the tab
/// bar so siblings can hand the device off quickly (ios-prd §4.4).
private struct SwitchProfileView: View {
    let profileName: String
    let onSwitch: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Signed in as \(profileName)")
                    .font(.headline)
                Button {
                    onSwitch()
                } label: {
                    Label("Switch Profile", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}

/// Temporary scaffold screen so the IA is navigable before features are built.
struct PlaceholderScreen: View {
    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            EmptyStateView(icon: "hammer",
                           headline: title,
                           subline: note,
                           kind: .neutral)
                .navigationTitle(title)
        }
    }
}
