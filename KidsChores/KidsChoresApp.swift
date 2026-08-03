//
//  KidsChoresApp.swift
//  KidsChores
//
//  Created by Kuldeep Singh on 2026-08-01.
//

import SwiftUI

@main
struct KidsChoresApp: App {
    // Composition root built once at launch; injected as the app session.
    @State private var session = AppSession(container: AppContainer(baseURL: AppContainer.localDev))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
