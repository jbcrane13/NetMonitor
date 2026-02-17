//
//  WHOISInfoTests.swift
//  NetMonitorTests
//
//  Tests for WHOISInfo struct and its parse(from:) method.
//  WHOISInfo is the model layer behind WHOISToolView.
//

import Testing
@testable import NetMonitor

@Suite("WHOISInfo Parsing Tests")
struct WHOISInfoParsingTests {

    // MARK: - Basic Parsing

    @Test("parse returns rawText unchanged")
    func rawTextPreserved() {
        let raw = "domain name: example.com\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.rawText == raw)
    }

    @Test("parse extracts domain name")
    func extractsDomainName() {
        let raw = "Domain Name: EXAMPLE.COM\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.domainName == "EXAMPLE.COM")
    }

    @Test("parse extracts registrar")
    func extractsRegistrar() {
        let raw = "Registrar: NameCheap, Inc.\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.registrar == "NameCheap, Inc.")
    }

    @Test("parse extracts registrar name variant")
    func extractsRegistrarName() {
        let raw = "Registrar Name: GoDaddy\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.registrar == "GoDaddy")
    }

    @Test("parse extracts creation date")
    func extractsCreationDate() {
        let raw = "Creation Date: 1995-08-14T04:00:00Z\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.creationDate == "1995-08-14T04:00:00Z")
    }

    @Test("parse extracts 'Created' date variant")
    func extractsCreatedVariant() {
        let raw = "Created: 2000-01-01\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.creationDate == "2000-01-01")
    }

    @Test("parse extracts registry expiry date")
    func extractsExpirationDate() {
        let raw = "Registry Expiry Date: 2026-08-13T04:00:00Z\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.expirationDate == "2026-08-13T04:00:00Z")
    }

    @Test("parse extracts 'Expiration Date' variant")
    func extractsExpirationDateVariant() {
        let raw = "Expiration Date: 2027-01-01\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.expirationDate == "2027-01-01")
    }

    @Test("parse extracts updated date")
    func extractsUpdatedDate() {
        let raw = "Updated Date: 2023-05-10T07:00:00Z\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.updatedDate == "2023-05-10T07:00:00Z")
    }

    @Test("parse extracts multiple name servers")
    func extractsNameServers() {
        let raw = """
        Name Server: ns1.example.com
        Name Server: ns2.example.com
        """
        let info = WHOISInfo.parse(from: raw)
        #expect(info.nameServers.count == 2)
        #expect(info.nameServers.contains("ns1.example.com"))
        #expect(info.nameServers.contains("ns2.example.com"))
    }

    @Test("parse lowercases name servers")
    func nameServersAreLowercase() {
        let raw = "Name Server: NS1.EXAMPLE.COM\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.nameServers.first == "ns1.example.com")
    }

    @Test("parse extracts domain status")
    func extractsDomainStatus() {
        let raw = "Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.status.contains("clientTransferProhibited"))
    }

    @Test("parse extracts multiple statuses")
    func extractsMultipleStatuses() {
        let raw = """
        Domain Status: clientTransferProhibited
        Domain Status: clientUpdateProhibited
        """
        let info = WHOISInfo.parse(from: raw)
        #expect(info.status.count == 2)
    }

    @Test("parse extracts registrant organization")
    func extractsRegistrantOrg() {
        let raw = "Registrant Organization: Internet Corporation\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.registrantOrg == "Internet Corporation")
    }

    @Test("parse extracts registrant country")
    func extractsRegistrantCountry() {
        let raw = "Registrant Country: US\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.registrantCountry == "US")
    }

    @Test("parse extracts DNSSEC")
    func extractsDNSSEC() {
        let raw = "DNSSEC: unsigned\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.dnssec == "unsigned")
    }

    // MARK: - Edge Cases

    @Test("parse handles empty string gracefully")
    func emptyString() {
        let info = WHOISInfo.parse(from: "")
        #expect(info.domainName == nil)
        #expect(info.registrar == nil)
        #expect(info.nameServers.isEmpty)
        #expect(info.rawText == "")
    }

    @Test("parse ignores lines without colons")
    func ignoresLinesWithoutColons() {
        let raw = """
        % This is a comment
        Some text without a colon
        Domain Name: test.com
        """
        let info = WHOISInfo.parse(from: raw)
        #expect(info.domainName == "test.com")
    }

    @Test("parse handles multi-colon values correctly")
    func multiColonValues() {
        // Values with colons (e.g. timestamps) should be preserved
        let raw = "Creation Date: 2023-01-01T00:00:00Z\n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.creationDate == "2023-01-01T00:00:00Z")
    }

    @Test("parse ignores keys with empty values")
    func ignoresEmptyValues() {
        let raw = "Registrar: \n"
        let info = WHOISInfo.parse(from: raw)
        #expect(info.registrar == nil)
    }

    @Test("parse handles real-world WHOIS snippet")
    func realWorldSnippet() {
        let raw = """
   Domain Name: GITHUB.COM
   Registry Domain ID: 1264983250_DOMAIN_COM-VRSN
   Registrar WHOIS Server: whois.markmonitor.com
   Registrar URL: http://www.markmonitor.com
   Updated Date: 2024-09-07T09:10:44Z
   Creation Date: 2007-10-09T18:20:50Z
   Registry Expiry Date: 2026-10-09T18:20:50Z
   Registrar: MarkMonitor Inc.
   Domain Status: clientUpdateProhibited
   Name Server: DNS1.P08.NSONE.NET
   Name Server: DNS2.P08.NSONE.NET
   DNSSEC: unsigned
"""
        let info = WHOISInfo.parse(from: raw)
        #expect(info.domainName == "GITHUB.COM")
        #expect(info.registrar == "MarkMonitor Inc.")
        #expect(info.creationDate == "2007-10-09T18:20:50Z")
        #expect(info.expirationDate == "2026-10-09T18:20:50Z")
        #expect(info.updatedDate == "2024-09-07T09:10:44Z")
        #expect(info.nameServers.count == 2)
        #expect(info.status.contains("clientUpdateProhibited"))
        #expect(info.dnssec == "unsigned")
    }

    // MARK: - WHOISInfo Default State

    @Test("WHOISInfo init sets only rawText by default")
    func defaultInit() {
        let info = WHOISInfo(rawText: "test")
        #expect(info.rawText == "test")
        #expect(info.domainName == nil)
        #expect(info.registrar == nil)
        #expect(info.creationDate == nil)
        #expect(info.expirationDate == nil)
        #expect(info.updatedDate == nil)
        #expect(info.nameServers.isEmpty)
        #expect(info.status.isEmpty)
        #expect(info.registrantOrg == nil)
        #expect(info.registrantCountry == nil)
        #expect(info.dnssec == nil)
    }
}
