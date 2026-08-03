//
//  HouseholdSettingsView.swift
//  KidsChores
//
//  Household settings form (ios-prd §8.6). Presented as a sheet from the gear
//  icon in the Family tab.
//

import SwiftUI

struct HouseholdSettingsView: View {
    @Environment(AppSession.self) private var session
    @State private var vm: HouseholdSettingsViewModel
    @State private var showPasscodeSetup = false
    @State private var showChangePasscode = false
    @Environment(\.dismiss) private var dismiss

    init(service: HouseholdService) {
        _vm = State(initialValue: HouseholdSettingsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Household")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await vm.save(); if vm.didSave { dismiss() } }
                        }
                        .disabled(!vm.isValid || vm.isSaving)
                    }
                }
                .task { await vm.load() }
                .sheet(isPresented: $showPasscodeSetup) {
                    PasscodeSetupSheet(
                        navTitle: "Family Device",
                        setPrompt: "Set a parent passcode",
                        confirmPrompt: "Confirm parent passcode",
                        explanation: "You'll need this to leave family mode and get back to the parent view."
                    ) { code in
                        session.enableFamilyDevice(passcode: code)
                    }
                }
                .sheet(isPresented: $showChangePasscode) {
                    PasscodeSetupSheet(
                        navTitle: "Parent Passcode",
                        setPrompt: session.hasParentPasscode ? "Set a new parent passcode" : "Set a parent passcode",
                        confirmPrompt: "Confirm parent passcode"
                    ) { code in
                        session.setParentPasscode(code)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load settings",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .loaded:
            form
        }
    }

    @ViewBuilder
    private var form: some View {
        @Bindable var vm = vm
        Form {
            Section("Household") {
                TextField("Name", text: $vm.name)
                Picker("Timezone", selection: $vm.timezone) {
                    ForEach(vm.timezoneOptions, id: \.self) { Text($0).tag($0) }
                }
            }

            Section {
                TextField("Points label", text: $vm.pointsLabel)
            } header: {
                Text("Points")
            } footer: {
                Text("What you call points in your house (e.g. \"stars\", \"coins\").")
            }

            Section {
                Picker("Excused tasks", selection: $vm.payoutPolicy) {
                    ForEach([ExcusedPayoutPolicy.excusedPaysNothing,
                             .excusedPaysPartial, .excusedPaysFull], id: \.self) {
                        Text(vm.label(for: $0)).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Excused payout")
            } footer: {
                Text(vm.explainer(for: vm.payoutPolicy))
            }

            Section {
                Stepper(value: $vm.gracePeriodHours, in: 1...72) {
                    HStack {
                        Text("Grace period")
                        Spacer()
                        Text("\(vm.gracePeriodHours)h").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("How long an overdue task stays actionable before it's marked missed.")
            }

            Section {
                Button {
                    // Only set a passcode the first time; reuse it afterwards.
                    if session.hasParentPasscode {
                        session.enableFamilyDevice()
                    } else {
                        showPasscodeSetup = true
                    }
                } label: {
                    Label("Use as a family device", systemImage: "ipad.and.iphone")
                }
            } footer: {
                Text(session.hasParentPasscode
                     ? "Show a teen profile picker instead of the parent view. Getting back needs your parent passcode."
                     : "Show a teen profile picker instead of the parent view. You'll set a parent passcode to get back to the parent view.")
            }

            Section {
                Button {
                    showChangePasscode = true
                } label: {
                    Label(session.hasParentPasscode ? "Change parent passcode" : "Set parent passcode",
                          systemImage: "key")
                }
            } footer: {
                Text("The passcode that unlocks the parent view when leaving family mode.")
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
        }
    }
}
