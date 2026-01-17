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
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("autoStartMonitoring") private var autoStartMonitoring = false
    @AppStorage("defaultCheckInterval") private var defaultCheckInterval = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                        Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                        Toggle("Auto-start Monitoring on Launch", isOn: $autoStartMonitoring)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Default Target Settings") {
                    Picker("Default Check Interval", selection: $defaultCheckInterval) {
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                        Text("30 seconds").tag(30)
                        Text("60 seconds").tag(60)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Target Alerts") {
                    VStack(alignment: .leading, spacing: 12) {
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Device Discovery") {
                    Toggle("Notify when new device discovered", isOn: $notifyOnNewDevice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Sound") {
                    Toggle("Play notification sounds", isOn: $notifySoundEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - Network Settings

struct NetworkSettingsView: View {
    @AppStorage("pingTimeout") private var pingTimeout = 3
    @AppStorage("httpTimeout") private var httpTimeout = 10
    @AppStorage("scanConcurrency") private var scanConcurrency = 50
    @AppStorage("preferIPv4") private var preferIPv4 = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Timeouts") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("ICMP Ping Timeout", selection: $pingTimeout) {
                            Text("1s").tag(1)
                            Text("3s").tag(3)
                            Text("5s").tag(5)
                            Text("10s").tag(10)
                        }

                        Picker("HTTP/HTTPS Timeout", selection: $httpTimeout) {
                            Text("5s").tag(5)
                            Text("10s").tag(10)
                            Text("30s").tag(30)
                            Text("60s").tag(60)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Device Discovery") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Scan Concurrency", selection: $scanConcurrency) {
                            Text("25 concurrent").tag(25)
                            Text("50 concurrent").tag(50)
                            Text("100 concurrent").tag(100)
                        }
                        Text("Higher values scan faster but may stress your network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Protocol") {
                    Toggle("Prefer IPv4 over IPv6", isOn: $preferIPv4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - Companion App Settings

struct CompanionSettingsView: View {
    @AppStorage("companionEnabled") private var companionEnabled = true
    @AppStorage("companionPort") private var companionPort = 8849
    @AppStorage("companionAutoAccept") private var companionAutoAccept = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Companion App Service", isOn: $companionEnabled)

                        HStack {
                            Text("Service Port")
                            Spacer()
                            TextField("Port", value: $companionPort, format: .number)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }

                        Toggle("Auto-accept companion connections", isOn: $companionAutoAccept)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    Text("The companion app allows you to monitor your network from your iOS device. Both devices must be on the same local network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - Data Management

struct DataManagementView: View {
    @AppStorage("retentionDays") private var retentionDays = 30
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @State private var showingClearAlert = false
    @State private var dataSize = "Calculating..."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Data Retention") {
                    Picker("Keep measurement history for", selection: $retentionDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("Forever").tag(-1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("iCloud Sync") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Sync targets and settings to iCloud", isOn: $cloudSyncEnabled)
                        Text("Sync target configurations and custom device names across your Mac devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Storage") {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
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
