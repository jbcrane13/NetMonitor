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

            // Target status list
            targetList

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

                    Text(session.isMonitoring ? "Monitoring" : "Stopped")
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
            .help(session.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
        }
        .padding()
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 16) {
            statItem(
                value: "\(onlineTargetCount)",
                label: "Online",
                color: .green
            )

            statItem(
                value: "\(offlineTargetCount)",
                label: "Offline",
                color: .red
            )

            statItem(
                value: averageLatencyString,
                label: "Avg Latency",
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

    // MARK: - Target List

    private var targetList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(session.latestResults.keys.prefix(5)), id: \.self) { targetID in
                    if let measurement = session.latestResults[targetID] {
                        targetRow(targetID: targetID, measurement: measurement)
                    }
                }

                if session.latestResults.isEmpty {
                    Text("No targets configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 200)
    }

    private func targetRow(targetID: UUID, measurement: TargetMeasurement) -> some View {
        HStack {
            Circle()
                .fill(measurement.isReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(targetID.uuidString.prefix(8))
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if measurement.isReachable, let latency = measurement.latency {
                Text("\(Int(latency))ms")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            } else {
                Text("Offline")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Open NetMonitor") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("NetMonitor") || $0.isMainWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
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

    private var onlineTargetCount: Int {
        session.latestResults.values.filter { $0.isReachable }.count
    }

    private var offlineTargetCount: Int {
        session.latestResults.values.filter { !$0.isReachable }.count
    }

    private var averageLatencyString: String {
        let latencies = session.latestResults.values.compactMap { $0.latency }
        guard !latencies.isEmpty else { return "—" }
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        return "\(Int(avg))ms"
    }
}

// MARK: - Preview

#Preview {
    MenuBarPopoverView(
        session: MonitoringSession(
            modelContext: try! ModelContainer(
                for: NetworkTarget.self, TargetMeasurement.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        ),
        onClose: {}
    )
}
