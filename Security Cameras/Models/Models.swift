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

enum CameraFeedMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case snapshotPolling
    case rtsp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snapshotPolling:
            return "Reolink JPG"
        case .rtsp:
            return "RTSP"
        }
    }

    var description: String {
        switch self {
        case .snapshotPolling:
            return "JPEG snapshot polling over HTTP or HTTPS."
        case .rtsp:
            return "Live RTSP stream through VLCKit."
        }
    }
}

enum CameraStreamVariant: String, CaseIterable, Identifiable, Hashable, Codable {
    case main
    case sub

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main:
            return "Main Stream"
        case .sub:
            return "Substream"
        }
    }

    var pathSuffix: String {
        switch self {
        case .main:
            return "main"
        case .sub:
            return "sub"
        }
    }
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

enum GridPictureStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    case showWholePicture
    case fillEachBox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .showWholePicture:
            return "Show whole picture"
        case .fillEachBox:
            return "Fill each box"
        }
    }

    var description: String {
        switch self {
        case .showWholePicture:
            return "Keeps the full camera view visible."
        case .fillEachBox:
            return "Uses all the space in each box."
        }
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
    var feedMode: CameraFeedMode = .snapshotPolling
    var isEnabled: Bool = true
    var streamVariant: CameraStreamVariant = .main
    var isMuted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        username: String,
        password: String,
        channel: Int,
        useHTTPS: Bool,
        feedMode: CameraFeedMode = .snapshotPolling,
        isEnabled: Bool = true,
        streamVariant: CameraStreamVariant = .main,
        isMuted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.password = password
        self.channel = channel
        self.useHTTPS = useHTTPS
        self.feedMode = feedMode
        self.isEnabled = isEnabled
        self.streamVariant = streamVariant
        self.isMuted = isMuted
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case username
        case password
        case channel
        case useHTTPS
        case feedMode
        case isEnabled
        case streamVariant
        case isMuted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        channel = try container.decode(Int.self, forKey: .channel)
        useHTTPS = try container.decode(Bool.self, forKey: .useHTTPS)
        feedMode = try container.decodeIfPresent(CameraFeedMode.self, forKey: .feedMode) ?? .snapshotPolling
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        streamVariant = try container.decodeIfPresent(CameraStreamVariant.self, forKey: .streamVariant) ?? .main
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
    }

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
            useHTTPS: useHTTPS,
            feedMode: feedMode,
            isEnabled: isEnabled,
            streamVariant: streamVariant,
            isMuted: isMuted
        )
    }

    var snapshotURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/cgi-bin/api.cgi"
        var queryItems = [
            URLQueryItem(name: "cmd", value: "Snap"),
            URLQueryItem(name: "channel", value: "\(max(channel, 0))"),
            URLQueryItem(name: "rs", value: id.uuidString.replacingOccurrences(of: "-", with: "")),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if streamVariant == .sub {
            queryItems.append(URLQueryItem(name: "width", value: "640"))
            queryItems.append(URLQueryItem(name: "height", value: "480"))
        }
        components.queryItems = queryItems
        return components.url
    }

    var rtspURL: URL? {
        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = host
        components.port = 554
        components.user = username
        components.password = password
        // Reolink snapshot uses 0-based physical channels, while RTSP preview path is 1-based.
        components.path = "/Preview_\(String(format: "%02d", max(channel, 0) + 1))_\(streamVariant.pathSuffix)"
        return components.url
    }

    var connectionSummary: String {
        let prefix = isEnabled ? "" : "Disabled • "
        switch feedMode {
        case .snapshotPolling:
            return "\(prefix)\(useHTTPS ? "HTTPS" : "HTTP") JPG \(streamVariant == .main ? "main" : "sub")"
        case .rtsp:
            return "\(prefix)RTSP \(streamVariant == .main ? "main" : "sub")"
        }
    }

    var formattedSnapshotURL: String {
        guard var components = snapshotURL.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return "Invalid camera address"
        }
        var queryItems = [
            URLQueryItem(name: "cmd", value: "Snap"),
            URLQueryItem(name: "channel", value: "\(max(channel, 0))"),
            URLQueryItem(name: "rs", value: id.uuidString.replacingOccurrences(of: "-", with: "")),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if streamVariant == .sub {
            queryItems.append(URLQueryItem(name: "width", value: "640"))
            queryItems.append(URLQueryItem(name: "height", value: "480"))
        }
        components.queryItems = queryItems
        return components.string ?? "Invalid camera address"
    }

    var formattedRTSPURL: String {
        guard let host = rtspURL?.host,
              let path = rtspURL?.path else {
            return "Invalid camera address"
        }
        let credentials: String
        if username.isEmpty {
            credentials = ""
        } else if password.isEmpty {
            credentials = "\(username)@"
        } else {
            credentials = "\(username):\(password)@"
        }
        return "rtsp://\(credentials)\(host):554\(path)"
    }

    static var emptyDraft: CameraConfig {
        CameraConfig(
            name: "",
            host: "",
            username: "admin",
            password: "",
            channel: 0,
            useHTTPS: false,
            feedMode: .snapshotPolling,
            isEnabled: true,
            streamVariant: .main,
            isMuted: false
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
