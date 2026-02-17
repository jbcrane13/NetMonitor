import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MonitoringSession.self) private var session: MonitoringSession?
    @Environment(DeviceDiscoveryCoordinator.self) private var discovery: DeviceDiscoveryCoordinator?
    @Environment(\.compactMode) private var compactMode

    var body: some View {
        ScrollView {
            VStack(spacing: compactMode ? 12 : 20) {
                // Header
                HStack {
                    Spacer()

                    // Start/Stop Scanning Button
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

                // Device Summary Section
                DeviceSummarySection(
                    devices: discovery?.discoveredDevices ?? session?.discoveredDevices ?? [],
                    isScanning: discovery?.isScanning ?? false,
                    lastScanTime: discovery?.lastScanTime ?? session?.lastScanTime
                )
                .padding(.horizontal)
            }
            .padding(.vertical, compactMode ? 8 : 16)
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Device Summary Section

struct DeviceSummarySection: View {
    let devices: [LocalDevice]
    let isScanning: Bool
    let lastScanTime: Date?

    private var recentDevices: [LocalDevice] {
        devices
            .sorted { ($0.lastSeen ?? .distantPast) > ($1.lastSeen ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label("Local Network", systemImage: "network")
                    .font(.headline)

                Spacer()

                if isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let lastScan = lastScanTime {
                    Text(lastScan, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if devices.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(isScanning ? "Scanning network…" : "No devices found yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isScanning {
                        Text("Tap 'Start Scanning' to discover local devices")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Summary stats row
                HStack(spacing: 0) {
                    DeviceStatPill(
                        count: devices.filter { $0.isOnline }.count,
                        label: "Online",
                        color: .green
                    )
                    Spacer()
                    DeviceStatPill(
                        count: devices.filter { !$0.isOnline }.count,
                        label: "Offline",
                        color: .secondary
                    )
                    Spacer()
                    DeviceStatPill(
                        count: devices.count,
                        label: "Total",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Recent devices
                VStack(spacing: 0) {
                    ForEach(recentDevices) { device in
                        DeviceRowCompact(device: device)

                        if device.id != recentDevices.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if devices.count > 5 {
                    Text("+ \(devices.count - 5) more devices — see Devices tab")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

// MARK: - Device Stat Pill

private struct DeviceStatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compact Device Row

private struct DeviceRowCompact: View {
    let device: LocalDevice

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(device.isOnline ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.callout)
                    .lineLimit(1)

                Text(device.ipAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if let vendor = device.vendor, !vendor.isEmpty {
                Text(vendor)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 12)
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

    return DashboardView()
        .modelContainer(container)
        .environment(session)
}
#endif
