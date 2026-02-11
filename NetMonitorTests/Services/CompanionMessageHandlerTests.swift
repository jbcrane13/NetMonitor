import Foundation
import Testing
import SwiftData
import NetMonitorShared
@testable import NetMonitor

@Suite("Companion Message Handler Tests", .serialized)
struct CompanionMessageHandlerTests {

    // MARK: - Test Infrastructure

    @MainActor
    private func createTestEnvironment() throws -> (
        handler: CompanionMessageHandler,
        container: ModelContainer,
        session: MonitoringSession,
        discovery: DeviceDiscoveryCoordinator
    ) {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let httpService = HTTPMonitorService()
        let icmpService = ICMPMonitorService()
        let tcpService = TCPMonitorService()

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: httpService,
            icmpService: icmpService,
            tcpService: tcpService
        )

        let arpScanner = ARPScannerService()
        let bonjourScanner = BonjourDiscoveryService()

        let discovery = DeviceDiscoveryCoordinator(
            modelContext: container.mainContext,
            arpScanner: arpScanner,
            bonjourScanner: bonjourScanner
        )

        let wakeOnLan = WakeOnLanService()

        let handler = CompanionMessageHandler(
            modelContext: container.mainContext,
            monitoringSession: session,
            deviceDiscovery: discovery,
            wakeOnLanService: wakeOnLan,
            icmpService: icmpService
        )

