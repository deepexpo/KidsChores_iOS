//
//  HouseholdSettingsViewModel.swift
//  KidsChores
//
//  Household settings (ios-prd §8.6): name, timezone, points label, excused
//  payout policy, grace period. Consequential settings get inline explainers
//  rather than a bare enum picker.
//

import Foundation

@MainActor
@Observable
final class HouseholdSettingsViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    var name = ""
    var timezone = TimeZone.current.identifier
    var pointsLabel = "points"
    var payoutPolicy: ExcusedPayoutPolicy = .excusedPaysNothing
    var gracePeriodHours = 24

    var isSaving = false
    var errorMessage: String?
    var didSave = false

    let timezoneOptions = TimeZone.knownTimeZoneIdentifiers

    private let service: HouseholdService

    init(service: HouseholdService) { self.service = service }

    func load() async {
        state = .loading
        do {
            let h = try await service.household()
            name = h.name
            timezone = h.timezone
            pointsLabel = h.pointsLabel
            payoutPolicy = h.excusedPayoutPolicy == .unknown ? .excusedPaysNothing : h.excusedPayoutPolicy
            gracePeriodHours = h.gracePeriodHours
            state = .loaded
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pointsLabel.trimmingCharacters(in: .whitespaces).isEmpty &&
        (1...72).contains(gracePeriodHours)
    }

    func save() async {
        guard isValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await service.updateHousehold(
                name: name.trimmingCharacters(in: .whitespaces),
                timezone: timezone,
                pointsLabel: pointsLabel.trimmingCharacters(in: .whitespaces),
                excusedPayoutPolicy: payoutPolicy,
                gracePeriodHours: gracePeriodHours)
            didSave = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func explainer(for policy: ExcusedPayoutPolicy) -> String {
        switch policy {
        case .excusedPaysNothing:
            return "Pays no points, but doesn't break a streak or count as missed."
        case .excusedPaysPartial:
            return "Pays 50% of the task's value."
        case .excusedPaysFull:
            return "Pays the full value."
        case .unknown:
            return ""
        }
    }

    func label(for policy: ExcusedPayoutPolicy) -> String {
        switch policy {
        case .excusedPaysNothing: "No points"
        case .excusedPaysPartial: "Half"
        case .excusedPaysFull: "Full"
        case .unknown: "—"
        }
    }

    private static func message(for error: Error) -> String {
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
}
