//
//  AppSession.swift
//  KidsChores
//
//  Observable session state. Holds the current phase and drives the top-level
//  navigation branch (RootView). Restores any persisted session at launch.
//

import Foundation
import Observation

extension Notification.Name {
    /// Posted by `TokenProvider` when a refresh is permanently rejected — the
    /// session can no longer be renewed and the UI must return to sign-in.
    static let sessionExpired = Notification.Name("KidsChoresSessionExpired")
}

/// The top-level app state the UI branches on.
enum SessionPhase: Equatable {
    case loading
    case signedOut
    /// Signed in. `role` decides teen vs. parent experience (API §1.1).
    case signedIn(role: MemberRole, memberID: String, householdID: String)
}

@MainActor
@Observable
final class AppSession {
    private(set) var phase: SessionPhase = .loading

    private let container: AppContainer

    /// Shared teen-side services. Built once so the definition cache and the
    /// outbox are the same instances across Today/Week.
    let definitionCache: DefinitionCache
    let outbox: Outbox
    let taskCache: TaskCache

    // MARK: - Shared-device (family device) state

    private let defaults = UserDefaults.standard
    private let familyDeviceKey = "familyDeviceMode"

    /// When true and signed in as a parent, the device shows the teen
    /// profile-picker instead of the parent management surface (ios-prd §4.4).
    var isFamilyDevice: Bool {
        didSet { defaults.set(isFamilyDevice, forKey: familyDeviceKey) }
    }
    /// The teen profile currently unlocked on a shared device (in-memory only —
    /// re-picked on each launch).
    private(set) var activeTeen: Member?

    init(container: AppContainer) {
        self.container = container
        self.definitionCache = DefinitionCache(service: container.api)
        self.outbox = Outbox(container: container.modelContainer, taskService: container.api)
        self.taskCache = TaskCache(container: container.modelContainer)
        self.isFamilyDevice = defaults.bool(forKey: familyDeviceKey)

        // Return to sign-in if the session can no longer be refreshed.
        NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.signOut() }
        }
    }

    /// The service surface features draw from.
    var api: KidsChoresAPI { container.api }
    var pinStore: PINStore { container.pinStore }

    // MARK: - Parent passcode (gates leaving family-device mode)

    /// Reserved Keychain account for the parent's device passcode. Stored via
    /// the same PIN store; not a member id, so it can't collide with a teen PIN.
    private let parentPasscodeAccount = "__kidschores_parent_passcode__"

    var hasParentPasscode: Bool { pinStore.pin(for: parentPasscodeAccount) != nil }

    func setParentPasscode(_ code: String) {
        pinStore.setPIN(code, for: parentPasscodeAccount)
    }

    func verifyParentPasscode(_ code: String) -> Bool {
        pinStore.pin(for: parentPasscodeAccount) == code
    }

    // MARK: - Shared-device actions

    /// Enter family-device mode, reusing the already-set parent passcode.
    func enableFamilyDevice() {
        isFamilyDevice = true
        activeTeen = nil
    }

    /// Enter family-device mode, setting the parent passcode required to leave
    /// it. Only needed the first time (when no passcode exists yet).
    func enableFamilyDevice(passcode: String) {
        setParentPasscode(passcode)
        enableFamilyDevice()
    }

    func disableFamilyDevice() { isFamilyDevice = false; activeTeen = nil }
    func selectTeen(_ member: Member) { activeTeen = member }
    func switchProfile() { activeTeen = nil }

    /// Restore a persisted session, if any. Call once at launch.
    func restore() {
        if let tokens = container.tokenStore.read() {
            phase = .signedIn(role: tokens.role, memberID: tokens.memberID, householdID: tokens.householdID)
        } else {
            phase = .signedOut
        }
    }

    /// Persist a fresh sign-in and flip into the signed-in experience.
    func didSignIn(_ tokens: AuthTokens) {
        container.tokenStore.save(tokens)
        phase = .signedIn(role: tokens.role, memberID: tokens.memberID, householdID: tokens.householdID)
    }

    func signOut() {
        container.tokenStore.clear()
        activeTeen = nil
        phase = .signedOut
    }
}
