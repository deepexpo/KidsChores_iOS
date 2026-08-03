//
//  FamilyMemberDetailView.swift
//  KidsChores
//
//  A teen as the parent sees them (ios-prd §8.2): balance, this-week completion
//  ring, an Adjust-points action, and a read-only recent ledger. Uses member_id
//  scoping on the wallet/ledger reads.
//

import SwiftUI

@MainActor
@Observable
private final class MemberDetailViewModel {
    let member: Member
    private(set) var balance: Int = 0
    private(set) var pointsLabel = "points"
    private(set) var ledger: [LedgerEntry] = []
    private(set) var pinIsSet: Bool
    var errorMessage: String?

    let completedThisWeek: Int
    let totalThisWeek: Int

    private let walletService: WalletService
    private let householdService: HouseholdService
    private let pinStore: PINStore

    init(member: Member, completedThisWeek: Int, totalThisWeek: Int,
         walletService: WalletService, householdService: HouseholdService, pinStore: PINStore) {
        self.member = member
        self.completedThisWeek = completedThisWeek
        self.totalThisWeek = totalThisWeek
        self.walletService = walletService
        self.householdService = householdService
        self.pinStore = pinStore
        self.pinIsSet = member.hasPIN
    }

    func load() async {
        do {
            async let wallet = walletService.wallet(memberID: member.id)
            async let entries = walletService.ledger(memberID: member.id, limit: 30, offset: 0)
            let (w, l) = try await (wallet, entries)
            balance = w.balance
            pointsLabel = w.pointsLabel
            ledger = l
        } catch {
            errorMessage = "Couldn't load \(member.displayName)'s wallet."
        }
    }

    func adjust(delta: Int, reason: String) async -> Bool {
        do {
            _ = try await walletService.adjust(
                memberID: member.id,
                AdjustWalletRequest(memberID: member.id, delta: delta, reason: reason))
            await load()      // balance re-fetched server-side
            return true
        } catch {
            errorMessage = "Couldn't adjust points. Please try again."
            return false
        }
    }

    /// Set/change (`pin != nil`) or clear (`pin == nil`) the teen's PIN.
    func updatePIN(_ pin: String?) async {
        do {
            let updated = try await householdService.setMemberPIN(memberID: member.id, pin: pin)
            pinIsSet = updated.hasPIN
            // Keep the local offline-fallback copy in sync.
            if let pin { pinStore.setPIN(pin, for: member.id) } else { pinStore.clear(for: member.id) }
        } catch {
            errorMessage = "Couldn't update the PIN. Please try again."
        }
    }

    /// Remove the teen from the household (`DELETE /v1/household/members/{id}`).
    func delete() async -> Bool {
        do {
            try await householdService.deleteMember(id: member.id)
            pinStore.clear(for: member.id)
            return true
        } catch let error as APIError {
            errorMessage = Self.deleteMessage(for: error, name: member.displayName)
            return false
        } catch {
            errorMessage = "Couldn't remove \(member.displayName). Please try again."
            return false
        }
    }

    /// Surfaces the server's reason. Deleting a teen that has task instances /
    /// ledger history fails on the backend today (a data-integrity constraint) —
    /// this reports it clearly instead of a generic "try again".
    private static func deleteMessage(for error: APIError, name: String) -> String {
        switch error {
        case .unprocessable(let detail):
            return detail ?? "\(name) still has tasks or history, so they can't be removed yet."
        case .server(let status, let detail):
            return detail ?? "Couldn't remove \(name) (server error \(status)). They may still have tasks or history."
        case .forbidden:
            return "Only a parent can remove a teen."
        case .transport:
            return "Couldn't reach the server. Check your connection and try again."
        case .notFound:
            return "\(name) is already removed."
        case .unauthorized, .rateLimited, .decoding:
            return "Couldn't remove \(name). Please try again."
        }
    }
}

struct FamilyMemberDetailView: View {
    @State private var vm: MemberDetailViewModel
    @State private var showAdjust = false
    @State private var showSetPIN = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    /// Called after the teen is removed, so the Family list can refresh.
    var onDeleted: () -> Void = {}

    init(member: Member, completedThisWeek: Int, totalThisWeek: Int,
         walletService: WalletService, householdService: HouseholdService, pinStore: PINStore,
         onDeleted: @escaping () -> Void = {}) {
        self.onDeleted = onDeleted
        _vm = State(initialValue: MemberDetailViewModel(
            member: member, completedThisWeek: completedThisWeek,
            totalThisWeek: totalThisWeek, walletService: walletService,
            householdService: householdService, pinStore: pinStore))
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Text("\(vm.balance)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(vm.pointsLabel).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        SeriesProgressRing(completed: vm.completedThisWeek,
                                           total: vm.totalThisWeek, diameter: 60)
                        VStack(alignment: .leading) {
                            Text("This week").font(.subheadline.weight(.medium))
                            Text("\(vm.completedThisWeek) of \(vm.totalThisWeek) done")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    showAdjust = true
                } label: {
                    Label("Adjust \(vm.pointsLabel)", systemImage: "slider.horizontal.3")
                }
            }

            Section {
                Button {
                    showSetPIN = true
                } label: {
                    Label(vm.pinIsSet ? "Change shared-device PIN" : "Set shared-device PIN",
                          systemImage: "lock.rotation")
                }
                if vm.pinIsSet {
                    Button(role: .destructive) {
                        Task { await vm.updatePIN(nil) }
                    } label: {
                        Label("Remove PIN", systemImage: "lock.open")
                    }
                }
            } footer: {
                Text(vm.pinIsSet
                     ? "\(vm.member.displayName) unlocks their profile on a shared device with this PIN."
                     : "Add a PIN so \(vm.member.displayName)'s profile is gated on a shared family device.")
            }

            Section("Recent history") {
                if vm.ledger.isEmpty {
                    Text("No history yet.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(vm.ledger) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.reason).font(.subheadline).lineLimit(2)
                                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            PointPill(value: entry.delta)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove \(vm.member.displayName)", systemImage: "person.badge.minus")
                }
            }
        }
        .navigationTitle(vm.member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showAdjust) {
            AdjustPointsSheet(memberName: vm.member.displayName, pointsLabel: vm.pointsLabel) { delta, reason in
                await vm.adjust(delta: delta, reason: reason)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSetPIN) {
            PasscodeSetupSheet(
                navTitle: "\(vm.member.displayName)'s PIN",
                setPrompt: "Set \(vm.member.displayName)'s PIN",
                confirmPrompt: "Confirm the PIN"
            ) { code in
                Task { await vm.updatePIN(code) }
            }
        }
        .confirmationDialog("Remove \(vm.member.displayName)?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove \(vm.member.displayName)", role: .destructive) {
                Task {
                    if await vm.delete() {
                        onDeleted()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes their profile from the household. This can't be undone.")
        }
        .alert("Couldn't complete", isPresented: errorBinding) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }
}
