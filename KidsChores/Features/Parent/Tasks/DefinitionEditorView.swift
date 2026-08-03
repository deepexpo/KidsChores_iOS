//
//  DefinitionEditorView.swift
//  KidsChores
//
//  The task create/edit form (ios-prd §8.3). Segmented schedule control with a
//  conditional weekday row; requires_review carries an inline explainer so the
//  parent understands the auto-pay vs. approve distinction.
//

import SwiftUI

struct DefinitionEditorView: View {
    @State private var vm: DefinitionEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(service: DefinitionService,
         assignees: [Member],
         existing: TaskDefinition?,
         onSaved: @escaping () -> Void) {
        _vm = State(initialValue: DefinitionEditorViewModel(
            service: service, assignees: assignees, existing: existing, onSaved: onSaved))
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                scheduleSection
                reviewSection
                if let error = vm.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(vm.isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.save(); if vm.errorMessage == nil { dismiss() } }
                    }
                    .disabled(!vm.isValid || vm.isSaving)
                }
            }
            .overlay { if vm.isSaving { ProgressView() } }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $vm.title)
            TextField("Description (optional)", text: $vm.details, axis: .vertical)
                .lineLimit(1...3)

            Picker("Assignee", selection: $vm.assigneeID) {
                ForEach(vm.assignees) { member in
                    Text(member.displayName).tag(member.id)
                }
            }
            .disabled(vm.isEditing)     // assignee can't change on edit (API §6)

            Stepper(value: $vm.pointValue, in: 1...10_000) {
                HStack {
                    Text("Points")
                    Spacer()
                    Text("\(vm.pointValue)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Repeats", selection: $vm.scheduleType) {
                Text("One-time").tag(ScheduleType.oneTime)
                Text("Daily").tag(ScheduleType.daily)
                Text("Weekdays").tag(ScheduleType.weekdays)
                Text("Weekly").tag(ScheduleType.weekly)
            }
            .pickerStyle(.segmented)

            if vm.showsWeekdayPicker {
                weekdayRow
            }

            DatePicker(vm.scheduleType == .oneTime ? "Date" : "Starts",
                       selection: $vm.startDate, displayedComponents: .date)
                .disabled(vm.isEditing)     // start_date is immutable on edit

            if vm.scheduleType != .oneTime {
                Toggle("Set an end date", isOn: $vm.hasEndDate)
                if vm.hasEndDate {
                    DatePicker("Ends", selection: $vm.endDate, in: vm.startDate...,
                               displayedComponents: .date)
                }
            }

            DatePicker("Due by", selection: $vm.dueTime, displayedComponents: .hourAndMinute)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let on = vm.weekdays.days.contains(day)
                Button {
                    vm.weekdays.toggle(day)
                } label: {
                    Text(day.shortLabel.prefix(1))
                        .font(.caption.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(on ? Color.accentColor : Color(.secondarySystemBackground),
                                    in: Circle())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortLabel)
                .accessibilityValue(on ? "selected" : "not selected")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var reviewSection: some View {
        Section {
            Toggle("Requires my review", isOn: $vm.requiresReview)
        } footer: {
            Text(vm.requiresReview
                 ? "On: you approve each completion before points are paid."
                 : "Off: pays automatically when the teen marks it done.")
        }
    }
}