        return (handler, container, session, discovery)
    }

    // MARK: - Command Handling Tests

    @Test("Handler processes startMonitoring command")
    @MainActor
    func handleStartMonitoring() async throws {
        let (handler, container, session, _) = try createTestEnvironment()

        // Insert a target so startMonitoring() proceeds past the empty-targets check
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)
        try container.mainContext.save()

        let command = CompanionMessage.command(
            CommandPayload(action: .startMonitoring, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        #expect(session.isMonitoring == true)

        if case .statusUpdate(let payload) = response {
            #expect(payload.isMonitoring == true)
        } else {
            Issue.record("Expected statusUpdate response")
        }
    }

    @Test("Handler processes stopMonitoring command")
    @MainActor
    func handleStopMonitoring() async throws {
        let (handler, container, session, _) = try createTestEnvironment()

        // Insert a target so startMonitoring() proceeds past the empty-targets check
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)
        try container.mainContext.save()

        // Start monitoring first
        session.startMonitoring()
        #expect(session.isMonitoring == true)

        let command = CompanionMessage.command(
            CommandPayload(action: .stopMonitoring, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        #expect(session.isMonitoring == false)

        if case .statusUpdate(let payload) = response {
            #expect(payload.isMonitoring == false)
        } else {
            Issue.record("Expected statusUpdate response")
        }
    }

    @Test("Handler processes scanDevices command")
    @MainActor
    func handleScanDevices() async throws {
        let (handler, _, _, discovery) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .scanDevices, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        #expect(discovery.isScanning == true)

        if case .toolResult(let payload) = response {
            #expect(payload.tool == "deviceScan")
            #expect(payload.success == true)
            #expect(payload.result == "Scan started")
        } else {
            Issue.record("Expected toolResult response")
        }
    }

    @Test("Handler processes refreshTargets command")
    @MainActor
    func handleRefreshTargets() async throws {
        let (handler, container, _, _) = try createTestEnvironment()

        // Create test targets
        let target1 = NetworkTarget(
            name: "Test Server",
            host: "192.168.1.100",
            port: 80,
            targetProtocol: .http
        )
        let target2 = NetworkTarget(
            name: "DNS Server",
            host: "8.8.8.8",
            port: nil,
            targetProtocol: .icmp
        )

        container.mainContext.insert(target1)
        container.mainContext.insert(target2)
        try container.mainContext.save()

        let command = CompanionMessage.command(
            CommandPayload(action: .refreshTargets, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        if case .targetList(let payload) = response {
            #expect(payload.targets.count == 2)
            #expect(payload.targets.contains { $0.name == "Test Server" })
            #expect(payload.targets.contains { $0.name == "DNS Server" })
        } else {
            Issue.record("Expected targetList response")
        }
    }

    @Test("Handler processes refreshDevices command")
    @MainActor
    func handleRefreshDevices() async throws {
        let (handler, _, _, discovery) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .refreshDevices, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        if case .deviceList(let payload) = response {
            #expect(payload.devices.count == discovery.discoveredDevices.count)
        } else {
            Issue.record("Expected deviceList response")
        }
    }

    @Test("Handler processes ping command with valid host")
    @MainActor
    func handlePingCommand() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .ping, parameters: ["host": "127.0.0.1"])
        )

        let response = await handler.handle(command, from: UUID())

        if case .toolResult(let payload) = response {
            #expect(payload.tool == "ping")
            // localhost should succeed
            #expect(payload.success == true)
            #expect(payload.result.contains("Reply from"))
        } else {
            Issue.record("Expected toolResult response")
        }
    }

    @Test("Handler rejects ping command without host parameter")
    @MainActor
    func handlePingWithoutHost() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .ping, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        if case .error(let payload) = response {
            #expect(payload.code == "MISSING_PARAMETER")
            #expect(payload.message.contains("host"))
        } else {
            Issue.record("Expected error response")
        }
    }

    @Test("Handler processes wakeOnLan command with valid MAC")
    @MainActor
    func handleWakeOnLan() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .wakeOnLan, parameters: ["mac": "AA:BB:CC:DD:EE:FF"])
        )

        let response = await handler.handle(command, from: UUID())

        if case .toolResult(let payload) = response {
            #expect(payload.tool == "wakeOnLan")
            #expect(payload.success == true)
            #expect(payload.result.contains("Magic packet sent"))
        } else {
            Issue.record("Expected toolResult response")
        }
    }

    @Test("Handler rejects wakeOnLan command without MAC parameter")
    @MainActor
    func handleWakeOnLanWithoutMAC() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .wakeOnLan, parameters: nil)
        )

        let response = await handler.handle(command, from: UUID())

        if case .error(let payload) = response {
            #expect(payload.code == "MISSING_PARAMETER")
            #expect(payload.message.contains("mac"))
        } else {
            Issue.record("Expected error response")
        }
    }

    @Test("Handler returns error for unsupported command")
    @MainActor
    func handleUnsupportedCommand() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let command = CompanionMessage.command(
            CommandPayload(action: .traceroute, parameters: ["host": "8.8.8.8"])
        )

        let response = await handler.handle(command, from: UUID())

        if case .error(let payload) = response {
            #expect(payload.code == "UNSUPPORTED_COMMAND")
            #expect(payload.message.contains("traceroute"))
        } else {
            Issue.record("Expected error response")
        }
    }

    @Test("Handler responds to heartbeat")
    @MainActor
    func handleHeartbeat() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let heartbeat = CompanionMessage.heartbeat(HeartbeatPayload())

        let response = await handler.handle(heartbeat, from: UUID())

        if case .heartbeat = response {
            // Success
        } else {
            Issue.record("Expected heartbeat response")
        }
    }

    @Test("Handler ignores non-command messages")
    @MainActor
    func handleNonCommandMessage() async throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let statusUpdate = CompanionMessage.statusUpdate(
            StatusUpdatePayload(
                isMonitoring: false,
                onlineTargets: 0,
                offlineTargets: 0,
                averageLatency: nil
            )
        )

        let response = await handler.handle(statusUpdate, from: UUID())

        #expect(response == nil)
    }

    // MARK: - Status Generation Tests

    @Test("Handler generates status update with no targets")
    @MainActor
    func generateStatusUpdateEmpty() throws {
        let (handler, _, session, _) = try createTestEnvironment()

        let message = handler.generateStatusUpdate()

        if case .statusUpdate(let payload) = message {
            #expect(payload.isMonitoring == session.isMonitoring)
            #expect(payload.onlineTargets == 0)
            #expect(payload.offlineTargets == 0)
            #expect(payload.averageLatency == nil)
        } else {
            Issue.record("Expected statusUpdate message")
        }
    }

    @Test("Handler generates target list")
    @MainActor
    func generateTargetList() throws {
        let (handler, container, _, _) = try createTestEnvironment()

        // Create test targets
        let target = NetworkTarget(
            name: "Web Server",
            host: "example.com",
            port: 443,
            targetProtocol: .https
        )

        container.mainContext.insert(target)
        try container.mainContext.save()

        let message = handler.generateTargetList()

        if case .targetList(let payload) = message {
            #expect(payload.targets.count == 1)
            #expect(payload.targets.first?.name == "Web Server")
            #expect(payload.targets.first?.host == "example.com")
            #expect(payload.targets.first?.port == 443)
            #expect(payload.targets.first?.protocol == "HTTPS")
        } else {
            Issue.record("Expected targetList message")
        }
    }

    @Test("Handler generates device list")
    @MainActor
    func generateDeviceList() throws {
        let (handler, _, _, _) = try createTestEnvironment()

        let message = handler.generateDeviceList()

        if case .deviceList(let payload) = message {
            #expect(payload.devices.count >= 0)
        } else {
            Issue.record("Expected deviceList message")
        }
    }
}
