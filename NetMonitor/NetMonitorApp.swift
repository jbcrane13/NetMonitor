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

    /// Check if monitoring should be disabled (for testing)
    private var shouldDisableMonitoring: Bool {
        isUITesting || ProcessInfo.processInfo.environment["DISABLE_MONITORING"] == "1"
    }

    /// Check if running in UI test mode
    private var isUITesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        
        // Check launch arguments
        if arguments.contains("--uitesting") ||
           arguments.contains("--disable-local-auth") ||
           arguments.contains("--disable-keychain-access") {
            return true
        }
        
        // Check environment variables (used by CI/CD and test runners)
        let environment = ProcessInfo.processInfo.environment
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
           environment["XCUITest"] == "1" ||
           environment["UITEST_MODE"] == "1" ||
           environment["DISABLE_AUTHENTICATION"] == "1" ||
           environment["CI"] == "true" {
            return true
        }
        
        // Check if we're running under XCTest (unit tests or UI tests)
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
            // Fall back to in-memory container if persistent storage fails
            print("Warning: Could not create persistent ModelContainer: \(error)")
            print("Falling back to in-memory storage")

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
        WindowGroup {
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
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func setupServices() async {
        let context = sharedModelContainer.mainContext

        // Add startup delay for UI tests to avoid auth race conditions
        if isUITesting {
            // Add a small delay to let any pending system authentication complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Configure other test-specific settings
            UserDefaults.standard.set(false, forKey: "autoStartMonitoring")
        }

        // In UI testing mode, create minimal services for rendering but skip heavy setup
        if isUITesting {
            let httpService = HTTPMonitorService()
            let icmpService = ICMPMonitorService()
            let tcpService = TCPMonitorService()
            monitoringSession = MonitoringSession(
                modelContext: context,
                httpService: httpService,
                icmpService: icmpService,
                tcpService: tcpService
            )
            deviceDiscovery = DeviceDiscoveryCoordinator(
                modelContext: context,
                arpScanner: ARPScannerService(),
                bonjourScanner: BonjourDiscoveryService()
            )
            return
        }

        // CRITICAL: Seed default targets FIRST, before any services that depend on targets
        await DefaultTargetsProvider.seedIfNeeded(modelContext: context)

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
                    _ = await MainActor.run {
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

        // 5. Set up notification service and request permission (skip in UI tests)
        if notificationService == nil {
            notificationService = NotificationService()

            // Skip authorization request during UI tests to avoid auth prompts
            if !isUITesting {
                Task {
                    _ = await notificationService?.requestAuthorization()
                }
            }
        }

        // 6. Auto-start monitoring if enabled in settings (skip during testing)
        if autoStartMonitoring && !shouldDisableMonitoring,
           let session = monitoringSession, !session.isMonitoring {
            session.startMonitoring()
        }
    }
}
