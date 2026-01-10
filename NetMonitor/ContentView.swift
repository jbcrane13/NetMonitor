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
            case .targets:
                TargetsView()
            case .devices:
                DevicesView()
            case .tools:
                ToolsView()
            case .settings:
                SettingsView()
            case nil:
                Text("Select a section")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer().container)
}
