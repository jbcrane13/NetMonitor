//
//  MenuBarPopoverView.swift
//  NetMonitor
//
//  Created on 2026-01-13.
//

import SwiftUI
import SwiftData

struct MenuBarPopoverView: View {
    @Bindable var session: MonitoringSession
    @Environment(DeviceDiscoveryCoordinator.self) private var coordinator: DeviceDiscoveryCoordinator?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Quick stats
            quickStats

            Divider()

            // Device list
            deviceList

            Divider()

            // Footer actions
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NetMonitor")
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(session.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    if session.isMonitoring && (coordinator?.isScanning == true) {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(session.isMonitoring ? "Monitoring" : "Stopped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Start/Stop button
            Button {
                if session.isMonitoring {
                    session.stopMonitoring()
                } else {
                    session.startMonitoring()
                }
            } label: {
                Image(systemName: session.isMonitoring ? "stop.fill" : "play.fill")
                    .foregroundStyle(session.isMonitoring ? .red : .green)
            }
            .buttonStyle(.borderless)
            .help(session.isMonitoring ? "Stop Scanning" : "Start Scanning")
        }
        .padding()
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 16) {
            statItem(
                value: "\(onlineCount)",
                label: "Online",
                color: .green
            )

            statItem(
                value: "\(offlineCount)",
                label: "Offline",
                color: .red
            )

            statItem(
                value: "\(totalCount)",
                label: "Devices",
                color: .blue
            )
        }
        .padding()
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Device List

    private var sortedDevices: [LocalDevice] {
        (coordinator?.discoveredDevices ?? [])
            .sorted { lhs, rhs in
                // Online first, then by lastSeen descending
                if lhs.isOnline != rhs.isOnline { return lhs.isOnline }
                return lhs.lastSeen > rhs.lastSeen
            }
            .prefix(5)
            .map { $0 }
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedDevices) { device in
                    deviceRow(device: device)
                }

                if sortedDevices.isEmpty {
                    Text(session.isMonitoring ? "Scanning for devices…" : "No devices discovered")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 200)
    }

    private func deviceRow(device: LocalDevice) -> some View {
        HStack {
            Circle()
                .fill(device.isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(device.customName ?? device.hostname ?? device.vendor ?? device.ipAddress)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(device.ipAddress)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Open NetMonitor") {
                WindowOpener.shared.openMainWindow()
                onClose()
            }
            .buttonStyle(.borderless)

            Spacer()

            if let startTime = session.startTime {
                Text("Running: \(startTime, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var onlineCount: Int {
        coordinator?.discoveredDevices.filter { $0.isOnline }.count ?? 0
    }

    private var offlineCount: Int {
        coordinator?.discoveredDevices.filter { !$0.isOnline }.count ?? 0
    }

    private var totalCount: Int {
        coordinator?.discoveredDevices.count ?? 0
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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

    return MenuBarPopoverView(session: session, onClose: {})
        .environment(coordinator)
}
