import SwiftUI

/// Placeholder for Device Detail View - to be implemented in Task 7
struct DeviceDetailView: View {
    let device: LocalDevice

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: device.deviceType.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(device.displayName)
                .font(.title)

            Text(device.ipAddress)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)

            if !device.macAddress.isEmpty {
                Text(device.macAddress)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            Text("Detail view - Task 7")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding()
        .navigationTitle("Device Details")
    }
}
