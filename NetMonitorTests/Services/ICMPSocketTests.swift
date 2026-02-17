//
//  ICMPSocketTests.swift
//  NetMonitorTests
//
//  Tests for ICMPSocket static utility methods: checksum, packet construction,
//  and response parsing. No network I/O — all pure unit tests.
//

import Testing
@testable import NetMonitor

// MARK: - Checksum Tests

@Suite("ICMPSocket — Checksum Tests")
struct ICMPSocketChecksumTests {

    @Test("Checksum of all-zero bytes produces 0xFFFF")
    func checksumAllZeros() {
        let data: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFFFF)
    }

    @Test("Checksum of all 0xFF words produces 0x0000")
    func checksumAllOnes() {
        let data: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0x0000)
    }

    @Test("Checksum handles odd-length data (trailing byte padded)")
    func checksumOddLength() {
        // 3 bytes: [0x01, 0x02, 0x03]
        // Sum: 0x0102 + 0x0300 = 0x0402
        // Complement: ~0x0402 = 0xFBFD
        let data: [UInt8] = [0x01, 0x02, 0x03]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFBFD)
    }

    @Test("Checksum is self-verifying — recompute over packet with checksum yields 0")
    func checksumSelfVerifying() {
        var packet: [UInt8] = [8, 0, 0, 0, 0, 1, 0, 1] // Echo request, id=1, seq=1
        let checksum = ICMPSocket.icmpChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)

        let verify = ICMPSocket.icmpChecksum(packet)
        #expect(verify == 0)
    }

    @Test("Checksum matches known ICMP echo request vector")
    func checksumKnownVector() {
        var packet: [UInt8] = [
            8, 0, 0, 0,             // type=8, code=0, checksum placeholder
            0x12, 0x34,              // identifier
            0x00, 0x01,              // sequence
            0, 0, 0, 0, 0, 0, 0, 0  // 8-byte payload
        ]
        let checksum = ICMPSocket.icmpChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)
        // Complete packet with checksum must verify to 0
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    @Test("Checksum handles 32-bit carry folding correctly")
    func checksumCarryFolding() {
        // 0xFFFE + 0x0003 = 0x10001 → fold → 0x0002 → complement → 0xFFFD
        let data: [UInt8] = [0xFF, 0xFE, 0x00, 0x03]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFFFD)
    }

    @Test("Checksum of single zero byte")
    func checksumSingleByte() {
        let data: [UInt8] = [0x00]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFFFF)
    }

    @Test("Checksum of single 0xFF byte")
    func checksumSingleNonZeroByte() {
        let data: [UInt8] = [0xFF]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0x00FF)
    }
}

// MARK: - Packet Construction Tests

@Suite("ICMPSocket — Packet Construction Tests")
struct ICMPSocketPacketTests {

    @Test("buildEchoRequest produces correct header structure")
    func buildEchoRequestHeader() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 42, payloadSize: 0, identifier: 0xABCD)

        #expect(packet.count == 8) // 8-byte header, no payload
        #expect(packet[0] == 8)    // ICMP type: Echo Request
        #expect(packet[1] == 0)    // Code: 0
        // Identifier (big-endian)
        #expect(packet[4] == 0xAB)
        #expect(packet[5] == 0xCD)
        // Sequence 42 (big-endian)
        #expect(packet[6] == 0x00)
        #expect(packet[7] == 42)
    }

    @Test("buildEchoRequest includes repeating payload pattern")
    func buildEchoRequestPayload() {
        let payloadSize = 16
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: payloadSize)

        #expect(packet.count == 8 + payloadSize)
        for i in 0..<payloadSize {
            #expect(packet[8 + i] == UInt8(i & 0xFF))
        }
    }

    @Test("buildEchoRequest embeds valid checksum")
    func buildEchoRequestChecksum() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 56)
        // Re-verifying checksum over a complete packet must yield 0
        let verify = ICMPSocket.icmpChecksum(packet)
        #expect(verify == 0)
    }

    @Test("buildEchoRequest standard 64-byte ping packet")
    func buildStandardPingPacket() {
        // Canonical ping: 8-byte ICMP header + 56-byte payload = 64 bytes
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 56)
        #expect(packet.count == 64)
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    @Test("buildEchoRequest with sequence number 0")
    func buildEchoRequestZeroSequence() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 0, payloadSize: 8)
        #expect(packet[6] == 0x00)
        #expect(packet[7] == 0x00)
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    @Test("buildEchoRequest with max sequence number 0xFFFF")
    func buildEchoRequestMaxSequence() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 0xFFFF, payloadSize: 0)
        #expect(packet[6] == 0xFF)
        #expect(packet[7] == 0xFF)
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    @Test("buildEchoRequest produces consistent checksums across calls")
    func buildEchoRequestReproducible() {
        let p1 = ICMPSocket.buildEchoRequest(sequence: 7, payloadSize: 32)
        let p2 = ICMPSocket.buildEchoRequest(sequence: 7, payloadSize: 32)
        #expect(p1 == p2)
    }

    @Test("buildEchoRequest different sequences produce different checksums")
    func buildEchoRequestUniquePerSequence() {
        let p1 = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 8)
        let p2 = ICMPSocket.buildEchoRequest(sequence: 2, payloadSize: 8)
        // Packets differ at sequence byte and checksum byte
        #expect(p1 != p2)
    }
}

