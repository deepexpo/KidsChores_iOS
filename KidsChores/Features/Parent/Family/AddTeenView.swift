//
//  AddTeenView.swift
//  KidsChores
//
//  Create a teen profile (PRD §6.1, api-reference §5). Optional 4-digit PIN for
//  shared-device mode — stored locally on success (the backend hashes it but
//  never returns it, so the client keeps its own copy for the PIN gate).
//

import SwiftUI

struct AddTeenView: View {
    let householdService: HouseholdService
    let pinStore: PINStore
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var birthdate = Calendar.current.date(byAdding: .year, value: -14, to: .now) ?? .now
    @State private var usePIN = false
    @State private var pin = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isThirteenPlus: Bool {
        (Calendar.current.dateComponents([.year], from: birthdate, to: .now).year ?? 0) >= 13
    }
    private var pinValid: Bool { !usePIN || (pin.count == 4 && pin.allSatisfy(\.isNumber)) }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isThirteenPlus && pinValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Teen") {
                    TextField("Name", text: $name)
                    DatePicker("Birthdate", selection: $birthdate, displayedComponents: .date)
                    if !isThirteenPlus {
                        Label("Must be 13 or older.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    Toggle("Set a PIN for shared devices", isOn: $usePIN)
                    if usePIN {
                        TextField("4-digit PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .onChange(of: pin) { _, new in
                                pin = String(new.filter(\.isNumber).prefix(4))
                            }
                    }
                } footer: {
                    Text("A PIN gates this profile on a shared family device. It's convenience, not security.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Add Teen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let request = CreateTeenRequest(
            displayName: name.trimmingCharacters(in: .whitespaces),
            birthdate: Self.apiDate(birthdate),
            pin: usePIN ? pin : nil)
        do {
            let member = try await householdService.createTeen(request)
            if usePIN { pinStore.setPIN(pin, for: member.id) }
            onCreated()
            dismiss()
        } catch APIError.unprocessable(let detail) {
            errorMessage = detail ?? "Couldn't add this teen. Check the details."
        } catch {
            errorMessage = "Couldn't reach the server. Please try again."
        }
    }

    private static func apiDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
