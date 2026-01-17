//
//  WakeOnLanAction.swift
//  NetMonitor
//
//  Shared Wake on LAN action handler with alert support.
//

import SwiftUI

/// Observable state for Wake on LAN actions with alert support.
///
/// Use this in views that need WOL functionality to avoid duplicating
/// the service instance, alert state, and action logic.
///
/// Example:
/// ```swift
/// struct MyView: View {
///     @State private var wolAction = WakeOnLanAction()
///
///     var body: some View {
///         Button("Wake") {
///             Task { await wolAction.wake(device: device) }
///         }
///         .wakeOnLanAlert($wolAction)
///     }
/// }
/// ```
@Observable
final class WakeOnLanAction {
    private(set) var alertMessage: String?
    var showAlert: Bool = false

    private let service = WakeOnLanService()

    /// Send a Wake on LAN magic packet to the specified device.
    /// - Parameter device: The device to wake (must have a MAC address)
    @MainActor
    func wake(device: LocalDevice) async {
        guard !device.macAddress.isEmpty else {
            alertMessage = "Cannot wake \(device.displayName): No MAC address"
            showAlert = true
            return
        }

        do {
            try await service.wake(macAddress: device.macAddress)
            alertMessage = "Magic packet sent to \(device.displayName)"
        } catch {
            alertMessage = "Failed to wake \(device.displayName): \(error.localizedDescription)"
        }
        showAlert = true
    }

    /// Send a Wake on LAN magic packet to the specified MAC address.
    /// - Parameters:
    ///   - macAddress: The MAC address to wake
    ///   - displayName: A display name for alert messages
    @MainActor
    func wake(macAddress: String, displayName: String) async {
        do {
            try await service.wake(macAddress: macAddress)
            alertMessage = "Magic packet sent to \(displayName)"
        } catch {
            alertMessage = "Failed to wake \(displayName): \(error.localizedDescription)"
        }
        showAlert = true
    }

    /// Dismiss the alert.
    func dismissAlert() {
        showAlert = false
        alertMessage = nil
    }
}

// MARK: - View Modifier

/// View modifier that adds Wake on LAN alert handling.
struct WakeOnLanAlertModifier: ViewModifier {
    @Bindable var action: WakeOnLanAction

    func body(content: Content) -> some View {
        content
            .alert("Wake on LAN", isPresented: $action.showAlert) {
                Button("OK", role: .cancel) {
                    action.dismissAlert()
                }
            } message: {
                Text(action.alertMessage ?? "")
            }
    }
}

extension View {
    /// Adds Wake on LAN alert handling to the view.
    /// - Parameter action: The WakeOnLanAction instance managing WOL state
    func wakeOnLanAlert(_ action: WakeOnLanAction) -> some View {
        modifier(WakeOnLanAlertModifier(action: action))
    }
}
