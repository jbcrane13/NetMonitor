//
//  NetMonitorApp.swift
//  NetMonitor
//
//  Created on 2026-01-10.
//

import SwiftUI
import SwiftData
import os

@main
struct NetMonitorApp: App {
    @State private var monitoringSession: MonitoringSession?
    @State private var deviceDiscovery: DeviceDiscoveryCoordinator?
    @State private var companionService: CompanionService?
    @State private var companionHandler: CompanionMessageHandler?
    @State private var menuBarController: MenuBarController?
    @State private var notificationService: NotificationService?

    @AppStorage("autoStartMonitoring") private var autoStartMonitoring = false
    @AppStorage("netmonitor.appearance.accentColor") private var accentColorHex = "#06B6D4"
    @AppStorage("netmonitor.appearance.compactMode") private var compactMode = false

    /// Check if monitoring should be disabled (for testing)
    private var shouldDisableMonitoring: Bool {
        isUITesting || ProcessInfo.processInfo.environment["DISABLE_MONITORING"] == "1"
    }

    /// Check if running in UI test mode
    private var isUITesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--uitesting") ||
           arguments.contains("--disable-local-auth") ||
           arguments.contains("--disable-keychain-access") {
            return true
        }

        let environment = ProcessInfo.processInfo.environment
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
           environment["XCUITest"] == "1" ||
           environment["UITEST_MODE"] == "1" ||
           environment["DISABLE_AUTHENTICATION"] == "1" ||
           environment["CI"] == "true" {
            return true
        }

        if NSClassFromString("XCTest") != nil {
            return true
        }

        return false
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: NetMonitorMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            Logger.app.warning("Could not create persistent ModelContainer: \(error)")
            Logger.app.warning("Falling back to in-memory storage")

            do {
                let inMemoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let monitoringSession, let deviceDiscovery {
                    ContentView()
                        .environment(monitoringSession)
                        .environment(deviceDiscovery)
                } else {
                    ProgressView("Starting NetMonitor…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task {
                await setupServices()
            }
            .tint(Color(hex: accentColorHex))
            .environment(\.appAccentColor, Color(hex: accentColorHex))
            .environment(\.compactMode, compactMode)
            .captureOpenWindow()
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
                .tint(Color(hex: accentColorHex))
                .environment(\.appAccentColor, Color(hex: accentColorHex))
                .environment(\.compactMode, compactMode)
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func setupServices() async {
        let context = sharedModelContainer.mainContext

        if isUITesting {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            UserDefaults.standard.set(false, forKey: "autoStartMonitoring")
        }

        if isUITesting {
            // Minimal setup for UI tests
            let coordinator = DeviceDiscoveryCoordinator(
                modelContext: context,
                arpScanner: ARPScannerService(),
                bonjourScanner: BonjourDiscoveryService()
            )
            deviceDiscovery = coordinator

            monitoringSession = MonitoringSession(
                modelContext: context,
                coordinator: coordinator,
                httpService: HTTPMonitorService(),
                icmpService: ICMPMonitorService(),
                tcpService: TCPMonitorService()
            )
            return
        }

        // CRITICAL: Seed default targets FIRST
        await DefaultTargetsProvider.seedIfNeeded(modelContext: context)

        // Create services
        let httpService = HTTPMonitorService()
        let icmpService = ICMPMonitorService()
        let tcpService = TCPMonitorService()
        let arpScanner = ARPScannerService()
        let bonjourScanner = BonjourDiscoveryService()
        let wakeOnLanService = WakeOnLanService()

        // 1. Set up device discovery coordinator (created first so session can reference it)
        if deviceDiscovery == nil {
            deviceDiscovery = DeviceDiscoveryCoordinator(
                modelContext: context,
                arpScanner: arpScanner,
                bonjourScanner: bonjourScanner
            )
        }

        // 2. Set up monitoring session, injecting the coordinator
        if monitoringSession == nil {
            monitoringSession = MonitoringSession(
                modelContext: context,
                coordinator: deviceDiscovery,
                httpService: httpService,
                icmpService: icmpService,
                tcpService: tcpService
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

            let handler = companionHandler
            do {
                try await companionService?.start { @Sendable message, clientID in
                    return await handler?.handle(message, from: clientID)
                }
            } catch {
                Logger.app.error("Failed to start companion service: \(error)")
            }
        }

        // 4. Set up menu bar (needs both session and coordinator)
        if let session = monitoringSession, let discovery = deviceDiscovery, menuBarController == nil {
            menuBarController = MenuBarController(
                monitoringSession: session,
                deviceDiscovery: discovery
            )
            menuBarController?.setup()
        }

        // 5. Set up notification service
        if notificationService == nil {
            notificationService = NotificationService()
            if !isUITesting {
                Task {
                    _ = await notificationService?.requestAuthorization()
                }
            }
        }

        // 6. Auto-start monitoring (now means: start network scanning)
        if autoStartMonitoring && !shouldDisableMonitoring,
           let session = monitoringSession, !session.isMonitoring {
            session.startMonitoring()
        }
    }
}
