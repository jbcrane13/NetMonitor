import SwiftUI
import SwiftData

struct TargetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]

    @State private var showingAddSheet = false
    @State private var selectedTarget: NetworkTarget?

    var body: some View {
        VStack {
            if targets.isEmpty {
                ContentUnavailableView(
                    "No Targets",
                    systemImage: "target",
                    description: Text("Add network targets to monitor")
                )
            } else {
                List(selection: $selectedTarget) {
                    ForEach(targets) { target in
                        TargetRow(target: target)
                            .tag(target)
                    }
                    .onDelete(perform: deleteTargets)
                }
            }
        }
        .navigationTitle("Targets")
        .toolbar {
            Button(action: { showingAddSheet = true }) {
                Label("Add Target", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTargetSheet()
        }
    }

    private func deleteTargets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(targets[index])
        }
        try? modelContext.save()
    }
}

struct TargetRow: View {
    @Bindable var target: NetworkTarget

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(target.name)
                    .font(.headline)

                Text(target.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Label(target.targetProtocol.rawValue, systemImage: target.targetProtocol.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Enabled", isOn: $target.isEnabled)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TargetsView()
        .modelContainer(PreviewContainer().container)
}
