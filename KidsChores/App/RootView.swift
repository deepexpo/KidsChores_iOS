//
//  RootView.swift
//  KidsChores
//
//  The top-level navigation branch. Per ios-prd §4, the app is one codebase,
//  two experiences, switched on `role` from sign-in — not two apps.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @State private var showSplash = true

    var body: some View {
        ZStack {
            content
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    session.restore()
                    withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .loading:
            Color(.systemBackground).ignoresSafeArea()
        case .signedOut:
            SignInView()
        case let .signedIn(role, memberID, _):
            switch role {
            case .parent:
                if session.isFamilyDevice {
                    // Shared-device mode: pick a teen, then run the teen surface
                    // under the parent's token, scoped by member_id (§4.4).
                    if let teen = session.activeTeen {
                        TeenRootView(memberID: teen.id,
                                     profileName: teen.displayName,
                                     onSwitchProfile: { session.switchProfile() })
                    } else {
                        ProfilePickerView()
                    }
                } else {
                    ParentRootView()
                }
            case .teen:
                TeenRootView(memberID: memberID)
            case .unknown:
                // Forward-compat: an unrecognised role shouldn't crash — treat
                // as signed-out and let the user re-authenticate.
                SignInView()
            }
        }
    }
}
