//
//  NetMonitorError.swift
//  NetMonitor
//
//  Shared error types for the NetMonitor application.
//

import Foundation

enum NetMonitorError: LocalizedError {
    case networkUnavailable
    case permissionDenied(String)
    case timeout(TimeInterval)
    case commandFailed(String)
    case saveFailed(Error)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .permissionDenied(let resource):
            return "Permission denied for \(resource)"
        case .timeout(let duration):
            return "Operation timed out after \(Int(duration)) seconds"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
