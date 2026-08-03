//
//  WeekdayMask.swift
//  KidsChores
//
//  The API's weekday mask is bit 0 = Monday … bit 6 = Sunday (API §6) — which
//  is NOT Swift's Weekday ordering (Sun = 1 … Sat = 7). This helper is the one
//  place that mapping lives, so the editor's 7-toggle row can't get it wrong.
//

import Foundation

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }
    var bit: Int { 1 << rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }
}

/// A set of selected weekdays that round-trips to/from the API's 7-bit mask.
struct WeekdayMask: Equatable {
    var days: Set<Weekday>

    init(days: Set<Weekday> = []) { self.days = days }

    init(mask: Int) {
        self.days = Set(Weekday.allCases.filter { mask & $0.bit != 0 })
    }

    var mask: Int { days.reduce(0) { $0 | $1.bit } }
    var isEmpty: Bool { days.isEmpty }

    mutating func toggle(_ day: Weekday) {
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
    }

    /// Human summary for list rows, e.g. "Mon, Wed, Fri".
    var summary: String {
        Weekday.allCases.filter { days.contains($0) }.map(\.shortLabel).joined(separator: ", ")
    }
}
