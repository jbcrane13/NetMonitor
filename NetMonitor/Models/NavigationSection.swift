import Foundation

enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case targets = "Targets"
    case devices = "Devices"
    case tools = "Tools"
    case settings = "Settings"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .targets: return "target"
        case .devices: return "network"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}
