import SwiftUI
import SwiftData
import os

struct TargetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]

    @State private var showingAddSheet = false
    @State private var selectedTarget: NetworkTarget?
    @State private var sortOption: TargetSortOption = .name
    @State private var targetToDelete: NetworkTarget?
    @State private var showDeleteConfirmation = false

    var sortedTargets: [NetworkTarget] {
        switch sortOption {
        case .name:
            return targets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Add network hosts here to quickly pre-fill them in network tools")
                )
            } else {
                List(selection: $selectedTarget) {
                    ForEach(sortedTargets) { target in
                        TargetRow(target: target)
                            .tag(target)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    target.isEnabled.toggle()
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        Logger.data.error("Failed to save target enabled state: \(error)")
                                    }
                                } label: {
                                    Label(target.isEnabled ? "Disable" : "Enable",
                                          systemImage: target.isEnabled ? "pause.circle" : "play.circle")
                                }
                                .tint(target.isEnabled ? .orange : .green)
                            }
                            .contextMenu {
                                Button {
                                    useInTool(target)
                                } label: {
                                    Label("Use in Ping Tool", systemImage: "network")
                                }

                                Button {
                                    copyAddress(target)
                                } label: {
                                    Label("Copy Address", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    targetToDelete = target
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteTargets)
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Bookmark", systemImage: "plus")
                }
                .accessibilityIdentifier("targets_button_add")
            }
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    if let selected = selectedTarget {
                        targetToDelete = selected
                        showDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedTarget == nil)
                .accessibilityIdentifier("targets_button_delete")
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
                .accessibilityIdentifier("targets_menu_sort")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTargetSheet()
        }
        .confirmationDialog("Delete Bookmark?", isPresented: $showDeleteConfirmation, presenting: targetToDelete) { target in
            Button("Delete", role: .destructive) {
                deleteTarget(target)
            }
            Button("Cancel", role: .cancel) { }
        } message: { target in
            Text("This will permanently delete '\(target.name)'.")
        }
    }

    // MARK: - Actions

    private func useInTool(_ target: NetworkTarget) {
        NotificationCenter.default.post(
            name: .useTargetInTool,
            object: nil,
            userInfo: ["host": target.host, "port": target.port as Any, "name": target.name]
        )
    }

    private func copyAddress(_ target: NetworkTarget) {
        let address: String
        if let port = target.port {
            address = "\(target.host):\(port)"
        } else {
            address = target.host
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
    }

    private func deleteTargets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedTargets[index])
        }
        do {
            try modelContext.save()
        } catch {
            Logger.data.error("Error deleting targets: \(error, privacy: .public)")
        }
    }

    private func deleteTarget(_ target: NetworkTarget) {
        modelContext.delete(target)

        if selectedTarget?.id == target.id {
            selectedTarget = nil
        }

        do {
            try modelContext.save()
        } catch {
            Logger.data.error("Error deleting target: \(error, privacy: .public)")
        }
    }
}

// MARK: - Sort Options

enum TargetSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case `protocol` = "Protocol"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .protocol: return "network"
        }
    }
}

// MARK: - Target Row

struct TargetRow: View {
    @Bindable var target: NetworkTarget
    @Environment(\.compactMode) private var compactMode

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: compactMode ? 2 : 4) {
                Text(target.name)
                    .font(.headline)

                Text(target.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: compactMode ? 8 : 12) {
                Label(target.targetProtocol.rawValue, systemImage: target.targetProtocol.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Enabled", isOn: $target.isEnabled)
                    .labelsHidden()
            }
        }
        .padding(.vertical, compactMode ? 2 : 4)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let useTargetInTool = Notification.Name("useTargetInTool")
}

#if DEBUG
#Preview {
    TargetsView()
        .modelContainer(PreviewContainer().container)
}
#endif
