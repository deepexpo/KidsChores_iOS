//
//  ParentRootView.swift
//  KidsChores
//
//  Parent IA, adaptive (ios-prd §4.2/§4.3, §10.3 — explicitly NOT a stretched
//  phone). Regular width (iPad, full-screen/large split) → NavigationSplitView
//  with an always-visible sidebar. Compact width (iPhone, Slide Over, narrow
//  multitasking) → tab bar. Both reuse the same feature views.
//
//  Reports is P1 with no backend endpoints yet (ios-prd §8.5) and is omitted
//  rather than shipped broken.
//

import SwiftUI

/// The parent's top-level sections, shared by the tab bar and the sidebar.
enum ParentSection: String, CaseIterable, Identifiable {
    case inbox, family, tasks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .family: "Family"
        case .tasks: "Tasks"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray"
        case .family: "person.2"
        case .tasks: "list.bullet.rectangle"
        }
    }
}

struct ParentRootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            ParentSplitView()
        } else {
            ParentTabView()
        }
    }
}

// MARK: - Compact: tab bar

private struct ParentTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        TabView {
            Tab(ParentSection.inbox.title, systemImage: ParentSection.inbox.systemImage) {
                parentSectionView(.inbox, session: session)
            }
            Tab(ParentSection.family.title, systemImage: ParentSection.family.systemImage) {
                parentSectionView(.family, session: session)
            }
            Tab(ParentSection.tasks.title, systemImage: ParentSection.tasks.systemImage) {
                parentSectionView(.tasks, session: session)
            }
        }
    }
}

// MARK: - Regular: sidebar split

private struct ParentSplitView: View {
    @Environment(AppSession.self) private var session
    @State private var selection: ParentSection? = .inbox
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            List(ParentSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.body.weight(.medium))
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
            .sheet(isPresented: $showSettings) {
                HouseholdSettingsView(service: session.api)
            }
        } detail: {
            if let selection {
                parentSectionView(selection, session: session)
                    .id(selection)      // fresh state per section
            } else {
                DetailPlaceholder(title: "Welcome back",
                                  subtitle: "Pick a section from the sidebar to get started.")
            }
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            BrandMark(size: 30)
                .padding(7)
                .background(Brand.backdrop, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("KidsChores")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    showSettings = true
                } label: {
                    Label("Household", systemImage: "gearshape")
                }
                Spacer()
                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
}

// MARK: - Shared section → view mapping

@ViewBuilder
private func parentSectionView(_ section: ParentSection, session: AppSession) -> some View {
    switch section {
    case .inbox:
        InboxView(approvalService: session.api, taskService: session.api)
    case .family:
        FamilyView(householdService: session.api,
                   walletService: session.api,
                   taskService: session.api)
    case .tasks:
        TasksListView(definitionService: session.api,
                      householdService: session.api,
                      seriesService: session.api)
    }
}
