import SwiftUI
import SwiftData

@main
struct NetMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            NetworkTarget.self,
            TargetMeasurement.self,
            LocalDevice.self,
            MonitoringSession.self
        ])

        Settings {
            SettingsView()
        }
    }
}
