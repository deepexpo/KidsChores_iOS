//
//  WeekView.swift
//  KidsChores
//
//  Week (ios-prd §7.2): a 7-day scroll-snap header (today highlighted) above a
//  vertically scrolling list grouped by day. Tapping a day scrolls its section
//  into view rather than swapping the screen, keeping spatial context.
//

import SwiftUI

struct WeekView: View {
    @State private var vm: WeekViewModel
    @State private var excuseTarget: WeekViewModel.WeekRow?
    @State private var selectedDay: Date?
    /// Selected task → detail pane on iPad, push on iPhone (§4.4 / §7.4).
    @State private var selectedRowID: String?

    init(memberID: String,
         taskService: TaskService,
         definitionCache: DefinitionCache,
         outbox: Outbox,
         taskCache: TaskCache) {
        _vm = State(initialValue: WeekViewModel(
            memberID: memberID,
            taskService: taskService,
            definitionCache: definitionCache,
            outbox: outbox,
            taskCache: taskCache))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if vm.isOffline { OfflineBanner() }
                dayHeader
                Divider()
                content
            }
            .navigationTitle("Week")
            .task {
                if selectedDay == nil { selectedDay = vm.todayID }
                await vm.load()
            }
            .refreshable { await vm.refresh() }
            .sheet(item: $excuseTarget) { row in
                ExcuseComposerView(taskTitle: row.title) { text in
                    Task { await vm.excuse(row, text: text) }
                }
                .presentationDetents([.medium])
            }
        } detail: {
            detailPane
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedRowID, let row = vm.row(for: id) {
            TaskDetailView(
                detail: row.detail,
                onComplete: { Task { await vm.complete(row) } },
                onExcuse: { excuseTarget = row })
        } else {
            DetailPlaceholder(title: "Your week",
                              subtitle: "Tap a task from any day to see the details.")
        }
    }

    // MARK: - Day chip header

    private var dayHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.days) { day in
                    dayChip(day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func dayChip(_ day: WeekViewModel.DayGroup) -> some View {
        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
        return Button {
            selectedDay = day.date
        } label: {
            VStack(spacing: 2) {
                Text(day.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                Text(day.date, format: .dateTime.day())
                    .font(.headline)
                    .monospacedDigit()
            }
            .frame(width: 44, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground)))
            .foregroundStyle(isSelected ? .white : (day.isToday ? Color.accentColor : .primary))
            .overlay(alignment: .bottom) {
                if day.isToday && !isSelected {
                    Circle().fill(Color.accentColor).frame(width: 4, height: 4).padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day()))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load your week",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .loaded:
            dayList
        }
    }

    private var dayList: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedRowID) {
                ForEach(vm.days) { day in
                    Section {
                        if day.rows.isEmpty {
                            Text("Nothing due")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.rows) { row($0).tag($0.id) }
                        }
                    } header: {
                        Text(day.date, format: .dateTime.weekday(.wide).month().day())
                    }
                    .id(day.id)
                }
            }
            .listStyle(.insetGrouped)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.days)
            .onChange(of: selectedDay) { _, newValue in
                guard let newValue else { return }
                withAnimation { proxy.scrollTo(newValue, anchor: .top) }
            }
        }
    }

    @ViewBuilder
    private func row(_ row: WeekViewModel.WeekRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TaskRow(title: row.title, dueAt: row.dueAt, pointValue: row.pointValue,
                    status: row.status, secondaryBadges: row.inSeries ? ["Series"] : [])
            if let note = row.conflictNote {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if row.canComplete {
                Button { Task { await vm.complete(row) } } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if row.canExcuse {
                Button { excuseTarget = row } label: {
                    Label("Excuse", systemImage: "text.bubble")
                }
                .tint(.orange)
            }
        }
        .accessibilityActions {
            if row.canComplete {
                Button("Complete \(row.title)") { Task { await vm.complete(row) } }
            }
            if row.canExcuse {
                Button("Excuse \(row.title)") { excuseTarget = row }
            }
        }
    }
}
