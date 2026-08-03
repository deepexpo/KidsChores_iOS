//
//  AuthViewModel.swift
//  KidsChores
//
//  Drives email/password login and registration. Keeps auth logic out of the
//  view (SRP) and depends only on `AuthService` (DIP), not the whole API.
//  Sign in with Apple is deferred to a later phase.
//

import Foundation

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable {
        case login = "Log In"
        case register = "Create Account"
    }

    var mode: Mode = .login
    var email = ""
    var password = ""
    var displayName = ""

    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    private let service: AuthService
    /// Called with the fresh tokens on success (wired to `AppSession.didSignIn`).
    private let onSignedIn: (AuthTokens) -> Void

    init(service: AuthService, onSignedIn: @escaping (AuthTokens) -> Void) {
        self.service = service
        self.onSignedIn = onSignedIn
    }

    // MARK: - Validation

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private var isPasswordValid: Bool { password.count >= 8 }

    private var isNameValid: Bool {
        mode == .login || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canSubmit: Bool {
        !isSubmitting && isEmailValid && isPasswordValid && isNameValid
    }

    // MARK: - Submit

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let cleanEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            let tokens: AuthTokens
            switch mode {
            case .login:
                tokens = try await service.login(
                    EmailLoginRequest(email: cleanEmail, password: password))
            case .register:
                tokens = try await service.register(
                    EmailRegisterRequest(
                        email: cleanEmail,
                        password: password,
                        displayName: displayName.trimmingCharacters(in: .whitespaces)))
            }
            onSignedIn(tokens)
        } catch let error as APIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    func toggleMode() {
        mode = (mode == .login) ? .register : .login
        errorMessage = nil
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .unauthorized:
            return "Incorrect email or password."
        case .unprocessable(let detail):
            return detail ?? "Please check your details and try again."
        case .rateLimited:
            return "Too many attempts. Please wait a moment and try again."
        case .transport:
            return "Couldn't reach the server. Check your connection and try again."
        case .forbidden, .notFound, .server, .decoding:
            return "Something went wrong. Please try again."
        }
    }
}
