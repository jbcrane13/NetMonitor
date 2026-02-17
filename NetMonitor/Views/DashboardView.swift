import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MonitoringSession.self) private var session: MonitoringSession?
    @Environment(DeviceDiscoveryCoordinator.self) private var coordinator: DeviceDiscoveryCoordinator?
    @Environment(\.compactMode) private var compactMode

    @Query(sort: \LocalDevice.lastSeen, order: .reverse) private var allDevices: [LocalDevice]

    var body: some View {
        ScrollView {
            VStack(spacing: compactMode ? 12 : 20) {
                // Header
                HStack {
                    Spacer()

                    // Start/Stop Button
                    if let session = session {
                        Button(action: {
                            if session.isMonitoring {
                                session.stopMonitoring()
                            } else {
                                session.startMonitoring()
                            }
                        }) {
                            Label(
                                session.isMonitoring ? "Stop Scanning" : "Start Scanning",
                                systemImage: session.isMonitoring ? "stop.circle.fill" : "play.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(session.isMonitoring ? .red : .green)
                        .accessibilityIdentifier("dashboard_button_monitoring_toggle")
                    }
                }
                .padding(.horizontal)

                // Error Message Display
                if let session = session, let errorMessage = session.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // Network Info Cards
                HStack(spacing: 16) {
                    ConnectionInfoCard()
                    GatewayInfoCard()
                }
                .padding(.horizontal)

                QuickStatsBar()
                    .padding(.horizontal)

                ISPInfoCard()
                    .padding(.horizontal)

                // Network Health Summary
                NetworkHealthCard(
                    devices: allDevices,
                    isScanning: coordinator?.isScanning ?? false,
                    lastScanTime: coordinator?.lastScanTime
                )
                .padding(.horizontal)

                // Recently seen devices
                if !allDevices.isEmpty {
                    RecentDevicesCard(devices: Array(allDevices.prefix(8)))
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, compactMode ? 8 : 16)
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Network Health Card

private struct NetworkHealthCard: View {
    let devices: [LocalDevice]
    let isScanning: Bool
    let lastScanTime: Date?

    private var onlineCount: Int { devices.filter { $0.isOnline }.count }
    private var offlineCount: Int { devices.filter { !$0.isOnline }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Network Health", systemImage: "network")
                    .font(.headline)

                Spacer()

                if isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let last = lastScanTime {
                    Text("Last scan \(last, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No scan yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 24) {
                HealthMetric(
                    value: "\(devices.count)",
                    label: "Devices Found",
                    icon: "laptopcomputer.and.iphone",
                    color: .blue
                )

                HealthMetric(
                    value: "\(onlineCount)",
                    label: "Online",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                HealthMetric(
                    value: "\(offlineCount)",
                    label: "Offline",
                    icon: "xmark.circle.fill",
                    color: offlineCount > 0 ? .red : .secondary
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct HealthMetric: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Recent Devices Card

private struct RecentDevicesCard: View {
    let devices: [LocalDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Devices", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            Divider()

            ForEach(devices) { device in
                RecentDeviceRow(device: device)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct RecentDeviceRow: View {
    let device: LocalDevice

    private var displayName: String {
        device.customName ?? device.hostname ?? device.vendor ?? device.ipAddress
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(device.isOnline ? Color.green : Color.red)
                .frame(width: 7, height: 7)

            Text(displayName)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Text(device.ipAddress)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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

    return DashboardView()
        .modelContainer(container)
        .environment(session)
        .environment(coordinator)
}
#endif