// MARK: - Response Parsing Tests

@Suite("ICMPSocket — Response Parsing Tests")
struct ICMPSocketParseTests {

    @Test("parseResponse handles ICMP echo reply (no IP header)")
    func parseEchoReply() {
        // Bare ICMP packet (no IP header): type=0 (echo reply), seq=5
        let buffer: [UInt8] = [
            0, 0,       // type=0 (echo reply), code=0
            0x00, 0x00, // checksum
            0x00, 0x01, // identifier
            0x00, 0x05, // sequence = 5
        ]

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "8.8.8.8", rtt: 15.5)

        if case .echoReply(let seq) = response.kind {
            #expect(seq == 5)
        } else {
            Issue.record("Expected echoReply, got \(response.kind)")
        }
        #expect(response.sourceIP == "8.8.8.8")
        #expect(response.rtt == 15.5)
    }

    @Test("parseResponse handles ICMP echo reply with IPv4 header")
    func parseEchoReplyWithIPHeader() {
        // 20-byte IPv4 header (IHL=5) + 8-byte ICMP echo reply
        var buffer = [UInt8](repeating: 0, count: 28)
        buffer[0] = 0x45 // IPv4, IHL=5 (20 bytes)
        // Skip IP header fields (offset 1-19)
        buffer[20] = 0   // ICMP type: Echo Reply
        buffer[21] = 0   // code
        buffer[22] = 0; buffer[23] = 0 // checksum
        buffer[24] = 0; buffer[25] = 1 // identifier
        buffer[26] = 0; buffer[27] = 7 // sequence = 7

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "1.1.1.1", rtt: 12.0)

        if case .echoReply(let seq) = response.kind {
            #expect(seq == 7)
        } else {
            Issue.record("Expected echoReply with IPv4 header, got \(response.kind)")
        }
    }

    @Test("parseResponse handles ICMP time exceeded (no IP header)")
    func parseTimeExceeded() {
        // ICMP Time Exceeded structure:
        // [0-7]   Time Exceeded header: type=11, code=0, checksum, unused
        // [8-27]  Original IP header (20 bytes) — all zeros for test
        // [28-35] First 8 bytes of original ICMP: type=8, code=0, cksum, id, seq
        var buffer = [UInt8](repeating: 0, count: 36)
        buffer[0] = 11  // type = Time Exceeded
        buffer[1] = 0   // code = TTL exceeded in transit
        // Original ICMP at offset 28
        buffer[28] = 8  // original type = Echo Request
        buffer[34] = 0x00
        buffer[35] = 0x03 // original sequence = 3

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "10.0.0.1", rtt: 5.2)

        if case .timeExceeded(let routerIP, let origSeq) = response.kind {
            #expect(routerIP == "10.0.0.1")
            #expect(origSeq == 3)
        } else {
            Issue.record("Expected timeExceeded, got \(response.kind)")
        }
        #expect(response.rtt == 5.2)
    }

    @Test("parseResponse truncated time exceeded yields sequence 0")
    func parseTimeExceededTruncated() {
        var buffer = [UInt8](repeating: 0, count: 20)
        buffer[0] = 11 // type = Time Exceeded

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "10.0.0.1", rtt: 3.0)

        if case .timeExceeded(_, let origSeq) = response.kind {
            #expect(origSeq == 0)
        } else {
            Issue.record("Expected timeExceeded (truncated), got \(response.kind)")
        }
    }

    @Test("parseResponse treats unknown ICMP type as error")
    func parseUnknownType() {
        let buffer: [UInt8] = [
            3, 1,       // type=3 (Destination Unreachable), code=1
            0, 0, 0, 0, 0, 0
        ]

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "192.168.1.1", rtt: 1.0)

        if case .error = response.kind {
            // Expected
        } else {
            Issue.record("Expected error for unknown ICMP type, got \(response.kind)")
        }
    }

    @Test("parseResponse treats too-short buffer as error")
    func parseTooShort() {
        let buffer: [UInt8] = [0, 0, 0] // Only 3 bytes, need ≥ 8

        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: nil, rtt: 0)

        if case .error = response.kind {
            // Expected
        } else {
            Issue.record("Expected error for short buffer, got \(response.kind)")
        }
    }

    @Test("parseResponse preserves RTT value")
    func parsePreservesRTT() {
        let buffer: [UInt8] = [0, 0, 0, 0, 0, 1, 0, 9] // echo reply, seq=9
        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: "127.0.0.1", rtt: 42.5)
        #expect(response.rtt == 42.5)
    }

    @Test("parseResponse handles nil sourceIP")
    func parseNilSourceIP() {
        let buffer: [UInt8] = [0, 0, 0, 0, 0, 1, 0, 1]
        let response = ICMPSocket.parseResponse(buffer: buffer, sourceIP: nil, rtt: 1.0)
        #expect(response.sourceIP == nil)
    }
}

