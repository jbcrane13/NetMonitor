import SwiftUI
import SwiftData
import NetMonitorShared

struct AddTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var selectedProtocol: TargetProtocol = .https
    @State private var checkInterval: Double = 5.0
    @State private var timeout: Double = 3.0

    var body: some View {
        NavigationStack {
            Form(content: {
                SwiftUI.Section {
                    TextField("Name", text: $name)
                    TextField("Host", text: $host)
                        .textContentType(.URL)

                    HStack {
                        TextField("Port (optional)", text: $port)
                            .textFieldStyle(.roundedBorder)

                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Target Details")
                }

                SwiftUI.Section {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(TargetProtocol.allCases, id: \.self) { protocolType in
                            Text(protocolType.rawValue)
                                .tag(protocolType)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Protocol")
                }

                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check Interval: \(Int(checkInterval))s")
                            .font(.subheadline)
                        Slider(value: $checkInterval, in: 1...60, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeout: \(Int(timeout))s")
                            .font(.subheadline)
                        Slider(value: $timeout, in: 1...30, step: 1)
                    }
                } header: {
                    Text("Monitoring Settings")
                }
            })
            .navigationTitle("Add Target")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTarget()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 500)
    }

    private var isValid: Bool {
        !name.isEmpty && !host.isEmpty
    }

    private func addTarget() {
        let portInt = Int(port)

        let target = NetworkTarget(
            name: name,
            host: host,
            port: portInt,
            targetProtocol: selectedProtocol,
            checkInterval: checkInterval,
            timeout: timeout
        )

        modelContext.insert(target)
        try? modelContext.save()
    }
}

#Preview {
    AddTargetSheet()
        .modelContainer(PreviewContainer().container)
}
