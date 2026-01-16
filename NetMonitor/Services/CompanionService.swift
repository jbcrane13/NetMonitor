//
//  CompanionService.swift
//  NetMonitor
//
//  Created on 2026-01-13.
//

import Foundation
import Network
import NetMonitorShared

/// Bonjour service for companion app communication
actor CompanionService {

    let port: UInt16 = 8849
    let serviceType = "_netmon._tcp"
    let serviceName = "NetMonitor"

    private(set) var isRunning = false
    private(set) var connectedClients: [UUID: NWConnection] = [:]

    private var listener: NWListener?
    private var messageHandler: ((CompanionMessage, UUID) async -> CompanionMessage?)?

    /// Start the Bonjour service
    func start(messageHandler: @escaping (CompanionMessage, UUID) async -> CompanionMessage?) throws {
        guard !isRunning else { return }

        self.messageHandler = messageHandler

        // Create listener
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        // Add Bonjour service advertisement
        let txtRecord = NWTXTRecord()
        parameters.defaultProtocolStack.applicationProtocols.insert(
            NWProtocolFramer.Options(definition: CompanionFramer.definition),
            at: 0
        )

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener?.service = NWListener.Service(
            name: serviceName,
            type: serviceType,
            domain: "local.",
            txtRecord: txtRecord
        )

        listener?.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleListenerState(state)
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleNewConnection(connection)
            }
        }

        listener?.start(queue: .global())
        isRunning = true
    }

    /// Stop the service
    func stop() {
        listener?.cancel()
        listener = nil

        for (_, connection) in connectedClients {
            connection.cancel()
        }
        connectedClients.removeAll()

        isRunning = false
    }

    /// Send a message to all connected clients
    func broadcast(_ message: CompanionMessage) async {
        guard let data = try? JSONEncoder().encode(message) else { return }

        for (id, connection) in connectedClients {
            await send(data: data, to: connection, clientID: id)
        }
    }

    /// Send a message to a specific client
    func send(_ message: CompanionMessage, to clientID: UUID) async {
        guard let connection = connectedClients[clientID],
              let data = try? JSONEncoder().encode(message) else { return }

        await send(data: data, to: connection, clientID: clientID)
    }

    // MARK: - Private Methods

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("CompanionService: Listening on port \(port)")
        case .failed(let error):
            print("CompanionService: Failed - \(error)")
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let clientID = UUID()
        connectedClients[clientID] = connection

        print("CompanionService: New connection from client \(clientID)")

        connection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleConnectionState(state, clientID: clientID)
            }
        }

        connection.start(queue: .global())
        receiveMessage(from: connection, clientID: clientID)
    }

    private func handleConnectionState(_ state: NWConnection.State, clientID: UUID) {
        switch state {
        case .ready:
            print("CompanionService: Client \(clientID) connected")
            // Send initial status
            Task {
                await send(
                    .heartbeat(HeartbeatPayload()),
                    to: clientID
                )
            }
        case .failed(let error):
            print("CompanionService: Client \(clientID) failed - \(error)")
            connectedClients.removeValue(forKey: clientID)
        case .cancelled:
            print("CompanionService: Client \(clientID) disconnected")
            connectedClients.removeValue(forKey: clientID)
        default:
            break
        }
    }

    private nonisolated func receiveMessage(from connection: NWConnection, clientID: UUID) {
        // Capture values before closure to avoid actor isolation issues
        let capturedClientID = clientID
        let capturedConnection = connection

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            // Capture values BEFORE Task block
            let capturedData = data
            let capturedIsComplete = isComplete
            let capturedError = error

            if let data = capturedData, !data.isEmpty {
                Task { [weak self] in
                    await self?.processReceivedData(data, clientID: capturedClientID)
                }
            }

            if let error = capturedError {
                print("CompanionService: Receive error - \(error)")
                return
            }

            if !capturedIsComplete {
                // Use Task to safely call back into actor context
                Task { [weak self] in
                    self?.receiveMessage(from: capturedConnection, clientID: capturedClientID)
                }
            }
        }
    }

    private func processReceivedData(_ data: Data, clientID: UUID) async {
        do {
            let message = try JSONDecoder().decode(CompanionMessage.self, from: data)
            print("CompanionService: Received \(message) from \(clientID)")

            // Handle message and get response
            if let response = await messageHandler?(message, clientID) {
                await send(response, to: clientID)
            }
        } catch {
            print("CompanionService: Failed to decode message - \(error)")
            await send(
                .error(ErrorPayload(
                    code: "DECODE_ERROR",
                    message: "Failed to decode message: \(error.localizedDescription)"
                )),
                to: clientID
            )
        }
    }

    private nonisolated func send(data: Data, to connection: NWConnection, clientID: UUID) async {
        // Capture values before closure to avoid actor isolation issues
        let capturedClientID = clientID

        // Prefix with length for framing
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        connection.send(content: framedData, completion: .contentProcessed { error in
            if let error = error {
                print("CompanionService: Send error to \(capturedClientID) - \(error)")
            }
        })
    }
}

// MARK: - Protocol Framer

/// Custom framer for length-prefixed JSON messages
final class CompanionFramer: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: CompanionFramer.self)
    static let label = "NetMonitor"

    required init(framer: NWProtocolFramer.Instance) {}

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        // Simple length-prefixed framing
        return 0
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        // Pass through
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            print("Framer output error: \(error)")
        }
    }

    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}
}
