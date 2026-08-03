//
//  StatusBadge.swift
//  KidsChores
//
//  Small label + color + glyph per TaskStatus (ios-prd §6.5). Color is never
//  the only signal (accessibility §13) — every badge pairs color with a glyph
//  and text. `TaskStatus` is the single source of truth for the text.
//

import SwiftUI

/// Presentation mapping for a `TaskStatus`. Kept as a pure value type (SRP) so
/// both `StatusBadge` and, e.g., a row's leading glyph can share one mapping.
struct StatusStyle {
    let label: String
    let systemImage: String
    let color: Color

    init(_ status: TaskStatus) {
        switch status {
        case .pending:
            self = .init(label: "Pending", systemImage: "circle", color: .secondary)
        case .reviewPending:
            self = .init(label: "In review", systemImage: "clock", color: .orange)
        case .complete:
            self = .init(label: "Done", systemImage: "checkmark.circle.fill", color: .green)
        case .overdue:
            self = .init(label: "Overdue", systemImage: "exclamationmark.circle", color: .orange)
        case .excusePending:
            self = .init(label: "Excuse sent", systemImage: "text.bubble", color: .secondary)
        case .excused:
            self = .init(label: "Excused", systemImage: "checkmark.circle", color: .green)
        case .missed:
            // Low-emphasis red — a missed task is a fact, not a punishment (§6.1).
            self = .init(label: "Missed", systemImage: "xmark.circle", color: .red)
        case .cancelled:
            self = .init(label: "Cancelled", systemImage: "slash.circle", color: .secondary)
        case .unknown:
            self = .init(label: "—", systemImage: "questionmark.circle", color: .secondary)
        }
    }

    private init(label: String, systemImage: String, color: Color) {
        self.label = label
        self.systemImage = systemImage
        self.color = color
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        let style = StatusStyle(status)
        Label(style.label, systemImage: style.systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(style.color)
            .accessibilityLabel(style.label)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(TaskStatus.allCases, id: \.self) { StatusBadge(status: $0) }
    }
    .padding()
}
