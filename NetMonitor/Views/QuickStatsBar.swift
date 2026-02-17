//
//  QuickStatsBar.swift
//  NetMonitor
//

import SwiftUI

/// Displays real-time network scanning statistics in a horizontal bar
struct QuickStatsBar: View {
    @Environment(MonitoringSession.self) private var session: MonitoringSession?
    @Environment(DeviceDiscoveryCoordinator.self) private var discovery: DeviceDiscoveryCoordinator?
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.compactMode) private var compactMode

    var body: some View {
        HStack(spacing: compactMode ? 12 : 20) {
            // Online count
            StatItem(
                icon: "checkmark.circle.fill",
                color: .green,
                label: "Online",
                value: "\(onlineCount)"
            )

            Divider()
                .frame(height: 20)

            // Offline count
            StatItem(
                icon: "xmark.circle.fill",
                color: .red,
                label: "Offline",
                value: "\(offlineCount)"
            )

            Divider()
                .frame(height: 20)

            // Total devices
            StatItem(
                icon: "desktopcomputer",
                color: accentColor,
                label: "Devices",
                value: "\(totalCount)"
            )

            Divider()
                .frame(height: 20)

            // Last scan
            StatItem(
                icon: "clock.fill",
                color: .secondary,
                label: "Last Scan",
                value: lastScanString
            )
        }
        .padding(compactMode ? 8 : 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var devices: [LocalDevice] {
        discovery?.discoveredDevices ?? session?.discoveredDevices ?? []
    }

    private var onlineCount: Int {
        devices.filter { $0.isOnline }.count
    }

    private var offlineCount: Int {
        devices.filter { !$0.isOnline }.count
    }

    private var totalCount: Int {
        devices.count
    }

    private var lastScanString: String {
        let scanTime = discovery?.lastScanTime ?? session?.lastScanTime
        guard let lastScan = scanTime else {
            return "—"
        }

        let interval = Date().timeIntervalSince(lastScan)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

// MARK: - StatItem Helper View

private struct StatItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = PreviewContainer().container
    let context = container.mainContext
    let httpService = HTTPMonitorService()
    let icmpService = ICMPMonitorService()
    let tcpService = TCPMonitorService()
    let session = MonitoringSession(
        modelContext: context,
        httpService: httpService,
        icmpService: icmpService,
        tcpService: tcpService
    )

    return QuickStatsBar()
        .padding()
        .modelContainer(container)
        .environment(session)
}
#endif
