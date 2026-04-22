//
//  RTSPConnectionService.swift
//  Security Cameras
//
//  Created by Codex on 4/21/26.
//

import Foundation
import Network

enum RTSPConnectionService {
    static func validate(camera: CameraConfig) async throws {
        guard await canReach(camera: camera) else {
            let port = camera.rtspURL?.port ?? 554
            throw CameraValidationError.transport("Could not reach RTSP service on port \(port).")
        }
    }

    static func canReach(camera: CameraConfig) async -> Bool {
        guard let url = camera.rtspURL,
              let host = url.host else { return false }
        let port = UInt16(url.port ?? 554)
        return await canReach(host: host, port: port)
    }

    private static func canReach(host: String, port: UInt16, timeout: TimeInterval = 5) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "RTSPConnectionService.\(host)")
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let probe = Probe(connection: connection, continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        await probe.finish(true)
                    }
                case .failed(_), .cancelled:
                    Task {
                        await probe.finish(false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                Task {
                    await probe.finish(false)
                }
            }
        }
    }
}

private actor Probe {
    private let connection: NWConnection
    private let continuation: CheckedContinuation<Bool, Never>
    private var finished = false

    init(connection: NWConnection, continuation: CheckedContinuation<Bool, Never>) {
        self.connection = connection
        self.continuation = continuation
    }

    func finish(_ result: Bool) {
        guard !finished else { return }
        finished = true
        connection.cancel()
        continuation.resume(returning: result)
    }
}
