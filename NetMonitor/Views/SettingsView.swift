import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            NetworkSettingsView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }

            CompanionSettingsView()
                .tabItem {
                    Label("Companion", systemImage: "iphone")
                }

            DataManagementView()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("autoStartMonitoring") private var autoStartMonitoring = false
    @AppStorage("defaultCheckInterval") private var defaultCheckInterval = 10

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
            Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
            Toggle("Auto-start Monitoring on Launch", isOn: $autoStartMonitoring)

            Divider()

            Text("Default Target Settings")
                .font(.headline)

            Picker("Default Check Interval", selection: $defaultCheckInterval) {
                Text("5 seconds").tag(5)
                Text("10 seconds").tag(10)
                Text("30 seconds").tag(30)
                Text("60 seconds").tag(60)
            }
        }
        .padding()
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @AppStorage("notifyOnTargetDown") private var notifyOnTargetDown = true
    @AppStorage("notifyOnTargetRecovery") private var notifyOnTargetRecovery = true
    @AppStorage("notifyOnNewDevice") private var notifyOnNewDevice = false
    @AppStorage("notifySoundEnabled") private var notifySoundEnabled = true
    @AppStorage("criticalLatencyThreshold") private var criticalLatencyThreshold = 500

    var body: some View {
        Form {
            Text("Target Alerts")
                .font(.headline)

            Toggle("Notify when target goes offline", isOn: $notifyOnTargetDown)
            Toggle("Notify when target recovers", isOn: $notifyOnTargetRecovery)

            HStack {
                Text("High latency threshold")
                Spacer()
                TextField("ms", value: $criticalLatencyThreshold, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                Text("ms")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Device Discovery")
                .font(.headline)

            Toggle("Notify when new device discovered", isOn: $notifyOnNewDevice)

            Divider()

            Text("Sound")
                .font(.headline)

            Toggle("Play notification sounds", isOn: $notifySoundEnabled)
        }
        .padding()
    }
}

// MARK: - Network Settings

struct NetworkSettingsView: View {
    @AppStorage("pingTimeout") private var pingTimeout = 3
    @AppStorage("httpTimeout") private var httpTimeout = 10
    @AppStorage("scanConcurrency") private var scanConcurrency = 50
    @AppStorage("preferIPv4") private var preferIPv4 = true

    var body: some View {
        Form {
            Text("Timeouts")
                .font(.headline)

            HStack {
                Text("ICMP Ping Timeout")
                Spacer()
                Picker("", selection: $pingTimeout) {
                    Text("1s").tag(1)
                    Text("3s").tag(3)
                    Text("5s").tag(5)
                    Text("10s").tag(10)
                }
                .frame(width: 100)
            }

            HStack {
                Text("HTTP/HTTPS Timeout")
                Spacer()
                Picker("", selection: $httpTimeout) {
                    Text("5s").tag(5)
                    Text("10s").tag(10)
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                }
                .frame(width: 100)
            }

            Divider()

            Text("Device Discovery")
                .font(.headline)

            HStack {
                Text("Scan Concurrency")
                Spacer()
                Picker("", selection: $scanConcurrency) {
                    Text("25 concurrent").tag(25)
                    Text("50 concurrent").tag(50)
                    Text("100 concurrent").tag(100)
                }
                .frame(width: 150)
            }
            Text("Higher values scan faster but may stress your network")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Protocol")
                .font(.headline)

            Toggle("Prefer IPv4 over IPv6", isOn: $preferIPv4)
        }
        .padding()
    }
}

// MARK: - Companion App Settings

struct CompanionSettingsView: View {
    @AppStorage("companionEnabled") private var companionEnabled = true
    @AppStorage("companionPort") private var companionPort = 8849
    @AppStorage("companionAutoAccept") private var companionAutoAccept = false

    var body: some View {
        Form {
            Toggle("Enable Companion App Service", isOn: $companionEnabled)

            HStack {
                Text("Service Port")
                Spacer()
                TextField("Port", value: $companionPort, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Auto-accept companion connections", isOn: $companionAutoAccept)

            Divider()

            Text("Status")
                .font(.headline)

            HStack {
                Circle()
                    .fill(companionEnabled ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(companionEnabled ? "Advertising on local network" : "Service disabled")
                    .foregroundStyle(.secondary)
            }

            Text("Service Type: _netmon._tcp")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("The companion app allows you to monitor your network from your iOS device. Both devices must be on the same local network.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Data Management

struct DataManagementView: View {
    @AppStorage("retentionDays") private var retentionDays = 30
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @State private var showingClearAlert = false
    @State private var dataSize = "Calculating..."

    var body: some View {
        Form {
            Text("Data Retention")
                .font(.headline)

            Picker("Keep measurement history for", selection: $retentionDays) {
                Text("7 days").tag(7)
                Text("14 days").tag(14)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("Forever").tag(-1)
            }

            Divider()

            Text("iCloud Sync")
                .font(.headline)

            Toggle("Sync targets and settings to iCloud", isOn: $cloudSyncEnabled)
            Text("Sync target configurations and custom device names across your Mac devices")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Storage")
                .font(.headline)

            HStack {
                Text("Database Size")
                Spacer()
                Text(dataSize)
                    .foregroundStyle(.secondary)
            }

            Button("Clear All Measurement Data", role: .destructive) {
                showingClearAlert = true
            }
        }
        .padding()
        .onAppear {
            calculateDataSize()
        }
        .alert("Clear Measurement Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearMeasurementData()
            }
        } message: {
            Text("This will permanently delete all historical measurement data. Target configurations will be preserved.")
        }
    }

    private func calculateDataSize() {
        Task {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let storeURL = appSupport?.appendingPathComponent("default.store") {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
                    if let size = attributes[.size] as? Int64 {
                        let formatter = ByteCountFormatter()
                        formatter.countStyle = .file
                        await MainActor.run {
                            dataSize = formatter.string(fromByteCount: size)
                        }
                    }
                } catch {
                    await MainActor.run {
                        dataSize = "Unknown"
                    }
                }
            } else {
                await MainActor.run {
                    dataSize = "Not available"
                }
            }
        }
    }

    private func clearMeasurementData() {
        dataSize = "Calculating..."
        calculateDataSize()
    }
}

#Preview {
    SettingsView()
}
