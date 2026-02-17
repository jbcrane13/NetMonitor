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

                    Text(session.isMonitoring ? "Scanning Network" : "Idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    /// Most recently seen devices for display
    private var recentDevices: [LocalDevice] {
        session.discoveredDevices
            .sorted { ($0.lastSeen ?? .distantPast) > ($1.lastSeen ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(recentDevices) { device in
                    deviceRow(device: device)
                }

                if session.discoveredDevices.isEmpty {
                    Text(session.isMonitoring ? "Scanning…" : "No devices found")
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
                .fill(device.isOnline ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(deviceDisplayName(device))
                    .font(.caption)
                    .lineLimit(1)
                Text(device.ipAddress)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if let vendor = device.vendor, !vendor.isEmpty {
                Text(vendor)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(device.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(device.isOnline ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func deviceDisplayName(_ device: LocalDevice) -> String {
        if let hostname = device.hostname, !hostname.isEmpty {
            return hostname
        }
        return device.ipAddress
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

    private var onlineCount: Int { session.onlineTargetCount }
    private var offlineCount: Int { session.offlineTargetCount }
    private var totalCount: Int { session.discoveredDevices.count }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = try! ModelContainer(
        for: NetworkTarget.self, TargetMeasurement.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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

    return MenuBarPopoverView(session: session, onClose: {})
}
#endif
