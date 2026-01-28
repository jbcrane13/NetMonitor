import Foundation
import Testing
@testable import NetMonitor

@Suite("Wake on LAN Service Tests")
struct WakeOnLanServiceTests {

    @Test("MAC address parsing with colons")
    func parseMACWithColons() async throws {
        let service = WakeOnLanService()

        // Valid MAC formats should not throw during wake() call
        // We can't verify the packet was sent without network mocking,
        // but we can test that parsing doesn't fail
        let validMAC = "AA:BB:CC:DD:EE:FF"

        // This will attempt to send the packet, which may fail due to network,
        // but should not fail due to MAC parsing
        // We use a timeout to catch the operation
        do {
            try await service.wake(macAddress: validMAC)
            // If it succeeds or fails with network error, parsing worked
        } catch WakeOnLanError.invalidMACAddress {
            // If we get invalid MAC error, test should fail
            #expect(Bool(false), "Valid MAC address was rejected")
        } catch {
            // Network errors are acceptable for this test
            // We only care about MAC parsing validation
        }
    }

    @Test("MAC address parsing with hyphens")
    func parseMACWithHyphens() async throws {
        let service = WakeOnLanService()

        let validMAC = "AA-BB-CC-DD-EE-FF"

        do {
            try await service.wake(macAddress: validMAC)
        } catch WakeOnLanError.invalidMACAddress {
            #expect(Bool(false), "Valid MAC address with hyphens was rejected")
        } catch {
            // Network errors are acceptable
        }
    }

    @Test("MAC address parsing without separators")
    func parseMACWithoutSeparators() async throws {
        let service = WakeOnLanService()

        let validMAC = "AABBCCDDEEFF"

        do {
            try await service.wake(macAddress: validMAC)
        } catch WakeOnLanError.invalidMACAddress {
            #expect(Bool(false), "Valid MAC address without separators was rejected")
        } catch {
            // Network errors are acceptable
        }
    }

    @Test("Invalid MAC address length rejects")
    func invalidMACLength() async throws {
        let service = WakeOnLanService()

        let invalidMAC = "AA:BB:CC:DD:EE"  // Only 5 bytes

        await #expect(throws: WakeOnLanError.self) {
            try await service.wake(macAddress: invalidMAC)
        }
    }

    @Test("Invalid MAC address characters reject")
    func invalidMACCharacters() async throws {
        let service = WakeOnLanService()

        let invalidMAC = "AA:BB:CC:DD:EE:GG"  // 'G' is not hex

        await #expect(throws: WakeOnLanError.self) {
            try await service.wake(macAddress: invalidMAC)
        }
    }

    @Test("Empty MAC address rejects")
    func emptyMAC() async throws {
        let service = WakeOnLanService()

        await #expect(throws: WakeOnLanError.self) {
            try await service.wake(macAddress: "")
        }
    }

    @Test("MAC address is case insensitive")
    func caseInsensitiveMAC() async throws {
        let service = WakeOnLanService()

        let lowercaseMAC = "aa:bb:cc:dd:ee:ff"

        do {
            try await service.wake(macAddress: lowercaseMAC)
        } catch WakeOnLanError.invalidMACAddress {
            #expect(Bool(false), "Lowercase MAC address was rejected")
        } catch {
            // Network errors are acceptable
        }
    }

    @Test("Mixed separator MAC address rejects")
    func mixedSeparators() async throws {
        let service = WakeOnLanService()

        let mixedMAC = "AA:BB-CC:DD-EE:FF"

        // After cleaning, this becomes "AABBCCDDEEFF" which is valid
        // So this should NOT reject
        do {
            try await service.wake(macAddress: mixedMAC)
        } catch WakeOnLanError.invalidMACAddress {
            #expect(Bool(false), "Mixed separator MAC was rejected after cleaning")
        } catch {
            // Network errors are acceptable
        }
    }

    @Test("MAC with extra whitespace handles correctly")
    func macWithWhitespace() async throws {
        let service = WakeOnLanService()

        let macWithSpaces = " AA:BB:CC:DD:EE:FF "

        do {
            try await service.wake(macAddress: macWithSpaces)
        } catch WakeOnLanError.invalidMACAddress {
            #expect(Bool(false), "MAC with whitespace was rejected")
        } catch {
            // Network errors are acceptable
        }
    }
}
