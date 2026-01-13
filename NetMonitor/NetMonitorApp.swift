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
    @State private var deviceDiscovery: DeviceDiscoveryCoordinator?
    @State private var companionService: CompanionService?
    @State private var companionHandler: CompanionMessageHandler?
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
                .environment(deviceDiscovery)
                .onAppear {
                    Task { @MainActor in
                        await setupServices()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            MenuBarCommands(
                isMonitoring: Binding(
                    get: { monitoringSession?.isMonitoring ?? false },
                    set: { _ in }
                ),
                startMonitoring: { monitoringSession?.startMonitoring() },
                stopMonitoring: { monitoringSession?.stopMonitoring() }
            )
        }

        Settings {
            SettingsView()
        }
    }

    @MainActor
    private func setupServices() async {
        let context = sharedModelContainer.mainContext

        // 1. Set up monitoring session
        if monitoringSession == nil {
            monitoringSession = MonitoringSession(modelContext: context)
        }

        // 2. Set up device discovery
        if deviceDiscovery == nil {
            deviceDiscovery = DeviceDiscoveryCoordinator(modelContext: context)
        }

        // 3. Set up companion service
        if let session = monitoringSession,
           let discovery = deviceDiscovery,
           companionService == nil {
            companionHandler = CompanionMessageHandler(
                modelContext: context,
                monitoringSession: session,
                deviceDiscovery: discovery
            )

            companionService = CompanionService()

            // Create a local reference that can be safely captured
            let handler = companionHandler
            do {
                try await companionService?.start { @Sendable message, clientID in
                    await MainActor.run {
                        Task {
                            _ = await handler?.handle(message, from: clientID)
                        }
                    }
                    return nil
                }
            } catch {
                print("Failed to start companion service: \(error)")
            }
        }

        // 4. Set up menu bar
        if let session = monitoringSession, menuBarController == nil {
            menuBarController = MenuBarController(monitoringSession: session)
            menuBarController?.setup()
        }
    }
}
