import Testing
@testable import NetMonitor

@Suite("NavigationSection Tests")
struct NavigationSectionTests {

    @Test("allCases contains all five sections")
    func allCases() {
        let cases = NavigationSection.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.dashboard))
        #expect(cases.contains(.targets))
        #expect(cases.contains(.devices))
        #expect(cases.contains(.tools))
        #expect(cases.contains(.settings))
    }

    @Test("rawValue returns correct string for each section")
    func rawValues() {
        #expect(NavigationSection.dashboard.rawValue == "Dashboard")
        #expect(NavigationSection.targets.rawValue == "Targets")
        #expect(NavigationSection.devices.rawValue == "Devices")
        #expect(NavigationSection.tools.rawValue == "Tools")
        #expect(NavigationSection.settings.rawValue == "Settings")
    }

    @Test("id returns rawValue for each section")
    func idProperty() {
        #expect(NavigationSection.dashboard.id == "Dashboard")
        #expect(NavigationSection.targets.id == "Targets")
        #expect(NavigationSection.devices.id == "Devices")
        #expect(NavigationSection.tools.id == "Tools")
        #expect(NavigationSection.settings.id == "Settings")
    }

    @Test("iconName returns correct SF Symbol for dashboard")
    func dashboardIcon() {
        #expect(NavigationSection.dashboard.iconName == "chart.line.uptrend.xyaxis")
    }

    @Test("iconName returns correct SF Symbol for targets")
    func targetsIcon() {
        #expect(NavigationSection.targets.iconName == "target")
    }

    @Test("iconName returns correct SF Symbol for devices")
    func devicesIcon() {
        #expect(NavigationSection.devices.iconName == "network")
    }

    @Test("iconName returns correct SF Symbol for tools")
    func toolsIcon() {
        #expect(NavigationSection.tools.iconName == "wrench.and.screwdriver")
    }

    @Test("iconName returns correct SF Symbol for settings")
    func settingsIcon() {
        #expect(NavigationSection.settings.iconName == "gearshape")
    }

    @Test("all icon names are non-empty")
    func allIconsNonEmpty() {
        for section in NavigationSection.allCases {
            #expect(!section.iconName.isEmpty)
        }
    }

    @Test("NavigationSection conforms to Identifiable")
    func identifiableConformance() {
        let section: any Identifiable = NavigationSection.dashboard
        #expect(section.id as? String == "Dashboard")
    }

    @Test("NavigationSection can be initialized from rawValue")
    func rawValueInitialization() {
        #expect(NavigationSection(rawValue: "Dashboard") == .dashboard)
        #expect(NavigationSection(rawValue: "Targets") == .targets)
        #expect(NavigationSection(rawValue: "Devices") == .devices)
        #expect(NavigationSection(rawValue: "Tools") == .tools)
        #expect(NavigationSection(rawValue: "Settings") == .settings)
        #expect(NavigationSection(rawValue: "Invalid") == nil)
    }
}
