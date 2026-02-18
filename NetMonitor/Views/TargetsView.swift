import SwiftUI
import SwiftData
import os

/// Quick-launch bookmarks for network hosts.
///
/// The Targets list is no longer wired to active monitoring. Instead it acts
/// as a curated bookmark list: selecting a target pre-fills tool inputs.
/// Add, edit, enable/disable and delete targets here.
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
                    "No Saved Hosts",
                    systemImage: "bookmark",
                    description: Text("Add network hosts as bookmarks to quickly launch tools like Ping and Traceroute")
                )
            } else {
                List(selection: $selectedTarget) {
                    ForEach(sortedTargets) { target in
                        TargetRow(target: target, onQuickLaunch: handleQuickLaunch)
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
                                quickLaunchMenu(for: target)

                                Divider()

                                Button(role: .destructive) {
                                    targetToDelete = target
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Target", systemImage: "trash")
                                }
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
        .confirmationDialog("Delete Target?", isPresented: $showDeleteConfirmation, presenting: targetToDelete) { target in
            Button("Delete", role: .destructive) {
                deleteTarget(target)
            }
            Button("Cancel", role: .cancel) { }
        } message: { target in
            Text("This will permanently delete '\(target.name)' and all its history.")
        }
    }

    @ViewBuilder
    private func quickLaunchMenu(for target: NetworkTarget) -> some View {
        Button {
            handleQuickLaunch(tool: "ping", host: target.host)
        } label: {
            Label("Ping \(target.host)", systemImage: "waveform.path")
        }

        Button {
            handleQuickLaunch(tool: "traceroute", host: target.host)
        } label: {
            Label("Traceroute to \(target.host)", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }

        Button {
            handleQuickLaunch(tool: "portScanner", host: target.host)
        } label: {
            Label("Port Scan \(target.host)", systemImage: "network")
        }
    }

    private func handleQuickLaunch(tool: String, host: String) {
        UserDefaults.standard.set(host, forKey: "netmonitor.tools.launchHost")
        UserDefaults.standard.set(tool, forKey: "netmonitor.tools.pendingLaunchTool")
        NotificationCenter.default.post(
            name: .quickLaunchTool,
            object: nil,
            userInfo: ["tool": tool, "host": host]
        )
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
    let onQuickLaunch: (String, String) -> Void
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
                // Quick-launch buttons
                Button {
                    onQuickLaunch("ping", target.host)
                } label: {
                    Image(systemName: "waveform.path")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .help("Ping \(target.host)")

                Button {
                    onQuickLaunch("traceroute", target.host)
                } label: {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .help("Traceroute to \(target.host)")

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

// MARK: - Notifications

extension Notification.Name {
    static let quickLaunchTool = Notification.Name("netmonitor.quickLaunchTool")
}

#if DEBUG
#Preview {
    TargetsView()
        .modelContainer(PreviewContainer().container)
}
#endif
