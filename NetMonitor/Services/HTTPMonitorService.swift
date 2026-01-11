import Foundation

/// Actor-based HTTP/HTTPS monitoring service
actor HTTPMonitorService: NetworkMonitorService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(target: NetworkTarget) async throws -> TargetMeasurement {
        // Validate target protocol
        guard target.targetProtocol == .http || target.targetProtocol == .https else {
            throw NetworkMonitorError.invalidHost("Target protocol must be HTTP or HTTPS")
        }

        // Build URL
        let scheme = target.targetProtocol == .https ? "https" : "http"
        let port = target.port.map { ":\($0)" } ?? ""
        guard let url = URL(string: "\(scheme)://\(target.host)\(port)") else {
            throw NetworkMonitorError.invalidHost(target.host)
        }

        // Perform request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = target.timeout
        request.httpMethod = "HEAD"  // Use HEAD to minimize data transfer

        let startTime = Date()

        do {
            let (_, response) = try await session.data(for: request)
            let latency = Date().timeIntervalSince(startTime) * 1000  // Convert to ms

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                let isReachable = (200...399).contains(httpResponse.statusCode)

                return TargetMeasurement(
                    latency: latency,
                    isReachable: isReachable,
                    errorMessage: isReachable ? nil : "HTTP \(httpResponse.statusCode)"
                )
            }

            // Non-HTTP response (shouldn't happen but handle it)
            return TargetMeasurement(
                latency: latency,
                isReachable: true
            )

        } catch let error as URLError {
            let latency = Date().timeIntervalSince(startTime) * 1000

            // Map URLError to our error types
            let monitorError: NetworkMonitorError
            let errorMessage: String

            switch error.code {
            case .timedOut:
                monitorError = .timeout
                errorMessage = "Request timed out"
            case .notConnectedToInternet, .networkConnectionLost:
                monitorError = .networkUnreachable
                errorMessage = "Network unreachable"
            default:
                monitorError = .unknownError(error)
                errorMessage = error.localizedDescription
            }

            return TargetMeasurement(
                latency: nil,
                isReachable: false,
                errorMessage: errorMessage
            )
        }
    }
}
