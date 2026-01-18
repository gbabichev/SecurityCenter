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
