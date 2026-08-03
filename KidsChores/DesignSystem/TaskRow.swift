//
//  TaskRow.swift
//  KidsChores
//
//  Leading status glyph, title + due time, trailing point pill (ios-prd §6.5).
//  Because a TaskInstance's own `title` is always nil (API §7), the row takes a
//  resolved `title` from the caller's definition join — it doesn't fetch or
//  join itself (SRP / dependency inversion at the view boundary).
//

import SwiftUI

struct TaskRow: View {
    let title: String
    let dueAt: Date
    let pointValue: Int
    let status: TaskStatus
    /// Small secondary badges (e.g. "Note", "Series") shown under the title.
    var secondaryBadges: [String] = []

    private var isDone: Bool { status == .complete || status == .excused }

    var body: some View {
        HStack(spacing: 12) {
            let style = StatusStyle(status)
            Image(systemName: style.systemImage)
                .foregroundStyle(style.color)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(dueAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(secondaryBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)
            PointPill(value: pointValue, showsSign: false)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // VoiceOver: state the action target, not just the glyph (§13).
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(StatusStyle(status).label), \(pointValue) points")
    }
}

#Preview {
    List {
        TaskRow(title: "Wash dishes", dueAt: .now, pointValue: 40, status: .overdue)
        TaskRow(title: "Make bed", dueAt: .now, pointValue: 5, status: .complete,
                secondaryBadges: ["Series"])
    }
}
