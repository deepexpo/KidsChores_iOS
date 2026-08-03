//
//  APIServices.swift
//  KidsChores
//
//  Interface-segregated service protocols (ISP). A view model depends only on
//  the capability it needs — the Today screen takes a `TaskService`, the Inbox
//  takes an `ApprovalService` — not one god-client. Concrete conformance lives
//  in `LiveAPIClient`; tests/previews substitute mocks (LSP).
//

import Foundation

// MARK: - Auth

protocol AuthService {
    /// Email + password sign-in — `POST /v1/auth/login`.
    func login(_ request: EmailLoginRequest) async throws -> AuthTokens

    /// Register a new parent + household — `POST /v1/auth/register`.
    func register(_ request: EmailRegisterRequest) async throws -> AuthTokens

    /// Redeem a refresh token for a fresh (rotated) token pair — `POST /v1/auth/refresh`.
    func refresh(_ request: RefreshRequest) async throws -> AuthTokens

    /// Exchanges an Apple identity token for session tokens. Deferred to a later
    /// phase (needs the Sign in with Apple entitlement) — kept ready here.
    func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokens
}

// MARK: - Account (the signed-in parent's own login)

protocol AccountService {
    /// Change the account password. ⚠️ Assumed `POST /v1/auth/change-password`.
    func changePassword(_ request: ChangePasswordRequest) async throws
    /// Permanently delete the account (and, for a sole owner, the household).
    /// ⚠️ Assumed `DELETE /v1/account`.
    func deleteAccount() async throws
}

// MARK: - Household & members

protocol HouseholdService {
    func household() async throws -> Household
    func updateHousehold(name: String?, timezone: String?, pointsLabel: String?,
                         excusedPayoutPolicy: ExcusedPayoutPolicy?, gracePeriodHours: Int?) async throws -> Household
    func members() async throws -> [Member]
    func createTeen(_ request: CreateTeenRequest) async throws -> Member
    func deleteMember(id: String) async throws
    /// Shared-device PIN check (§4.4). Always returns a result on 200; throws
    /// `.rateLimited` on 429, `.notFound` if the member isn't in the household.
    func verifyPIN(memberID: String, pin: String) async throws -> VerifyPINResponse

    /// Set/change (`pin != nil`) or clear (`pin == nil`) a teen's PIN. Parent
    /// only. ⚠️ Assumed `PUT /v1/household/members/{id}/pin` — confirm with backend.
    func setMemberPIN(memberID: String, pin: String?) async throws -> Member
}

// MARK: - Definitions (parent-managed templates)

protocol DefinitionService {
    func definitions(includeArchived: Bool) async throws -> [TaskDefinition]
    func createDefinition(_ request: CreateDefinitionRequest) async throws -> TaskDefinition
    func updateDefinition(id: String, _ request: CreateDefinitionRequest) async throws -> TaskDefinition
    func archiveDefinition(id: String) async throws
}

// MARK: - Task instances (the teen's daily loop)

protocol TaskService {
    func today(memberID: String?) async throws -> [TaskInstance]
    func week(start: String, memberID: String?) async throws -> [TaskInstance]
    func complete(instanceID: String, _ request: CompleteTaskRequest) async throws -> TaskInstance
    func excuse(instanceID: String, _ request: ExcuseTaskRequest) async throws -> TaskInstance
    func review(instanceID: String, _ request: ReviewRequest) async throws -> TaskInstance
    func cancel(instanceID: String, _ request: CancelTaskRequest) async throws -> TaskInstance
}

// MARK: - Approvals (the parent's inbox loop)

protocol ApprovalService {
    func approvals() async throws -> [ApprovalItem]
    func bulkResolve(_ request: BulkApprovalRequest) async throws -> BulkApprovalResponse
}

// MARK: - Series

protocol SeriesService {
    func series(includeArchived: Bool) async throws -> [Series]
    func createSeries(_ request: CreateSeriesRequest) async throws -> Series
    func seriesInstances(seriesID: String) async throws -> [SeriesInstance]
    /// Edit a series' name/bonus. ⚠️ Assumed `PATCH /v1/series/{id}`.
    func updateSeries(id: String, _ request: SeriesUpdateRequest) async throws -> Series
    /// `DELETE /v1/series/{id}` — archives (soft-delete), preserves history.
    func archiveSeries(id: String) async throws
}

// MARK: - Wallet, ledger, claims, goals

protocol WalletService {
    func wallet(memberID: String) async throws -> Wallet
    func ledger(memberID: String, limit: Int, offset: Int) async throws -> [LedgerEntry]
    func adjust(memberID: String, _ request: AdjustWalletRequest) async throws -> LedgerEntry
    func createClaim(_ request: CreateClaimRequest) async throws -> Claim
    /// Pending claims across the household, for the parent inbox. ⚠️ Assumed
    /// `GET /v1/wallet/claims?status=pending` — not in the API reference yet.
    func pendingClaims() async throws -> [Claim]
    func resolveClaim(claimID: String, _ request: ResolveClaimRequest) async throws -> Claim
    func createGoal(memberID: String, _ request: CreateGoalRequest) async throws -> SavingsGoal
}

// MARK: - Reports (P1)

protocol ReportService {
    /// Per-teen weekly report over the last `weeks` weeks. ⚠️ Assumed
    /// `GET /v1/reports/{member_id}?weeks=` — not in the API reference yet.
    func report(memberID: String, weeks: Int) async throws -> Report
}

/// Convenience umbrella for composition roots / previews that want everything.
/// Individual features should still depend on the narrow protocols above.
typealias KidsChoresAPI = AuthService & AccountService & HouseholdService & DefinitionService
    & TaskService & ApprovalService & SeriesService & WalletService & ReportService
