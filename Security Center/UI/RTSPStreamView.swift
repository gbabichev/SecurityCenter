//
//  RTSPStreamView.swift
//  Security Center
//
//  Created by Codex on 4/21/26.
//

import SwiftUI
import VLCKitSPM

struct RTSPStreamView: View {
    let url: URL?
    let isMuted: Bool
    let onStatusChange: (SnapshotStatus) -> Void

    var body: some View {
        VLCPlayerContainer(url: url, isMuted: isMuted, onStatusChange: onStatusChange)
            .background(Color.black)
    }
}

#if os(iOS)
private typealias VLCPlatformViewRepresentable = UIViewRepresentable
private typealias VLCPlatformView = UIView
#else
private typealias VLCPlatformViewRepresentable = NSViewRepresentable
private typealias VLCPlatformView = NSView
#endif

private struct VLCPlayerContainer: VLCPlatformViewRepresentable {
    let url: URL?
    let isMuted: Bool
    let onStatusChange: (SnapshotStatus) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange)
    }

#if os(iOS)
    func makeUIView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.backgroundColor = .black
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
        return view
    }

    func updateUIView(_ view: VLCPlatformView, context: Context) {
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
    }

    static func dismantleUIView(_ view: VLCPlatformView, coordinator: Coordinator) {
        coordinator.stop()
    }
#else
    func makeNSView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
        return view
    }

    func updateNSView(_ view: VLCPlatformView, context: Context) {
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
    }

    static func dismantleNSView(_ view: VLCPlatformView, coordinator: Coordinator) {
        coordinator.stop()
    }
#endif

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private let player = VLCMediaPlayer(options: [
            "--network-caching=300",
            "--live-caching=300",
            "--clock-jitter=0",
            "--clock-synchro=0",
            "--rtsp-tcp"
        ])
        private let onStatusChange: (SnapshotStatus) -> Void
        private var currentURL: URL?
        private var currentIsMuted = false
        private var reconnectTask: Task<Void, Never>?
        private var isActive = false
        private var hasShownVideo = false

        init(onStatusChange: @escaping (SnapshotStatus) -> Void) {
            self.onStatusChange = onStatusChange
            super.init()
            player.delegate = self
        }

        func attach(to view: VLCPlatformView) {
            player.drawable = view
            isActive = true
            applyMute()
        }

        func update(url: URL?, isMuted: Bool) {
            let didURLChange = currentURL != url
            let didMuteChange = currentIsMuted != isMuted
            guard didURLChange || didMuteChange else { return }

            currentIsMuted = isMuted
            applyMute()
            guard didURLChange else { return }

            reconnectTask?.cancel()
            currentURL = url
            hasShownVideo = false

            guard let url else {
                player.stop()
                player.media = nil
                publish(.failed)
                return
            }

            let media = VLCMedia(url: url)
            configure(media: media)
            player.media = media
            publish(.loading)
            player.play()
        }

        func stop() {
            isActive = false
            reconnectTask?.cancel()
            reconnectTask = nil
            player.stop()
            player.media = nil
        }

        func mediaPlayerStateChanged(_ notification: Notification) {
            switch player.state {
            case .opening, .buffering:
                if !hasShownVideo {
                    publish(.loading)
                }
            case .playing, .paused, .esAdded:
                reconnectTask?.cancel()
                reconnectTask = nil
                hasShownVideo = true
                publish(.ok)
            case .error, .ended, .stopped:
                hasShownVideo = false
                publish(.failed)
                scheduleReconnect()
            @unknown default:
                if !hasShownVideo {
                    publish(.loading)
                }
            }
        }

        private func scheduleReconnect() {
            guard isActive, currentURL != nil else { return }
            reconnectTask?.cancel()
            reconnectTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let currentURL = self.currentURL, self.isActive else { return }
                    let media = VLCMedia(url: currentURL)
                    self.configure(media: media)
                    self.player.media = media
                    self.hasShownVideo = false
                    self.publish(.loading)
                    self.player.play()
                }
            }
        }

        private func configure(media: VLCMedia) {
            media.addOption("network-caching=300")
            media.addOption("live-caching=300")
            media.addOption("rtsp-tcp")
        }

        private func applyMute() {
            player.audio?.isMuted = currentIsMuted
        }

        private func publish(_ status: SnapshotStatus) {
            Task { @MainActor in
                onStatusChange(status)
            }
        }
    }
}
