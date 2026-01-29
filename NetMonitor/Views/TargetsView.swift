import SwiftUI
import SwiftData

struct TargetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MonitoringSession.self) private var monitoringSession: MonitoringSession?
    @Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]

    @State private var showingAddSheet = false
    @State private var selectedTarget: NetworkTarget?
    @State private var sortOption: TargetSortOption = .name

    var sortedTargets: [NetworkTarget] {
        switch sortOption {
        case .name:
            return targets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .status:
            return targets.sorted { lhs, rhs in
                let lhsOnline = monitoringSession?.latestMeasurement(for: lhs.id)?.isReachable ?? false
                let rhsOnline = monitoringSession?.latestMeasurement(for: rhs.id)?.isReachable ?? false
                if lhsOnline != rhsOnline {
                    return lhsOnline  // Online first
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .protocol:
            return targets.sorted { lhs, rhs in
                if lhs.targetProtocol != rhs.targetProtocol {
                    return lhs.targetProtocol.rawValue < rhs.targetProtocol.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

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
                    ForEach(sortedTargets) { target in
                        TargetRow(target: target, monitoringSession: monitoringSession)
                            .tag(target)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    target.isEnabled.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(target.isEnabled ? "Disable" : "Enable",
                                          systemImage: target.isEnabled ? "pause.circle" : "play.circle")
                                }
                                .tint(target.isEnabled ? .orange : .green)
                            }
                    }
                    .onDelete(perform: deleteTargets)
                }
            }
        }
        .navigationTitle("Targets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Target", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(TargetSortOption.allCases) { option in
                            Label(option.rawValue, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTargetSheet()
        }
    }

    private func deleteTargets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedTargets[index])
        }
        try? modelContext.save()
    }
}

enum TargetSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case status = "Status"
    case `protocol` = "Protocol"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .status: return "checkmark.circle"
        case .protocol: return "network"
        }
    }
}

struct TargetRow: View {
    @Bindable var target: NetworkTarget
    var monitoringSession: MonitoringSession?

    var statusColor: Color {
        guard let measurement = monitoringSession?.latestMeasurement(for: target.id) else {
            return .gray
        }
        return measurement.isReachable ? .green : .red
    }

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

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
