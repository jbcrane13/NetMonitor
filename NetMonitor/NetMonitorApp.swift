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
    @State private var notificationService: NotificationService?

    @AppStorage("autoStartMonitoring") private var autoStartMonitoring = false

    /// Check if running in UI test mode
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            NetworkTarget.self,
            TargetMeasurement.self,
            LocalDevice.self,
            SessionRecord.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

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
        // Skip services setup in UI test mode for clean termination
        guard !isUITesting else { return }

        let context = sharedModelContainer.mainContext

        // Create all services first (centralized service instantiation)
        let httpService = HTTPMonitorService()
        let icmpService = ICMPMonitorService()
        let tcpService = TCPMonitorService()
        let arpScanner = ARPScannerService()
        let bonjourScanner = BonjourDiscoveryService()
        let wakeOnLanService = WakeOnLanService()

        // 1. Set up monitoring session with injected services
        if monitoringSession == nil {
            monitoringSession = MonitoringSession(
                modelContext: context,
                httpService: httpService,
                icmpService: icmpService,
                tcpService: tcpService
            )
        }

        // 2. Set up device discovery with injected services
        if deviceDiscovery == nil {
            deviceDiscovery = DeviceDiscoveryCoordinator(
                modelContext: context,
                arpScanner: arpScanner,
                bonjourScanner: bonjourScanner
            )
        }

        // 3. Set up companion service
        if let session = monitoringSession,
           let discovery = deviceDiscovery,
           companionService == nil {
            companionHandler = CompanionMessageHandler(
                modelContext: context,
                monitoringSession: session,
                deviceDiscovery: discovery,
                wakeOnLanService: wakeOnLanService,
                icmpService: icmpService
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

        // 5. Set up notification service and request permission
        if notificationService == nil {
            notificationService = NotificationService()
            Task {
                _ = await notificationService?.requestAuthorization()
            }
        }

        // 7. Seed default targets on first launch
        await DefaultTargetsProvider.seedIfNeeded(modelContext: context)

        // 8. Auto-start monitoring if enabled in settings
        if autoStartMonitoring, let session = monitoringSession, !session.isMonitoring {
            session.startMonitoring()
        }
    }
}
