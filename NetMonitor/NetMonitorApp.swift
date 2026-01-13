//
//  NetMonitorApp.swift
//  NetMonitor
//
//  Created on 2026-01-10.
//

import SwiftUI
import SwiftData

@main
struct NetMonitorApp: App {
    @State private var monitoringSession: MonitoringSession?
    @State private var menuBarController: MenuBarController?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            NetworkTarget.self,
            TargetMeasurement.self,
            LocalDevice.self,
            SessionRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitoringSession)
                .onAppear {
                    setupMonitoringSession()
                    setupMenuBar()
                }
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
        }
    }

    @MainActor
    private func setupMonitoringSession() {
        if monitoringSession == nil {
            let context = sharedModelContainer.mainContext
            monitoringSession = MonitoringSession(modelContext: context)
        }
    }

    @MainActor
    private func setupMenuBar() {
        guard let session = monitoringSession, menuBarController == nil else { return }
        menuBarController = MenuBarController(monitoringSession: session)
        menuBarController?.setup()
    }
}
