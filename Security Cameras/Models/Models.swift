//
//  Models.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

enum SnapshotStatus {
    case loading
    case ok
    case failed
}

enum CameraValidationError: LocalizedError {
    case missingHost
    case invalidURL
    case duplicateCamera
    case unauthorized
    case unexpectedStatus(Int)
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return "Enter camera IP address or host name."
        case .invalidURL:
            return "Camera address is not valid."
        case .duplicateCamera:
            return "Camera with same connection already exists."
        case .unauthorized:
            return "Camera rejected username or password."
        case .unexpectedStatus(let statusCode):
            return "Camera returned HTTP \(statusCode)."
        case .invalidResponse:
            return "Camera responded, but not with snapshot image."
        case .transport(let message):
            return message
        }
    }
}

enum CameraNameLocation: String, CaseIterable, Identifiable, Hashable, Codable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft:
            return "Top Left"
        case .topRight:
            return "Top Right"
        case .bottomLeft:
            return "Bottom Left"
        case .bottomRight:
            return "Bottom Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }
}

enum GridOption: String, CaseIterable, Identifiable, Hashable, Codable {
    case grid2x2
    case grid2x4
    case grid4x4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid2x2:
            return "2x2"
        case .grid2x4:
            return "2x4"
        case .grid4x4:
            return "4x4"
        }
    }

    var columns: Int {
        switch self {
        case .grid2x2:
            return 2
        case .grid2x4:
            return 2
        case .grid4x4:
            return 4
        }
    }

    var rows: Int {
        switch self {
        case .grid2x2:
            return 2
        case .grid2x4:
            return 4
        case .grid4x4:
            return 4
        }
    }

    var maxItems: Int {
        columns * rows
    }
}

enum SidebarItem: Hashable {
    case camera(CameraConfig.ID)
    case grid(GridOption)
}

struct CameraConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var username: String
    var password: String
    var channel: Int
    var useHTTPS: Bool

    var displayName: String {
        name.isEmpty ? "Camera" : name
    }

    var sanitized: CameraConfig {
        CameraConfig(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            channel: channel,
            useHTTPS: useHTTPS
        )
    }

    var snapshotURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/cgi-bin/api.cgi"
        components.queryItems = [
            URLQueryItem(name: "cmd", value: "Snap"),
            URLQueryItem(name: "channel", value: "\(channel)"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        return components.url
    }

    var connectionSummary: String {
        useHTTPS ? "HTTPS" : "HTTP"
    }

    var formattedSnapshotURL: String {
        guard var components = snapshotURL.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return "Invalid camera address"
        }
        components.queryItems = [
            URLQueryItem(name: "cmd", value: "Snap"),
            URLQueryItem(name: "channel", value: "\(channel)"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "password", value: password.isEmpty ? "" : "••••••")
        ]
        return components.string ?? "Invalid camera address"
    }

    static var emptyDraft: CameraConfig {
        CameraConfig(
            name: "",
            host: "",
            username: "admin",
            password: "",
            channel: 0,
            useHTTPS: false
        )
    }
}

extension Data {
    var isJPEG: Bool {
        guard count >= 4 else { return false }
        return self[startIndex] == 0xFF
            && self[index(after: startIndex)] == 0xD8
            && self[index(before: endIndex)] == 0xD9
            && self[index(before: index(before: endIndex))] == 0xFF
    }
}
