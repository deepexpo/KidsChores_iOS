//
//  AppContainer.swift
//  KidsChores
//
//  Composition root. Constructs the object graph in one place so the rest of
//  the app depends on protocols, never on concrete construction (DIP).
//

import Foundation
import SwiftData

/// Owns the singletons wired at launch. Injected into the view tree via
/// `AppSession`; features receive only the narrow service protocols they need.
struct AppContainer {
    let api: KidsChoresAPI
    let tokenStore: TokenStore
    /// Local shared-device profile PINs (not a security boundary — see PINStore).
    let pinStore: PINStore
    /// Backs the offline outbox (and, later, the cached Today/Week store).
    /// TODO: move into an App Group container before shipping the widget (§10).
    let modelContainer: ModelContainer

    init(baseURL: URL) {
        let store = KeychainTokenStore()
        let provider = TokenProvider(store: store, baseURL: baseURL)
        let http = URLSessionHTTPClient(baseURL: baseURL, tokenProvider: provider)
        self.api = LiveAPIClient(http: http)
        self.tokenStore = store
        self.pinStore = KeychainPINStore()
        self.modelContainer = Self.makeModelContainer()
    }

    /// Escape hatch for previews/tests to inject fakes.
    init(api: KidsChoresAPI, tokenStore: TokenStore,
         pinStore: PINStore = InMemoryPINStore(), inMemory: Bool = true) {
        self.api = api
        self.tokenStore = tokenStore
        self.pinStore = pinStore
        self.modelContainer = Self.makeModelContainer(inMemory: inMemory)
    }

    static func makeModelContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: OutboxAction.self, CachedTaskInstance.self,
                                      configurations: config)
        } catch {
            // A corrupt local store shouldn't brick the app; fall back to memory.
            return try! ModelContainer(for: OutboxAction.self, CachedTaskInstance.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    /// Base URL for the API.
    ///
    /// Override at runtime by setting the `API_BASE_URL` environment variable in
    /// the Xcode scheme (Product → Scheme → Edit → Run → Arguments → Environment
    /// Variables), e.g. `http://192.168.1.42:8000` when testing on a physical
    /// device. On a device, `localhost` points at the device itself — you must
    /// use your Mac's LAN IP. Falls back to localhost (works on the Simulator).
    static var localDev: URL {
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:8000")!
    }
}
