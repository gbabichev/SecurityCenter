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
