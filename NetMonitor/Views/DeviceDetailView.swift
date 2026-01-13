import SwiftUI
import SwiftData
import NetMonitorShared

struct DeviceDetailView: View {
    @Bindable var device: LocalDevice
    @Environment(\.modelContext) private var modelContext

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedDeviceType: DeviceType = .unknown

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                networkInfoCard
                timestampsCard
                notesCard
                actionsSection
            }
            .padding()
        }
        .navigationTitle(device.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                    isEditing.toggle()
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(device.isOnline ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 64, height: 64)

                Image(systemName: device.deviceType.iconName)
                    .font(.title)
                    .foregroundStyle(device.isOnline ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Device Name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(device.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let vendor = device.vendor {
                    Text(vendor)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isEditing {
                Picker("Device Type", selection: $selectedDeviceType) {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        Label(type.rawValue.capitalized, systemImage: type.iconName)
                            .tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Network Info Card

    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Network Information", systemImage: "network")
                .font(.headline)

            Divider()

            infoRow(label: "IP Address", value: device.ipAddress, monospace: true)

            if !device.macAddress.isEmpty {
                infoRow(label: "MAC Address", value: device.macAddress, monospace: true)
            }

            if let hostname = device.hostname {
                infoRow(label: "Hostname", value: hostname, monospace: true)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timestamps Card

    private var timestampsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Activity", systemImage: "clock")
                .font(.headline)

            Divider()

            infoRow(
                label: "First Seen",
                value: device.firstSeen.formatted(date: .abbreviated, time: .shortened)
            )

            infoRow(
                label: "Last Seen",
                value: device.lastSeen.formatted(date: .abbreviated, time: .shortened)
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            Divider()

            if isEditing {
                TextEditor(text: $editedNotes)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                if let notes = device.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No notes")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actions", systemImage: "bolt")
                .font(.headline)

            Divider()

            HStack(spacing: 12) {
                actionButton(
                    title: "Ping",
                    systemImage: "waveform.path",
                    action: { /* TODO: Implement ping action */ }
                )

                actionButton(
                    title: "Port Scan",
                    systemImage: "network",
                    action: { /* TODO: Implement port scan action */ }
                )

                if !device.macAddress.isEmpty {
                    actionButton(
                        title: "Wake",
                        systemImage: "power",
                        action: { /* TODO: Implement WOL action */ }
                    )
                }

                actionButton(
                    title: "Add to Targets",
                    systemImage: "plus.circle",
                    action: { addToTargets() }
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Views

    private func infoRow(label: String, value: String, monospace: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(monospace ? .monospaced : .default)
                .textSelection(.enabled)
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Actions

    private func startEditing() {
        editedName = device.customName ?? ""
        editedNotes = device.notes ?? ""
        selectedDeviceType = device.deviceType
    }

    private func saveChanges() {
        device.customName = editedName.isEmpty ? nil : editedName
        device.notes = editedNotes.isEmpty ? nil : editedNotes
        device.deviceType = selectedDeviceType
        try? modelContext.save()
    }

    private func addToTargets() {
        let target = NetworkTarget(
            name: device.displayName,
            host: device.ipAddress,
            port: nil,
            targetProtocol: .icmp,
            checkInterval: 30,
            timeout: 10,
            isEnabled: true
        )
        modelContext.insert(target)
        try? modelContext.save()
    }
}
