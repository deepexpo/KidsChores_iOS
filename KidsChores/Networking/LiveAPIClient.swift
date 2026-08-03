//
//  LiveAPIClient.swift
//  KidsChores
//
//  The one concrete conformance to every service protocol, built on the
//  `HTTPClient` transport seam. Endpoint paths are the as-built ones from the
//  API reference (§11 summary), not the illustrative paths in the master PRD.
//

import Foundation

final class LiveAPIClient {
    private let http: HTTPClient
    private let encoder: JSONEncoder

    init(http: HTTPClient) {
        self.http = http
        self.encoder = JSONEncoder()
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try encoder.encode(value) }
        catch { throw APIError.decoding(underlying: String(describing: error)) }
    }
}

// MARK: - AuthService

extension LiveAPIClient: AuthService {
    func login(_ request: EmailLoginRequest) async throws -> AuthTokens {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/auth/login",
                        body: try encode(request), requiresAuth: false),
            as: AuthTokens.self)
    }

    func register(_ request: EmailRegisterRequest) async throws -> AuthTokens {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/auth/register",
                        body: try encode(request), requiresAuth: false),
            as: AuthTokens.self)
    }

    func refresh(_ request: RefreshRequest) async throws -> AuthTokens {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/auth/refresh",
                        body: try encode(request), requiresAuth: false),
            as: AuthTokens.self)
    }

    func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokens {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/auth/apple",
                        body: try encode(request), requiresAuth: false),
            as: AuthTokens.self)
    }
}

// MARK: - AccountService

extension LiveAPIClient: AccountService {
    func changePassword(_ request: ChangePasswordRequest) async throws {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/auth/change-password", body: try encode(request)))
    }

    func deleteAccount() async throws {
        try await http.send(HTTPRequest(method: "DELETE", path: "/v1/account"))
    }
}

// MARK: - HouseholdService

extension LiveAPIClient: HouseholdService {
    func household() async throws -> Household {
        try await http.send(HTTPRequest(method: "GET", path: "/v1/household"), as: Household.self)
    }

    func updateHousehold(name: String?, timezone: String?, pointsLabel: String?,
                         excusedPayoutPolicy: ExcusedPayoutPolicy?, gracePeriodHours: Int?) async throws -> Household {
        struct Body: Encodable {
            let name: String?, timezone: String?
            let pointsLabel: String?, excusedPayoutPolicy: ExcusedPayoutPolicy?, gracePeriodHours: Int?
            enum CodingKeys: String, CodingKey {
                case name, timezone
                case pointsLabel = "points_label"
                case excusedPayoutPolicy = "excused_payout_policy"
                case gracePeriodHours = "grace_period_hours"
            }
        }
        let body = Body(name: name, timezone: timezone, pointsLabel: pointsLabel,
                        excusedPayoutPolicy: excusedPayoutPolicy, gracePeriodHours: gracePeriodHours)
        return try await http.send(
            HTTPRequest(method: "PATCH", path: "/v1/household", body: try encode(body)),
            as: Household.self)
    }

    func members() async throws -> [Member] {
        try await http.send(HTTPRequest(method: "GET", path: "/v1/household/members"), as: [Member].self)
    }

    func createTeen(_ request: CreateTeenRequest) async throws -> Member {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/household/members/teens", body: try encode(request)),
            as: Member.self)
    }

    func deleteMember(id: String) async throws {
        try await http.send(HTTPRequest(method: "DELETE", path: "/v1/household/members/\(id)"))
    }

    func verifyPIN(memberID: String, pin: String) async throws -> VerifyPINResponse {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/household/members/\(memberID)/verify-pin",
                        body: try encode(VerifyPINRequest(pin: pin))),
            as: VerifyPINResponse.self)
    }

    func setMemberPIN(memberID: String, pin: String?) async throws -> Member {
        try await http.send(
            HTTPRequest(method: "PUT", path: "/v1/household/members/\(memberID)/pin",
                        body: try encode(MemberPINUpdateRequest(pin: pin))),
            as: Member.self)
    }
}

// MARK: - DefinitionService

extension LiveAPIClient: DefinitionService {
    func definitions(includeArchived: Bool) async throws -> [TaskDefinition] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/definitions",
                        query: [URLQueryItem(name: "include_archived", value: String(includeArchived))]),
            as: [TaskDefinition].self)
    }

    func createDefinition(_ request: CreateDefinitionRequest) async throws -> TaskDefinition {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/definitions", body: try encode(request)),
            as: TaskDefinition.self)
    }

    func updateDefinition(id: String, _ request: CreateDefinitionRequest) async throws -> TaskDefinition {
        try await http.send(
            HTTPRequest(method: "PATCH", path: "/v1/definitions/\(id)", body: try encode(request)),
            as: TaskDefinition.self)
    }

    func archiveDefinition(id: String) async throws {
        try await http.send(HTTPRequest(method: "DELETE", path: "/v1/definitions/\(id)"))
    }
}

// MARK: - TaskService

