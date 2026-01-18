import SwiftUI
import SwiftData
import AppKit

struct DevicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalDevice.lastSeen, order: .reverse) private var devices: [LocalDevice]

    @State private var coordinator: DeviceDiscoveryCoordinator?
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
        NavigationSplitView {
            deviceList
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(device: device)
            } else {
                ContentUnavailableView(
                    "Select a Device",
                    systemImage: "desktopcomputer",
                    description: Text("Choose a device from the list to view details")
                )
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            toolbarContent
        }
        .searchable(text: $searchText, prompt: "Search devices...")
        .onAppear {
            if coordinator == nil {
                coordinator = DeviceDiscoveryCoordinator(modelContext: modelContext)
            }
        }
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
        .frame(minWidth: 300)
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
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $filterOnlineOnly) {
                Label("Online Only", systemImage: "circle.fill")
            }
            .toggleStyle(.button)
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

        if !device.macAddress.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.macAddress, forType: .string)
            } label: {
                Label("Copy MAC Address", systemImage: "doc.on.doc")
            }
        }

        Divider()

        Button {
            // TODO: Implement ping
        } label: {
            Label("Ping Device", systemImage: "waveform.path")
        }

        Button {
            // TODO: Implement port scan
        } label: {
            Label("Scan Ports", systemImage: "network")
        }

        if !device.macAddress.isEmpty {
            Button {
                Task {
                    await wolAction.wake(device: device)
                }
            } label: {
                Label("Wake on LAN", systemImage: "power")
            }
        }

        Divider()

        Button(role: .destructive) {
            modelContext.delete(device)
        } label: {
            Label("Remove Device", systemImage: "trash")
        }
    }
}

#Preview {
    DevicesView()
        .modelContainer(PreviewContainer().container)
}
