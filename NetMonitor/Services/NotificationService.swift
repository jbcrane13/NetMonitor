import Foundation
import UserNotifications

/// Notification service for target status alerts
/// Handles permission requests and sends notifications for monitoring events
actor NotificationService {

    // MARK: - Types

    enum NotificationType {
        case targetOffline(targetName: String)
        case targetRecovered(targetName: String)
        case highLatency(targetName: String, latency: Double, threshold: Double)

        var title: String {
            switch self {
            case .targetOffline:
                return "Target Offline"
            case .targetRecovered:
                return "Target Recovered"
            case .highLatency:
                return "High Latency Detected"
            }
        }

        var body: String {
            switch self {
            case .targetOffline(let targetName):
                return "\(targetName) is no longer reachable"
            case .targetRecovered(let targetName):
                return "\(targetName) has recovered and is now reachable"
            case .highLatency(let targetName, let latency, let threshold):
                return "\(targetName) latency (\(Int(latency))ms) exceeds threshold (\(Int(threshold))ms)"
            }
        }

        var identifier: String {
            switch self {
            case .targetOffline(let targetName):
                return "offline-\(targetName)"
            case .targetRecovered(let targetName):
                return "recovered-\(targetName)"
            case .highLatency(let targetName, _, _):
                return "latency-\(targetName)"
            }
        }
    }

    enum NotificationError: Error, CustomStringConvertible {
        case notAuthorized
        case notificationFailed(String)

        var description: String {
            switch self {
            case .notAuthorized:
                return "Notification permission not granted"
            case .notificationFailed(let reason):
                return "Failed to send notification: \(reason)"
            }
        }
    }

    // MARK: - Properties

    private var isAuthorized: Bool = false
    private let center = UNUserNotificationCenter.current()

    // MARK: - Public API

    /// Request notification authorization from the user
    /// - Returns: Whether authorization was granted
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    /// Check current authorization status without prompting
    /// - Returns: Whether notifications are authorized
    func checkAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        isAuthorized = authorized
        return authorized
    }

    /// Send a notification for a monitoring event
    /// - Parameter type: The type of notification to send
    /// - Throws: NotificationError if not authorized or notification fails
    func send(_ type: NotificationType) async throws {
        // Check authorization status first
        guard await checkAuthorizationStatus() else {
            throw NotificationError.notAuthorized
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default
        content.categoryIdentifier = "NETMONITOR"

        // Add custom data
        switch type {
        case .targetOffline(let targetName):
            content.userInfo = ["type": "offline", "target": targetName]
        case .targetRecovered(let targetName):
            content.userInfo = ["type": "recovered", "target": targetName]
        case .highLatency(let targetName, let latency, let threshold):
            content.userInfo = [
                "type": "latency",
                "target": targetName,
                "latency": latency,
                "threshold": threshold
            ]
        }

        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: type.identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        // Send notification
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.notificationFailed(error.localizedDescription)
        }
    }

    /// Remove all pending and delivered notifications
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Remove notifications for a specific target
    /// - Parameter targetName: Name of the target
    func clearNotifications(for targetName: String) {
        let identifiers = [
            "offline-\(targetName)",
            "recovered-\(targetName)",
            "latency-\(targetName)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