extension LiveAPIClient: TaskService {
    func today(memberID: String?) async throws -> [TaskInstance] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/tasks/today", query: memberIDQuery(memberID)),
            as: [TaskInstance].self)
    }

    func week(start: String, memberID: String?) async throws -> [TaskInstance] {
        var query = [URLQueryItem(name: "start", value: start)]
        query.append(contentsOf: memberIDQuery(memberID))
        return try await http.send(
            HTTPRequest(method: "GET", path: "/v1/tasks/week", query: query),
            as: [TaskInstance].self)
    }

    func complete(instanceID: String, _ request: CompleteTaskRequest) async throws -> TaskInstance {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/tasks/instances/\(instanceID)/complete", body: try encode(request)),
            as: TaskInstance.self)
    }

    func excuse(instanceID: String, _ request: ExcuseTaskRequest) async throws -> TaskInstance {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/tasks/instances/\(instanceID)/excuse", body: try encode(request)),
            as: TaskInstance.self)
    }

    func review(instanceID: String, _ request: ReviewRequest) async throws -> TaskInstance {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/tasks/instances/\(instanceID)/review", body: try encode(request)),
            as: TaskInstance.self)
    }

    func cancel(instanceID: String, _ request: CancelTaskRequest) async throws -> TaskInstance {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/tasks/instances/\(instanceID)/cancel", body: try encode(request)),
            as: TaskInstance.self)
    }

    private func memberIDQuery(_ memberID: String?) -> [URLQueryItem] {
        memberID.map { [URLQueryItem(name: "member_id", value: $0)] } ?? []
    }
}

// MARK: - ApprovalService

extension LiveAPIClient: ApprovalService {
    func approvals() async throws -> [ApprovalItem] {
        try await http.send(HTTPRequest(method: "GET", path: "/v1/approvals"), as: [ApprovalItem].self)
    }

    func bulkResolve(_ request: BulkApprovalRequest) async throws -> BulkApprovalResponse {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/approvals/bulk", body: try encode(request)),
            as: BulkApprovalResponse.self)
    }
}

// MARK: - SeriesService

extension LiveAPIClient: SeriesService {
    func series(includeArchived: Bool) async throws -> [Series] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/series",
                        query: [URLQueryItem(name: "include_archived", value: String(includeArchived))]),
            as: [Series].self)
    }

    func createSeries(_ request: CreateSeriesRequest) async throws -> Series {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/series", body: try encode(request)),
            as: Series.self)
    }

    func seriesInstances(seriesID: String) async throws -> [SeriesInstance] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/series/\(seriesID)/instances"),
            as: [SeriesInstance].self)
    }

    func updateSeries(id: String, _ request: SeriesUpdateRequest) async throws -> Series {
        try await http.send(
            HTTPRequest(method: "PATCH", path: "/v1/series/\(id)", body: try encode(request)),
            as: Series.self)
    }

    func archiveSeries(id: String) async throws {
        try await http.send(HTTPRequest(method: "DELETE", path: "/v1/series/\(id)"))
    }
}

// MARK: - ReportService

extension LiveAPIClient: ReportService {
    func report(memberID: String, weeks: Int) async throws -> Report {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/reports/\(memberID)",
                        query: [URLQueryItem(name: "weeks", value: String(weeks))]),
            as: Report.self)
    }
}

// MARK: - WalletService

extension LiveAPIClient: WalletService {
    func wallet(memberID: String) async throws -> Wallet {
        try await http.send(HTTPRequest(method: "GET", path: "/v1/wallet/\(memberID)"), as: Wallet.self)
    }

    func ledger(memberID: String, limit: Int, offset: Int) async throws -> [LedgerEntry] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/wallet/\(memberID)/ledger",
                        query: [URLQueryItem(name: "limit", value: String(limit)),
                                URLQueryItem(name: "offset", value: String(offset))]),
            as: [LedgerEntry].self)
    }

    func adjust(memberID: String, _ request: AdjustWalletRequest) async throws -> LedgerEntry {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/wallet/\(memberID)/adjust", body: try encode(request)),
            as: LedgerEntry.self)
    }

    func createClaim(_ request: CreateClaimRequest) async throws -> Claim {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/wallet/claims", body: try encode(request)),
            as: Claim.self)
    }

    func pendingClaims() async throws -> [Claim] {
        try await http.send(
            HTTPRequest(method: "GET", path: "/v1/wallet/claims",
                        query: [URLQueryItem(name: "status", value: "pending")]),
            as: [Claim].self)
    }

    func resolveClaim(claimID: String, _ request: ResolveClaimRequest) async throws -> Claim {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/wallet/claims/\(claimID)/resolve", body: try encode(request)),
            as: Claim.self)
    }

    func createGoal(memberID: String, _ request: CreateGoalRequest) async throws -> SavingsGoal {
        try await http.send(
            HTTPRequest(method: "POST", path: "/v1/wallet/\(memberID)/goals", body: try encode(request)),
            as: SavingsGoal.self)
    }
}
