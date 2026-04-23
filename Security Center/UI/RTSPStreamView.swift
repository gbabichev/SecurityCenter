//
//  RTSPStreamView.swift
//  Security Center
//
//  Created by Codex on 4/21/26.
//

import SwiftUI
import VLCKitSPM

enum RTSPScalingMode {
    case fit
    case stretch
}

private enum RTSPVLCConfiguration {
    static let sharedLibrary = VLCLibrary(options: [
        "--rtsp-tcp",
        "--network-caching=1000",
        "--live-caching=1000"
    ])

    static let mediaOptions = [
        "rtsp-tcp",
        "network-caching=1000",
        "live-caching=1000"
    ]
}

struct RTSPStreamView: View {
    let url: URL?
    let isMuted: Bool
    var scalingMode: RTSPScalingMode = .fit
    let onStatusChange: (SnapshotStatus) -> Void
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        GeometryReader { proxy in
            let baseSize = fittedSize(in: proxy.size)
            let scale = stretchScale(in: proxy.size, baseSize: baseSize)

            ZStack {
                Color.black

                VLCPlayerContainer(
                    url: url,
                    isMuted: isMuted,
                    onStatusChange: onStatusChange,
                    onVideoSizeChange: updateVideoAspectRatio
                )
                .frame(width: baseSize.width, height: baseSize.height)
                .scaleEffect(x: scale.width, y: scale.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .background(Color.black)
        }
    }

    private func fittedSize(in availableSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0, videoAspectRatio > 0 else {
            return availableSize
        }

        let availableAspectRatio = availableSize.width / availableSize.height

        if availableAspectRatio > videoAspectRatio {
            return CGSize(width: availableSize.height * videoAspectRatio, height: availableSize.height)
        } else {
            return CGSize(width: availableSize.width, height: availableSize.width / videoAspectRatio)
        }
    }

    private func stretchScale(in availableSize: CGSize, baseSize: CGSize) -> CGSize {
        guard scalingMode == .stretch,
              baseSize.width > 0,
              baseSize.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        return CGSize(
            width: availableSize.width / baseSize.width,
            height: availableSize.height / baseSize.height
        )
    }

    private func updateVideoAspectRatio(_ videoSize: CGSize) {
        guard videoSize.width > 0, videoSize.height > 0 else { return }
        videoAspectRatio = videoSize.width / videoSize.height
    }
}

#if os(iOS)
private typealias VLCPlatformViewRepresentable = UIViewRepresentable
private typealias VLCPlatformView = UIView
#else
private typealias VLCPlatformViewRepresentable = NSViewRepresentable
private typealias VLCPlatformView = VLCVideoView
#endif

private struct VLCPlayerContainer: VLCPlatformViewRepresentable {
    let url: URL?
    let isMuted: Bool
    let onStatusChange: (SnapshotStatus) -> Void
    let onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange, onVideoSizeChange: onVideoSizeChange)
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
        view.backColor = .black
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
        private let player = VLCMediaPlayer(library: RTSPVLCConfiguration.sharedLibrary)
        private let onStatusChange: (SnapshotStatus) -> Void
        private let onVideoSizeChange: (CGSize) -> Void
        private var currentURL: URL?
        private var currentIsMuted = false
        private var reconnectTask: Task<Void, Never>?
        private var isActive = false
        private var hasShownVideo = false

        init(
            onStatusChange: @escaping (SnapshotStatus) -> Void,
            onVideoSizeChange: @escaping (CGSize) -> Void
        ) {
            self.onStatusChange = onStatusChange
            self.onVideoSizeChange = onVideoSizeChange
            super.init()
            player.delegate = self
        }

        func attach(to view: VLCPlatformView) {
#if os(macOS)
            player.setVideoView(view)
#else
            player.drawable = view
#endif
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
                publishVideoSizeIfAvailable()
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
            for option in RTSPVLCConfiguration.mediaOptions {
                media.addOption(option)
            }
        }

        private func applyMute() {
            player.audio?.isMuted = currentIsMuted
        }

        private func publishVideoSizeIfAvailable() {
            let size = player.videoSize
            guard size.width > 0, size.height > 0 else { return }

            Task { @MainActor in
                onVideoSizeChange(size)
            }
        }

        private func publish(_ status: SnapshotStatus) {
            Task { @MainActor in
                onStatusChange(status)
            }
        }
    }
}
