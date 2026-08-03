//
//  AuthModels.swift
//  KidsChores
//
//  Auth exchange models. Email/password (`/v1/auth/{register,login,refresh}`)
//  and Sign in with Apple are all implemented backend-side — see
//  docs/auth-endpoints.md. Email/password is the current client auth method;
//  Sign in with Apple is deferred client-side to a later phase.
//

import Foundation

/// Request body for `POST /v1/auth/apple`. Unauthenticated. (Next phase.)
struct AppleSignInRequest: Encodable {
    /// Identity token from `ASAuthorizationAppleIDCredential`.
    let identityToken: String
    /// 1–100 chars. Only used the *first* time this Apple ID is seen.
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case displayName = "display_name"
    }
}

/// `POST /v1/auth/login`.
struct EmailLoginRequest: Encodable {
    let email: String
    let password: String
}

/// `POST /v1/auth/register`. Parent-only — creates the household and this
/// person as `parent`, mirroring how Apple sign-in doubles as signup.
struct EmailRegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case email, password
        case displayName = "display_name"
    }
}

/// `POST /v1/auth/refresh`. The refresh token is rotating and single-use.
struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

/// Body for changing the signed-in account's password.
/// ⚠️ Assumed contract `POST /v1/auth/change-password` — see docs/auth-endpoints.md.
struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

/// Response from `POST /v1/auth/apple`. Sign-in *is* signup for a new Apple ID.
struct AuthTokens: Decodable {
    let accessToken: String
    /// Redeemable at `POST /v1/auth/refresh` (rotating, single-use). Wiring it
    /// into `TokenProvider` for pre-emptive refresh is a pending task.
    let refreshToken: String
    let memberID: String
    let householdID: String
    /// Branch the entire navigation stack on this (`RootView`).
    let role: MemberRole

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case memberID = "member_id"
        case householdID = "household_id"
        case role
    }
}
