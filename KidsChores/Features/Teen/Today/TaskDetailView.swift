//
//  TaskDetailView.swift
//  KidsChores
//
//  Task Detail (ios-prd §7.4). The same complete/excuse actions as the row
//  swipe, surfaced as full-width buttons for accessibility/discoverability, and
//  used as the detail pane of the iPad two-column layout (§4.4).
//

import SwiftUI

/// Shared, view-model-agnostic model for the task detail pane, so both Today
/// and Week (whose row types differ) can drive the same `TaskDetailView`.
struct TaskDetail: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let dueAt: Date
    let pointValue: Int
    let status: TaskStatus
    let requiresReview: Bool
    let inSeries: Bool
    var conflictNote: String?
    /// Set by the owning row so the list and detail pane agree (e.g. a future
    /// non-series task isn't completable — see WeekViewModel).
    let canComplete: Bool
    let canExcuse: Bool
}

struct TaskDetailView: View {
    let detail: TaskDetail
    let onComplete: () -> Void
    let onExcuse: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title).font(.title2.bold())
                    HStack {
                        StatusBadge(status: detail.status)
                        Spacer()
                        PointPill(value: detail.pointValue, showsSign: false)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("Due") {
                    Text(detail.dueAt, format: .dateTime.weekday(.wide).hour().minute())
                }
                LabeledContent("Payout") {
                    Text(detail.requiresReview ? "After a parent approves" : "Automatic when marked done")
                }
                if detail.inSeries {
                    LabeledContent("Series") { Text("Part of a series") }
                }
            }

            if let description = detail.description, !description.isEmpty {
                Section("Description") {
                    Text(description)
                }
            }

            if let note = detail.conflictNote {
                Section {
                    Label(note, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            if detail.canComplete || detail.canExcuse {
                Section {
                    if detail.canComplete {
                        Button(action: onComplete) {
                            Label("Complete", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    if detail.canExcuse {
                        Button(action: onExcuse) {
                            Label("Add excuse", systemImage: "text.bubble")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}
