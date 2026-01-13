//
//  CompanionMessageTests.swift
//  NetMonitorTests
//
//  Created on 2026-01-13.
//

import Foundation
import Testing
@testable import NetMonitorShared

@Suite("CompanionMessage Protocol Tests")
struct CompanionMessageTests {

    @Test("Encode status update message")
    func encodeStatusUpdate() throws {
        let message = CompanionMessage.statusUpdate(StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 45.5
        ))

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .statusUpdate(let payload) = decoded {
            #expect(payload.isMonitoring == true)
            #expect(payload.onlineTargets == 5)
            #expect(payload.offlineTargets == 2)
            #expect(payload.averageLatency == 45.5)
        } else {
            Issue.record("Expected statusUpdate message type")
        }
    }

    @Test("Encode command message")
    func encodeCommand() throws {
        let message = CompanionMessage.command(CommandPayload(
            action: .startMonitoring,
            parameters: nil
        ))

        let data = try JSONEncoder().encode(message)
        let json = String(data: data, encoding: .utf8)

        #expect(json?.contains("startMonitoring") == true)
    }

    @Test("Decode device list message")
    func decodeDeviceList() throws {
        let json = """
        {
            "type": "deviceList",
            "payload": {
                "devices": [
                    {
                        "id": "12345678-1234-1234-1234-123456789ABC",
                        "ipAddress": "192.168.1.100",
                        "macAddress": "AA:BB:CC:DD:EE:FF",
                        "hostname": "test.local",
                        "deviceType": "unknown",
                        "isOnline": true
                    }
                ]
            }
        }
        """

        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .deviceList(let payload) = message {
            #expect(payload.devices.count == 1)
            #expect(payload.devices[0].ipAddress == "192.168.1.100")
        } else {
            Issue.record("Expected deviceList message type")
        }
    }

    @Test("Encode heartbeat message")
    func encodeHeartbeat() throws {
        let message = CompanionMessage.heartbeat(HeartbeatPayload(version: "1.0"))

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .heartbeat(let payload) = decoded {
            #expect(payload.version == "1.0")
        } else {
            Issue.record("Expected heartbeat message type")
        }
    }

    @Test("Encode error message")
    func encodeError() throws {
        let message = CompanionMessage.error(ErrorPayload(
            code: "E001",
            message: "Connection failed"
        ))

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .error(let payload) = decoded {
            #expect(payload.code == "E001")
            #expect(payload.message == "Connection failed")
        } else {
            Issue.record("Expected error message type")
        }
    }

    @Test("Encode tool result message")
    func encodeToolResult() throws {
        let message = CompanionMessage.toolResult(ToolResultPayload(
            tool: "ping",
            success: true,
            result: "64 bytes from 8.8.8.8: icmp_seq=1 ttl=119 time=12.5 ms"
        ))

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .toolResult(let payload) = decoded {
            #expect(payload.tool == "ping")
            #expect(payload.success == true)
        } else {
            Issue.record("Expected toolResult message type")
        }
    }

    @Test("Encode target list message")
    func encodeTargetList() throws {
        let target = TargetInfo(
            id: UUID(),
            name: "Test Target",
            host: "example.com",
            port: 443,
            protocol: "https",
            isEnabled: true,
            isReachable: true,
            latency: 25.5
        )

        let message = CompanionMessage.targetList(TargetListPayload(targets: [target]))

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

        if case .targetList(let payload) = decoded {
            #expect(payload.targets.count == 1)
            #expect(payload.targets[0].name == "Test Target")
            #expect(payload.targets[0].host == "example.com")
        } else {
            Issue.record("Expected targetList message type")
        }
    }
}
