//
//  IdleCursorHider.swift
//  Security Center
//
//  Created by Codex on 4/22/26.
//

import SwiftUI

#if os(macOS)
import AppKit

struct IdleCursorHider: NSViewRepresentable {
    let enabled: Bool
    let timeout: TimeInterval

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        context.coordinator.attach(to: view)
        context.coordinator.update(enabled: enabled, timeout: timeout)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
        context.coordinator.update(enabled: enabled, timeout: timeout)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        private var eventMonitor: Any?
        private weak var view: NSView?
        private weak var window: NSWindow?
        private var previousAcceptsMouseMovedEvents: Bool?
        private var idleTimer: Timer?
        private var isEnabled = false
        private var timeout: TimeInterval = 2

        func attach(to view: NSView) {
            self.view = view

            guard let window = view.window, self.window !== window else { return }
            restoreWindowState()
            self.window = window

            if isEnabled {
                configureWindowForMouseTracking()
            }
        }

        func update(enabled: Bool, timeout: TimeInterval) {
            self.timeout = timeout

            guard enabled != isEnabled else {
                if enabled {
                    scheduleIdleTimer()
                } else {
                    cancelIdleTimer()
                }
                return
            }

            isEnabled = enabled

            if enabled {
                configureWindowForMouseTracking()
                installMonitorIfNeeded()
                scheduleIdleTimer()
            } else {
                cancelIdleTimer()
                removeMonitor()
                restoreWindowState()
            }
        }

        func teardown() {
            cancelIdleTimer()
            removeMonitor()
            restoreWindowState()
        }

        private func installMonitorIfNeeded() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
                .mouseMoved,
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged,
                .scrollWheel
            ]) { [weak self] event in
                self?.scheduleIdleTimer()
                return event
            }
        }

        private func removeMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        private func scheduleIdleTimer() {
            guard isEnabled else { return }
            cancelIdleTimer()
            idleTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                NSCursor.setHiddenUntilMouseMoves(true)
            }
        }

        private func cancelIdleTimer() {
            idleTimer?.invalidate()
            idleTimer = nil
        }

        private func configureWindowForMouseTracking() {
            guard let window = view?.window ?? window else { return }
            if self.window == nil {
                self.window = window
            }
            if previousAcceptsMouseMovedEvents == nil {
                previousAcceptsMouseMovedEvents = window.acceptsMouseMovedEvents
            }
            window.acceptsMouseMovedEvents = true
        }

        private func restoreWindowState() {
            guard let window, let previousAcceptsMouseMovedEvents else { return }
            window.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
            self.previousAcceptsMouseMovedEvents = nil
        }
    }

    private final class PassthroughView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

extension View {
    func hideCursorWhenIdle(enabled: Bool, timeout: TimeInterval = 2) -> some View {
        background(IdleCursorHider(enabled: enabled, timeout: timeout))
    }
}
#else
extension View {
    func hideCursorWhenIdle(enabled _: Bool, timeout _: TimeInterval = 2) -> some View {
        self
    }
}
#endif
