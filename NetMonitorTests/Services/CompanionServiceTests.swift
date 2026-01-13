//
//  CompanionServiceTests.swift
//  NetMonitorTests
//
//  Created on 2026-01-13.
//

import Testing
import Network
@testable import NetMonitor

@Suite("CompanionService Tests")
struct CompanionServiceTests {

    @Test("Service initializes with correct port")
    func servicePort() async {
        let service = CompanionService()
        let port = await service.port
        #expect(port == 8849)
    }

    @Test("Service starts in stopped state")
    func initialState() async {
        let service = CompanionService()
        let isRunning = await service.isRunning
        #expect(isRunning == false)
    }

    @Test("Service type matches spec")
    func serviceType() async {
        let service = CompanionService()
        let type = await service.serviceType
        #expect(type == "_netmon._tcp")
    }
}
