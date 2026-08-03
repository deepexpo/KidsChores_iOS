//
//  ReportsView.swift
//  KidsChores
//
//  Per-teen reports (ios-prd §8.5): completion-rate trend, excuse frequency,
//  and points earned per week. Excuse frequency is styled as *informational*,
//  not accusatory — neutral color, no alarming red (§8.6).
//

import SwiftUI
import Charts

struct ReportsView: View {
    @State private var vm: ReportsViewModel

    init(reportService: ReportService, householdService: HouseholdService) {
        _vm = State(initialValue: ReportsViewModel(
            reportService: reportService, householdService: householdService))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Reports")
                .task { await vm.load() }
                .refreshable { await vm.loadReport() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyStateView(icon: "wifi.slash", headline: "Couldn't load reports",
                           subline: message, kind: .error,
                           actionTitle: "Retry", action: { Task { await vm.load() } })
        case .noTeens:
            EmptyStateView(icon: "chart.xyaxis.line", headline: "No teens yet",
                           subline: "Add a teen in Family to see their reports.", kind: .neutral)
        case .loaded:
            report
        }
    }

    @ViewBuilder
    private var report: some View {
        @Bindable var vm = vm
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Picker("Teen", selection: $vm.selectedTeenID) {
                        ForEach(vm.teens) { Text($0.displayName).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.menu)

                    Picker("Range", selection: $vm.weeks) {
                        Text("4 weeks").tag(4)
                        Text("12 weeks").tag(12)
                    }
                    .pickerStyle(.segmented)
                }

                if vm.isLoadingReport {
                    ProgressView().padding(.top, 40)
                } else if !vm.hasData {
                    EmptyStateView(icon: "chart.bar.doc.horizontal",
                                   headline: "Not enough history yet",
                                   subline: "Reports fill in as tasks are completed week by week.",
                                   kind: .neutral)
                        .frame(height: 260)
                } else if let weeks = vm.report?.weeks {
                    completionCard(weeks)
                    pointsCard(weeks)
                    excusesCard(weeks)
                }
            }
            .padding()
        }
    }

    // MARK: - Charts

    private func completionCard(_ weeks: [ReportWeek]) -> some View {
        card(title: "Completion rate", subtitle: "Share of tasks completed each week") {
            Chart(weeks) { week in
                LineMark(x: .value("Week", week.date, unit: .weekOfYear),
                         y: .value("Completion", week.completionRate))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                PointMark(x: .value("Week", week.date, unit: .weekOfYear),
                          y: .value("Completion", week.completionRate))
                    .foregroundStyle(Color.accentColor)
                AreaMark(x: .value("Week", week.date, unit: .weekOfYear),
                         y: .value("Completion", week.completionRate))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.25), .clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(format: .percent, values: [0, 0.5, 1])
            }
        }
    }

    private func pointsCard(_ weeks: [ReportWeek]) -> some View {
        card(title: "Points earned", subtitle: "Per week") {
            Chart(weeks) { week in
                BarMark(x: .value("Week", week.date, unit: .weekOfYear),
                        y: .value("Points", week.pointsEarned))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
            }
        }
    }

    private func excusesCard(_ weeks: [ReportWeek]) -> some View {
        card(title: "Excuses", subtitle: "How often, week to week — just for awareness") {
            Chart(weeks) { week in
                BarMark(x: .value("Week", week.date, unit: .weekOfYear),
                        y: .value("Excuses", week.excuseCount))
                    // Neutral/informational — not accusatory (§8.6).
                    .foregroundStyle(Color.secondary)
                    .cornerRadius(4)
            }
        }
    }

    private func card<Content: View>(title: String, subtitle: String,
                                     @ViewBuilder chart: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            chart()
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
