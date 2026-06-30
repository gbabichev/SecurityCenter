//
//  ScreenAwakeController.swift
//  Security Center
//
//  Created by Codex on 6/30/26.
//

import Foundation

#if os(iOS)
import UIKit
#endif

@MainActor
final class ScreenAwakeController {
    static let shared = ScreenAwakeController()

    private var isEnabled = false

#if os(macOS)
    private var activity: NSObjectProtocol?
#endif

    private init() {}

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled

#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
#elseif os(macOS)
        if enabled {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled],
                reason: "Keep Security Center visible"
            )
        } else if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
#endif
    }
}
