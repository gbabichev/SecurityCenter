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

enum RTSPPlaybackState: Equatable {
    case connecting
    case buffering
    case playing
    case reconnecting(seconds: Int)
    case failed

    var title: String {
        switch self {
        case .connecting:
            return "Connecting…"
        case .buffering:
            return "Buffering…"
        case .playing:
            return ""
        case .reconnecting(let seconds):
            return "Reconnecting in \(seconds)s…"
        case .failed:
            return "Stream unavailable"
        }
    }

    var status: SnapshotStatus {
        switch self {
        case .connecting, .buffering, .reconnecting:
            return .loading
        case .playing:
            return .ok
        case .failed:
            return .failed
        }
    }
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
    var backgroundColor: Color?
    let onStatusChange: (SnapshotStatus) -> Void
    var onPlaybackStateChange: (RTSPPlaybackState) -> Void = { _ in }
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        GeometryReader { proxy in
            let baseSize = fittedSize(in: proxy.size)
            let scale = stretchScale(in: proxy.size, baseSize: baseSize)

            ZStack {
                if let backgroundColor {
                    backgroundColor
                }

                VLCPlayerContainer(
                    url: url,
                    isMuted: isMuted,
                    backgroundColor: backgroundColor,
                    onStatusChange: onStatusChange,
                    onPlaybackStateChange: onPlaybackStateChange,
                    onVideoSizeChange: updateVideoAspectRatio
                )
                .frame(width: baseSize.width, height: baseSize.height)
                .scaleEffect(x: scale.width, y: scale.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .background {
                if let backgroundColor {
                    backgroundColor
                }
            }
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
    let backgroundColor: Color?
    let onStatusChange: (SnapshotStatus) -> Void
    let onPlaybackStateChange: (RTSPPlaybackState) -> Void
    let onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onStatusChange: onStatusChange,
            onPlaybackStateChange: onPlaybackStateChange,
            onVideoSizeChange: onVideoSizeChange
        )
    }

#if os(iOS)
    func makeUIView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.backgroundColor = backgroundColor.map(UIColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
        return view
    }

    func updateUIView(_ view: VLCPlatformView, context: Context) {
        view.backgroundColor = backgroundColor.map(UIColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
    }

    static func dismantleUIView(_ view: VLCPlatformView, coordinator: Coordinator) {
        coordinator.stop()
    }
#else
    func makeNSView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.backColor = backgroundColor.map(NSColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted)
        return view
    }

    func updateNSView(_ view: VLCPlatformView, context: Context) {
        view.backColor = backgroundColor.map(NSColor.init) ?? .clear
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
        private let onPlaybackStateChange: (RTSPPlaybackState) -> Void
        private let onVideoSizeChange: (CGSize) -> Void
        private var currentURL: URL?
        private var currentIsMuted = false
        private var reconnectTask: Task<Void, Never>?
        private var videoReadyTask: Task<Void, Never>?
        private var isActive = false
        private var hasShownVideo = false
        private var reconnectDelayNanoseconds: UInt64 = 2_000_000_000

        init(
            onStatusChange: @escaping (SnapshotStatus) -> Void,
            onPlaybackStateChange: @escaping (RTSPPlaybackState) -> Void,
            onVideoSizeChange: @escaping (CGSize) -> Void
        ) {
            self.onStatusChange = onStatusChange
            self.onPlaybackStateChange = onPlaybackStateChange
            self.onVideoSizeChange = onVideoSizeChange
            super.init()
            player.delegate = self
        }

        deinit {
            reconnectTask?.cancel()
            videoReadyTask?.cancel()
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
            videoReadyTask?.cancel()
            currentURL = url
            hasShownVideo = false
            reconnectDelayNanoseconds = 2_000_000_000

            guard let url else {
                player.stop()
                player.media = nil
                publish(.failed)
                return
            }

            let media = VLCMedia(url: url)
            configure(media: media)
            player.media = media
            publish(.connecting)
            player.play()
            waitForVideoOutput()
        }

        func stop() {
            isActive = false
            reconnectTask?.cancel()
            reconnectTask = nil
            videoReadyTask?.cancel()
            videoReadyTask = nil
            reconnectDelayNanoseconds = 2_000_000_000
            player.stop()
            player.media = nil
        }

        func mediaPlayerStateChanged(_ notification: Notification) {
            switch player.state {
            case .opening:
                if markPlayingIfVideoIsAvailable() {
                    return
                } else if !hasShownVideo {
                    publish(.connecting)
                }
            case .buffering:
                if markPlayingIfVideoIsAvailable() {
                    return
                } else if !hasShownVideo {
                    publish(.buffering)
                }
            case .playing, .paused, .esAdded:
                reconnectTask?.cancel()
                reconnectTask = nil
                reconnectDelayNanoseconds = 2_000_000_000
                publishVideoSizeIfAvailable()
                waitForVideoOutput()
            case .error, .ended, .stopped:
                videoReadyTask?.cancel()
                videoReadyTask = nil
                hasShownVideo = false
                publish(.failed)
                scheduleReconnect()
            @unknown default:
                if !hasShownVideo {
                    publish(.connecting)
                }
            }
        }

        private func scheduleReconnect() {
            guard isActive, currentURL != nil else { return }
            reconnectTask?.cancel()
            videoReadyTask?.cancel()
            let delayNanoseconds = reconnectDelayNanoseconds
            let delaySeconds = max(1, Int(delayNanoseconds / 1_000_000_000))
            reconnectDelayNanoseconds = min(reconnectDelayNanoseconds * 2, 30_000_000_000)
            publish(.reconnecting(seconds: delaySeconds))
            reconnectTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let currentURL = self.currentURL, self.isActive else { return }
                    let media = VLCMedia(url: currentURL)
                    self.configure(media: media)
                    self.player.media = media
                    self.hasShownVideo = false
                    self.publish(.connecting)
                    self.player.play()
                }
            }
        }

        private func waitForVideoOutput() {
            guard !hasShownVideo else { return }
            videoReadyTask?.cancel()
            videoReadyTask = Task { [weak self] in
                for _ in 0..<80 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else { return }
                    let hasVideo = await MainActor.run {
                        guard let self, self.isActive else { return false }
                        return self.hasVideoOutput
                    }
                    if hasVideo {
                        await MainActor.run {
                            guard let self, self.isActive else { return }
                            self.markPlayingIfVideoIsAvailable()
                        }
                        return
                    }
                }

                await MainActor.run {
                    guard let self, self.isActive, !self.hasShownVideo else { return }
                    self.publish(.buffering)
                }
            }
        }

        @discardableResult
        private func markPlayingIfVideoIsAvailable() -> Bool {
            guard isActive, hasVideoOutput else { return false }
            hasShownVideo = true
            publishVideoSizeIfAvailable()
            publish(.playing)
            return true
        }

        private var hasVideoOutput: Bool {
            let size = player.videoSize
            if size.width > 0 && size.height > 0 {
                return true
            }
            if player.hasVideoOut {
                return true
            }
            if let media = player.media {
                let statistics = media.statistics
                return statistics.displayedPictures > 0
                    || statistics.decodedVideo > 0
                    || statistics.readBytes > 0
                    || statistics.demuxReadBytes > 0
                    || statistics.inputBitrate > 0
                    || statistics.demuxBitrate > 0
            }
            return false
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

        private func publish(_ state: RTSPPlaybackState) {
            Task { @MainActor in
                onPlaybackStateChange(state)
                onStatusChange(state.status)
            }
        }
    }
}
