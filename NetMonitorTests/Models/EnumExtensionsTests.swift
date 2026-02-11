import Testing
@testable import NetMonitor
import NetMonitorShared

@Suite("TargetProtocol Icon Extension Tests")
struct TargetProtocolIconTests {

    @Test("HTTP returns network icon")
    func httpIcon() {
        #expect(TargetProtocol.http.iconName == "network")
    }

    @Test("HTTPS returns network icon")
    func httpsIcon() {
        #expect(TargetProtocol.https.iconName == "network")
    }

    @Test("ICMP returns waveform icon")
    func icmpIcon() {
        #expect(TargetProtocol.icmp.iconName == "waveform.path.ecg")
    }

    @Test("TCP returns bidirectional arrow icon")
    func tcpIcon() {
        #expect(TargetProtocol.tcp.iconName == "arrow.left.arrow.right")
    }

    @Test("all protocol icons are non-empty")
    func allProtocolIconsNonEmpty() {
        for proto in TargetProtocol.allCases {
            #expect(!proto.iconName.isEmpty)
        }
    }

    @Test("HTTP and HTTPS share same icon")
    func httpProtocolsShareIcon() {
        #expect(TargetProtocol.http.iconName == TargetProtocol.https.iconName)
    }
}

@Suite("DeviceType Icon Extension Tests")
struct DeviceTypeIconTests {

    @Test("phone returns iphone icon")
    func phoneIcon() {
        #expect(DeviceType.phone.iconName == "iphone")
    }

    @Test("laptop returns laptopcomputer icon")
    func laptopIcon() {
        #expect(DeviceType.laptop.iconName == "laptopcomputer")
    }

    @Test("tablet returns ipad icon")
    func tabletIcon() {
        #expect(DeviceType.tablet.iconName == "ipad")
    }

    @Test("tv returns tv icon")
    func tvIcon() {
        #expect(DeviceType.tv.iconName == "tv")
    }

    @Test("speaker returns homepod icon")
    func speakerIcon() {
        #expect(DeviceType.speaker.iconName == "homepod")
    }

    @Test("gaming returns gamecontroller icon")
    func gamingIcon() {
        #expect(DeviceType.gaming.iconName == "gamecontroller")
    }

    @Test("iot returns sensor icon")
    func iotIcon() {
        #expect(DeviceType.iot.iconName == "sensor")
    }

    @Test("router returns wifi.router icon")
    func routerIcon() {
        #expect(DeviceType.router.iconName == "wifi.router")
    }

    @Test("printer returns printer icon")
    func printerIcon() {
        #expect(DeviceType.printer.iconName == "printer")
    }

    @Test("unknown returns questionmark.circle icon")
    func unknownIcon() {
        #expect(DeviceType.unknown.iconName == "questionmark.circle")
    }

    @Test("all device type icons are non-empty")
    func allDeviceIconsNonEmpty() {
        for deviceType in DeviceType.allCases {
            #expect(!deviceType.iconName.isEmpty)
        }
    }

    @Test("each device type has unique icon")
    func deviceTypesHaveUniqueIcons() {
        let icons = DeviceType.allCases.map { $0.iconName }
        let uniqueIcons = Set(icons)
        #expect(icons.count == uniqueIcons.count)
    }
}
