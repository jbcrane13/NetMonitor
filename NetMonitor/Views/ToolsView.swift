//
//  ToolsView.swift
//  NetMonitor
//
//  Grid launcher for network diagnostic tools.
//

import SwiftUI

/// Available network tools
enum NetworkTool: String, CaseIterable, Identifiable {
    case ping = "Ping"
    case traceroute = "Traceroute"
    case portScanner = "Port Scanner"
    case dnsLookup = "DNS Lookup"
    case whois = "WHOIS"
    case speedTest = "Speed Test"
    case bonjourBrowser = "Bonjour Browser"
    case wakeOnLan = "Wake on LAN"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .ping: return "waveform.path"
        case .traceroute: return "point.topleft.down.to.point.bottomright.curvepath"
        case .portScanner: return "network"
        case .dnsLookup: return "magnifyingglass"
        case .whois: return "doc.text.magnifyingglass"
        case .speedTest: return "speedometer"
        case .bonjourBrowser: return "bonjour"
        case .wakeOnLan: return "wake"
        }
    }

    var description: String {
        switch self {
        case .ping: return "Test host reachability"
        case .traceroute: return "Trace network path"
        case .portScanner: return "Scan open ports"
        case .dnsLookup: return "Query DNS records"
        case .whois: return "Domain information"
        case .speedTest: return "Measure connection speed"
        case .bonjourBrowser: return "Discover local services"
        case .wakeOnLan: return "Wake network devices"
        }
    }

    var isComplex: Bool {
        switch self {
        case .portScanner, .speedTest, .bonjourBrowser:
            return true
        default:
            return false
        }
    }
}

struct ToolsView: View {
    @State private var selectedTool: NetworkTool?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(NetworkTool.allCases) { tool in
                    ToolCard(tool: tool)
                        .onTapGesture {
                            selectedTool = tool
                        }
                        .accessibilityIdentifier("tools_card_\(tool.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                }
            }
            .padding()
        }
        .navigationTitle("Network Tools")
        .sheet(item: $selectedTool) { tool in
            toolSheet(for: tool)
        }
    }

    @ViewBuilder
    private func toolSheet(for tool: NetworkTool) -> some View {
        switch tool {
        case .ping:
            PingToolView()
                .frame(minWidth: 500, minHeight: 400)
        case .traceroute:
            TracerouteToolView()
                .frame(minWidth: 500, minHeight: 400)
        case .portScanner:
            PortScannerToolView()
                .frame(minWidth: 600, minHeight: 500)
        case .dnsLookup:
            DNSLookupToolView()
                .frame(minWidth: 500, minHeight: 400)
        case .whois:
            WHOISToolView()
                .frame(minWidth: 500, minHeight: 400)
        case .speedTest:
            SpeedTestToolView()
                .frame(minWidth: 600, minHeight: 500)
        case .bonjourBrowser:
            BonjourBrowserToolView()
                .frame(minWidth: 600, minHeight: 500)
        case .wakeOnLan:
            WakeOnLanToolView()
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: NetworkTool
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: tool.iconName)
                .font(.system(size: 28))
                .foregroundStyle(.cyan)
                .frame(height: 32)

            Text(tool.rawValue)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(tool.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 100)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovering ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    ToolsView()
}
