//
//  QuickStatsBar.swift
//  NetMonitor
//
//  Displays real-time network-scan statistics.
//  Driven by DeviceDiscoveryCoordinator / @Query LocalDevice instead of
//  target-based TargetMeasurement results.
//

import SwiftUI
import SwiftData

/// Displays real-time scan statistics in a horizontal bar
struct QuickStatsBar: View {
    @Environment(DeviceDiscoveryCoordinator.self) private var coordinator: DeviceDiscoveryCoordinator?
    @Environment(MonitoringSession.self) private var session: MonitoringSession?
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.compactMode) private var compactMode

    @Query private var allDevices: [LocalDevice]

    var body: some View {
        HStack(spacing: compactMode ? 12 : 20) {
            // Online device count
            StatItem(
                icon: "checkmark.circle.fill",
                color: .green,
                label: "Online",
                value: "\(onlineCount)"
            )

            Divider()
                .frame(height: 20)

            // Offline device count
            StatItem(
                icon: "xmark.circle.fill",
                color: .red,
                label: "Offline",
                value: "\(offlineCount)"
            )

            Divider()
                .frame(height: 20)

            // Total device count
            StatItem(
                icon: "laptopcomputer.and.iphone",
                color: accentColor,
                label: "Devices",
                value: "\(allDevices.count)"
            )

            Divider()
                .frame(height: 20)

            // Last scan time
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

    private var onlineCount: Int {
        allDevices.filter { $0.isOnline }.count
    }

    private var offlineCount: Int {
        allDevices.filter { !$0.isOnline }.count
    }

    private var lastScanString: String {
        let scanTime = coordinator?.lastScanTime ?? session?.lastScanTime
        guard let scanTime else { return "—" }

        let interval = Date().timeIntervalSince(scanTime)
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
    let coordinator = DeviceDiscoveryCoordinator(
        modelContext: context,
        arpScanner: ARPScannerService(),
        bonjourScanner: BonjourDiscoveryService()
    )
    let session = MonitoringSession(
        modelContext: context,
        coordinator: coordinator,
        httpService: HTTPMonitorService(),
        icmpService: ICMPMonitorService(),
        tcpService: TCPMonitorService()
    )

    return QuickStatsBar()
        .padding()
        .modelContainer(container)
        .environment(session)
        .environment(coordinator)
}
#endif
