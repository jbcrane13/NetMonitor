//
//  ContentView.swift
//  NetMonitor
//
//  Created on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSection: Section? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
        } detail: {
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
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer().container)
}
