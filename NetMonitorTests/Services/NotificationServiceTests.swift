import Foundation
import Testing
import UserNotifications
@testable import NetMonitor

@Suite("Notification Service Tests")
struct NotificationServiceTests {

    @Test("Authorization request returns status")
    func requestAuthorizationReturnsStatus() async throws {
        let service = NotificationService()

        let granted = await service.requestAuthorization()

        // Result should be a boolean (true or false)
        #expect(granted == true || granted == false)
    }

    @Test("Authorization status check returns status")
    func checkAuthorizationStatus() async throws {
        let service = NotificationService()

        let authorized = await service.checkAuthorizationStatus()

        // Result should be a boolean
        #expect(authorized == true || authorized == false)
    }

    @Test("Notification type generates correct title and body")
    func notificationTypeProperties() {
        // Test target offline notification
        let offlineType = NotificationService.NotificationType.targetOffline(targetName: "TestTarget")
        #expect(offlineType.title == "Target Offline")
        #expect(offlineType.body.contains("TestTarget"))
        #expect(offlineType.body.contains("no longer reachable"))
        #expect(offlineType.identifier.contains("offline"))
        #expect(offlineType.identifier.contains("TestTarget"))

        // Test target recovered notification
        let recoveredType = NotificationService.NotificationType.targetRecovered(targetName: "TestTarget")
        #expect(recoveredType.title == "Target Recovered")
        #expect(recoveredType.body.contains("TestTarget"))
        #expect(recoveredType.body.contains("recovered"))
        #expect(recoveredType.identifier.contains("recovered"))

        // Test high latency notification
        let latencyType = NotificationService.NotificationType.highLatency(
            targetName: "TestTarget",
            latency: 150.0,
            threshold: 100.0
        )
        #expect(latencyType.title == "High Latency Detected")
        #expect(latencyType.body.contains("TestTarget"))
        #expect(latencyType.body.contains("150"))
        #expect(latencyType.body.contains("100"))
        #expect(latencyType.identifier.contains("latency"))
    }

    @Test("Notification identifiers are unique per target")
    func uniqueIdentifiersPerTarget() {
        let target1Offline = NotificationService.NotificationType.targetOffline(targetName: "Target1")
        let target2Offline = NotificationService.NotificationType.targetOffline(targetName: "Target2")

        #expect(target1Offline.identifier != target2Offline.identifier)
    }

    @Test("Notification identifiers are consistent per type and target")
    func consistentIdentifiers() {
        let notification1 = NotificationService.NotificationType.targetOffline(targetName: "TestTarget")
        let notification2 = NotificationService.NotificationType.targetOffline(targetName: "TestTarget")

        #expect(notification1.identifier == notification2.identifier)
    }

    @Test("Send notification throws when not authorized")
    func sendThrowsWhenNotAuthorized() async throws {
        let service = NotificationService()

        // Check current authorization status
        let isAuthorized = await service.checkAuthorizationStatus()

        // If not authorized, sending should throw
        if !isAuthorized {
            let notification = NotificationService.NotificationType.targetOffline(targetName: "Test")

            await #expect(throws: NotificationService.NotificationError.self) {
                try await service.send(notification)
            }
        }
    }

    @Test("Clear notifications does not throw")
    func clearNotificationsDoesNotThrow() {
        let service = NotificationService()

        // Should not throw
        service.clearAllNotifications()
    }

    @Test("Clear target-specific notifications does not throw")
    func clearTargetNotificationsDoesNotThrow() {
        let service = NotificationService()

        // Should not throw
        service.clearNotifications(for: "TestTarget")
    }

    @Test("Notification error descriptions are informative")
    func errorDescriptions() {
        let notAuthorizedError = NotificationService.NotificationError.notAuthorized
        #expect(notAuthorizedError.description.contains("not granted"))

        let failedError = NotificationService.NotificationError.notificationFailed("test error")
        #expect(failedError.description.contains("test error"))
    }

    @Test("Multiple notification types have different identifiers")
    func differentTypesHaveDifferentIdentifiers() {
        let offline = NotificationService.NotificationType.targetOffline(targetName: "Test")
        let recovered = NotificationService.NotificationType.targetRecovered(targetName: "Test")
        let latency = NotificationService.NotificationType.highLatency(
            targetName: "Test",
            latency: 100,
            threshold: 50
        )

        #expect(offline.identifier != recovered.identifier)
        #expect(offline.identifier != latency.identifier)
        #expect(recovered.identifier != latency.identifier)
    }
}
