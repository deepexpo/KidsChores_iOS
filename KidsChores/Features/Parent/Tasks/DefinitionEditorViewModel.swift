//
//  DefinitionEditorViewModel.swift
//  KidsChores
//
//  Create/edit a Task Definition (ios-prd §8.3). Point value is a stepper (not
//  free text) to avoid fat-finger 10,000-point typos. In edit mode the API
//  can't change assignee/start_date (API §6), so the form locks those.
//

import Foundation

@MainActor
@Observable
final class DefinitionEditorViewModel {
    let isEditing: Bool
    private let existingID: String?

    // Form fields
    var title: String
    var details: String
    var assigneeID: String
    var pointValue: Int
    var scheduleType: ScheduleType
    var weekdays: WeekdayMask
    var startDate: Date
    var hasEndDate: Bool
    var endDate: Date
    var dueTime: Date
    var requiresReview: Bool

    var isSaving = false
    var errorMessage: String?

    /// Teens available as assignees.
    let assignees: [Member]

    private let service: DefinitionService
    private let onSaved: () -> Void

    init(service: DefinitionService,
         assignees: [Member],
         existing: TaskDefinition?,
         onSaved: @escaping () -> Void) {
        self.service = service
        self.assignees = assignees
        self.onSaved = onSaved
        self.isEditing = existing != nil
        self.existingID = existing?.id

        self.title = existing?.title ?? ""
        self.details = existing?.description ?? ""
        self.assigneeID = existing?.assigneeID ?? assignees.first?.id ?? ""
        self.pointValue = existing?.pointValue ?? 10
        self.scheduleType = existing.map { $0.scheduleType == .unknown ? .daily : $0.scheduleType } ?? .daily
        self.weekdays = WeekdayMask(mask: existing?.weekdayMask ?? 0)
        self.startDate = Self.parseDate(existing?.startDate) ?? .now
        self.hasEndDate = existing?.endDate != nil
        self.endDate = Self.parseDate(existing?.endDate) ?? .now
        self.dueTime = Self.parseTime(existing?.dueTime) ?? Self.defaultDueTime
        self.requiresReview = existing?.requiresReview ?? false
    }

    // MARK: - Validation

    var showsWeekdayPicker: Bool { scheduleType == .weekdays }

    var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard (1...200).contains(trimmed.count) else { return false }
        guard (1...10_000).contains(pointValue) else { return false }
        guard !assigneeID.isEmpty else { return false }
        if scheduleType == .weekdays && weekdays.isEmpty { return false }
        if hasEndDate && endDate < startDate { return false }
        return true
    }

    // MARK: - Save

    func save() async {
        guard isValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let request = CreateDefinitionRequest(
            assigneeID: assigneeID,
            title: title.trimmingCharacters(in: .whitespaces),
            description: details.isEmpty ? nil : details,
            pointValue: pointValue,
            scheduleType: scheduleType,
            weekdayMask: scheduleType == .weekdays ? weekdays.mask : nil,
            startDate: Self.formatDate(startDate),
            endDate: hasEndDate ? Self.formatDate(endDate) : nil,
            dueTime: Self.formatTime(dueTime),
            requiresReview: requiresReview,
            seriesID: nil)

        do {
            if let existingID {
                _ = try await service.updateDefinition(id: existingID, request)
            } else {
                _ = try await service.createDefinition(request)
            }
            onSaved()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Date/time formatting (yyyy-MM-dd and HH:MM)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static var defaultDueTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    }

    static func parseDate(_ string: String?) -> Date? {
        string.flatMap { dateFormatter.date(from: $0) }
    }
    static func parseTime(_ string: String?) -> Date? {
        string.flatMap { timeFormatter.date(from: $0) }
    }
    static func formatDate(_ date: Date) -> String { dateFormatter.string(from: date) }
    static func formatTime(_ date: Date) -> String { timeFormatter.string(from: date) }

    private static func message(for error: Error) -> String {
        if case APIError.unprocessable(let detail) = error { return detail ?? "Please check the form." }
        if case APIError.transport = error {
            return "Couldn't reach the server. Check your connection and try again."
        }
        return "Couldn't save. Please try again."
    }
}