// MARK: - ICMPResponse Model Tests

@Suite("ICMPSocket — ICMPResponse Model Tests")
struct ICMPResponseModelTests {

    @Test("ICMPResponse echo reply carries correct data")
    func echoReplyData() {
        let response = ICMPResponse(
            kind: .echoReply(sequence: 42),
            sourceIP: "1.2.3.4",
            rtt: 12.5
        )

        if case .echoReply(let seq) = response.kind {
            #expect(seq == 42)
        } else {
            Issue.record("Expected echoReply")
        }
        #expect(response.sourceIP == "1.2.3.4")
        #expect(response.rtt == 12.5)
    }

    @Test("ICMPResponse time exceeded carries router IP and sequence")
    func timeExceededData() {
        let response = ICMPResponse(
            kind: .timeExceeded(routerIP: "192.168.0.1", originalSequence: 7),
            sourceIP: "192.168.0.1",
            rtt: 3.0
        )

        if case .timeExceeded(let ip, let seq) = response.kind {
            #expect(ip == "192.168.0.1")
            #expect(seq == 7)
        } else {
            Issue.record("Expected timeExceeded")
        }
    }

    @Test("ICMPResponse timeout has nil sourceIP")
    func timeoutResponse() {
        let response = ICMPResponse(
            kind: .timeout,
            sourceIP: nil,
            rtt: 2000.0
        )

        if case .timeout = response.kind { /* expected */ }
        else { Issue.record("Expected timeout") }

        #expect(response.sourceIP == nil)
        #expect(response.rtt == 2000.0)
    }

    @Test("ICMPResponse error kind")
    func errorResponse() {
        let response = ICMPResponse(kind: .error, sourceIP: nil, rtt: 0)
        if case .error = response.kind { /* expected */ }
        else { Issue.record("Expected error") }
    }
}

// MARK: - ICMPType / ICMPError Tests

@Suite("ICMPSocket — Type and Error Tests")
struct ICMPTypeTests {

    @Test("ICMPType raw values match RFC 792")
    func icmpTypeRawValues() {
        #expect(ICMPType.echoReply.rawValue == 0)
        #expect(ICMPType.echoRequest.rawValue == 8)
        #expect(ICMPType.timeExceeded.rawValue == 11)
    }

    @Test("ICMPError is expressible as Error")
    func icmpErrorIsError() {
        let e1: Error = ICMPError.socketCreationFailed
        let e2: Error = ICMPError.invalidAddress
        let e3: Error = ICMPError.sendFailed
        // Just confirming they all conform to Error — if this compiles the test passes
        #expect(e1 is ICMPError)
        #expect(e2 is ICMPError)
        #expect(e3 is ICMPError)
    }
}
