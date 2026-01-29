import SwiftUI
import SwiftData
import AppKit

struct DevicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DeviceDiscoveryCoordinator.self) private var coordinator: DeviceDiscoveryCoordinator?
    @Query(sort: \LocalDevice.lastSeen, order: .reverse) private var devices: [LocalDevice]

    @State private var selectedDevice: LocalDevice?
    @State private var searchText: String = ""
    @State private var filterOnlineOnly: Bool = false
    @State private var wolAction = WakeOnLanAction()

    var filteredDevices: [LocalDevice] {
        var result = devices

        if filterOnlineOnly {
            result = result.filter { $0.isOnline }
        }

        if !searchText.isEmpty {
            result = result.filter { device in
                device.displayName.localizedCaseInsensitiveContains(searchText) ||
                device.ipAddress.contains(searchText) ||
                device.macAddress.localizedCaseInsensitiveContains(searchText) ||
                (device.vendor?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            // Device list
            VStack(spacing: 0) {
                deviceList
            }
            .frame(minWidth: 280, idealWidth: 350, maxWidth: 450)

            Divider()

            // Detail pane
            if let device = selectedDevice {
                DeviceDetailView(device: device)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Select a Device",
                    systemImage: "desktopcomputer",
                    description: Text("Choose a device from the list to view details")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            toolbarContent
        }
        .searchable(text: $searchText, prompt: "Search devices...")
        .accessibilityIdentifier("devices_search_field")
        .wakeOnLanAlert(wolAction)
    }

    // MARK: - Device List

    private var deviceList: some View {
        Group {
            if devices.isEmpty && coordinator?.isScanning != true {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "network",
                    description: Text("Tap Scan to discover devices on your network")
                )
            } else {
                List(filteredDevices, selection: $selectedDevice) { device in
                    DeviceRowView(device: device)
                        .tag(device)
                        .contextMenu {
                            deviceContextMenu(for: device)
                        }
                }
                .listStyle(.inset)
            }
        }
        .overlay {
            if coordinator?.isScanning == true {
                scanningOverlay
            }
        }
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        VStack(spacing: 16) {
            ProgressView(value: coordinator?.scanProgress ?? 0)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("Scanning network...")
                .font(.headline)

            Text("\(Int((coordinator?.scanProgress ?? 0) * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Stop") {
                coordinator?.stopScan()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("devices_button_stopScan")
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator?.startScan()
            } label: {
                Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(coordinator?.isScanning == true)
            .accessibilityIdentifier("devices_button_scan")
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $filterOnlineOnly) {
                Label("Online Only", systemImage: "circle.fill")
            }
            .toggleStyle(.button)
            .accessibilityIdentifier("devices_toggle_onlineOnly")
        }

        ToolbarItem(placement: .status) {
            HStack(spacing: 4) {
                Text("\(filteredDevices.count)")
                    .fontWeight(.semibold)
                Text("devices")
                    .foregroundStyle(.secondary)

                if let lastScan = coordinator?.lastScanTime {
                    Text("- Last scan: \(lastScan, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func deviceContextMenu(for device: LocalDevice) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(device.ipAddress, forType: .string)
        } label: {
            Label("Copy IP Address", systemImage: "doc.on.doc")
        }
        .accessibilityIdentifier("devices_menu_copyIP")

        if !device.macAddress.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.macAddress, forType: .string)
            } label: {
                Label("Copy MAC Address", systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier("devices_menu_copyMAC")
        }

        Divider()

        Button {
            // TODO: Implement ping
        } label: {
            Label("Ping Device", systemImage: "waveform.path")
        }
        .accessibilityIdentifier("devices_menu_ping")

        Button {
            // TODO: Implement port scan
        } label: {
            Label("Scan Ports", systemImage: "network")
        }
        .accessibilityIdentifier("devices_menu_portScan")

        if !device.macAddress.isEmpty {
            Button {
                Task {
                    await wolAction.wake(device: device)
                }
            } label: {
                Label("Wake on LAN", systemImage: "power")
            }
            .accessibilityIdentifier("devices_menu_wake")
        }

        Divider()

        Button(role: .destructive) {
            modelContext.delete(device)
        } label: {
            Label("Remove Device", systemImage: "trash")
        }
        .accessibilityIdentifier("devices_menu_remove")
    }
}

#Preview {
    DevicesView()
        .modelContainer(PreviewContainer().container)
}
