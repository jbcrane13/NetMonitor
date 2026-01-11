//
//  ContentView.swift
//  NetMonitor
//
//  Created on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: Section? = .dashboard
    @State private var session: MonitoringSession?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
        } detail: {
            if let session = session {
                Group {
                    switch selectedSection {
                    case .dashboard:
                        DashboardView()
                            .accessibilityIdentifier("detail_dashboard")
                    case .targets:
                        TargetsView()
                            .accessibilityIdentifier("detail_targets")
                    case .devices:
                        DevicesView()
                            .accessibilityIdentifier("detail_devices")
                    case .tools:
                        ToolsView()
                            .accessibilityIdentifier("detail_tools")
                    case .settings:
                        SettingsView()
                            .accessibilityIdentifier("detail_settings")
                    case nil:
                        Text("Select a section")
                            .accessibilityIdentifier("detail_empty")
                    }
                }
                .environment(session)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            // Create monitoring session on appear
            session = MonitoringSession(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer().container)
}
