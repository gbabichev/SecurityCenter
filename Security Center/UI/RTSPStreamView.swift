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
    private static let nativeLogger = VLCStreamLogger()
    private static var loggingObserver: NSObjectProtocol?
    static let sharedLibrary: VLCLibrary = {
        let library = VLCLibrary(options: [
            "--no-snapshot-preview",
            "--no-osd",
            "--rtsp-tcp",
            "--network-caching=1000",
            "--live-caching=1000"
        ])
        library.loggers = StreamDebugLog.shared.isEnabled ? [nativeLogger] : nil
        loggingObserver = NotificationCenter.default.addObserver(forName: .streamDebugLoggingChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in
                library.loggers = StreamDebugLog.shared.isEnabled ? [nativeLogger] : nil
            }
        }
        return library
    }()

    static let mediaOptions = [
        "rtsp-tcp",
        "network-caching=1000",
        "live-caching=1000"
    ]
}

struct RTSPStreamView: View {
    let url: URL?
    let isMuted: Bool
    var diagnosticName = ""
    var scalingMode: RTSPScalingMode = .fit
    var backgroundColor: Color?
    var providesBackdrop = false
    var onBackdropImageChange: (PlatformImage?) -> Void = { _ in }
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
                    diagnosticName: diagnosticName,
                    backgroundColor: backgroundColor,
                    providesBackdrop: providesBackdrop,
                    onBackdropImageChange: onBackdropImageChange,
                    onStatusChange: onStatusChange,
                    onPlaybackStateChange: onPlaybackStateChange,
                    onVideoSizeChange: updateVideoAspectRatio
                )
                // Audio is selected when media opens. A mute change needs a fresh player.
                .id(isMuted)
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
    let diagnosticName: String
    let backgroundColor: Color?
    let providesBackdrop: Bool
    let onBackdropImageChange: (PlatformImage?) -> Void
    let onStatusChange: (SnapshotStatus) -> Void
    let onPlaybackStateChange: (RTSPPlaybackState) -> Void
    let onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onStatusChange: onStatusChange,
            onPlaybackStateChange: onPlaybackStateChange,
            onVideoSizeChange: onVideoSizeChange,
            onBackdropImageChange: onBackdropImageChange
        )
    }

#if os(iOS)
    func makeUIView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.backgroundColor = backgroundColor.map(UIColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted, providesBackdrop: providesBackdrop, diagnosticName: diagnosticName)
        return view
    }

    func updateUIView(_ view: VLCPlatformView, context: Context) {
        view.backgroundColor = backgroundColor.map(UIColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted, providesBackdrop: providesBackdrop, diagnosticName: diagnosticName)
    }

    static func dismantleUIView(_ view: VLCPlatformView, coordinator: Coordinator) {
        coordinator.stop()
    }
#else
    func makeNSView(context: Context) -> VLCPlatformView {
        let view = VLCPlatformView()
        view.backColor = backgroundColor.map(NSColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted, providesBackdrop: providesBackdrop, diagnosticName: diagnosticName)
        return view
    }

    func updateNSView(_ view: VLCPlatformView, context: Context) {
        view.backColor = backgroundColor.map(NSColor.init) ?? .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(url: url, isMuted: isMuted, providesBackdrop: providesBackdrop, diagnosticName: diagnosticName)
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
        private let onBackdropImageChange: (PlatformImage?) -> Void
        private var backdropTask: Task<Void, Never>?
        private var backdropDirectory: URL?
        private var backdropEnabled = false
        private var lastBackdropCaptureAt: Date?
        private static let backdropRefreshInterval: TimeInterval = 30 * 60
        private let diagnosticID = String(UUID().uuidString.prefix(8))
        private var diagnosticName = ""
        private var diagnosticsTask: Task<Void, Never>?
        private var diagnosticsObserver: NSObjectProtocol?
        private var lastLoggedPlayerState: Int?
        private var previousDisplayed: Int32?
        private var attachmentCount = 0
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
            onVideoSizeChange: @escaping (CGSize) -> Void,
            onBackdropImageChange: @escaping (PlatformImage?) -> Void
        ) {
            self.onStatusChange = onStatusChange
            self.onPlaybackStateChange = onPlaybackStateChange
            self.onVideoSizeChange = onVideoSizeChange
            self.onBackdropImageChange = onBackdropImageChange
            super.init()
            player.delegate = self
            diagnosticsObserver = NotificationCenter.default.addObserver(forName: .streamDebugLoggingChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshDiagnosticSampling() }
            }
        }

        deinit {
            diagnosticsTask?.cancel()
            if let diagnosticsObserver { NotificationCenter.default.removeObserver(diagnosticsObserver) }
            backdropTask?.cancel()
            if let backdropDirectory { try? FileManager.default.removeItem(at: backdropDirectory) }
            reconnectTask?.cancel()
            videoReadyTask?.cancel()
        }

        func attach(to view: VLCPlatformView) {
            attachmentCount += 1
#if os(macOS)
            player.setVideoView(view)
#else
            player.drawable = view
#endif
            isActive = true
            applyMute()
        }

        func update(url: URL?, isMuted: Bool, providesBackdrop: Bool, diagnosticName: String) {
            self.diagnosticName = diagnosticName
            StreamDebugLog.shared.registerCredentials(in: url)
            let didURLChange = currentURL != url
            if didURLChange || backdropEnabled != providesBackdrop {
                stopBackdropCapture()
                backdropEnabled = providesBackdrop
                if providesBackdrop && url != nil { startBackdropCapture() }
            }
            let didMuteChange = currentIsMuted != isMuted
            guard didURLChange || didMuteChange else { return }
            currentIsMuted = isMuted
            applyMute()
            guard didURLChange else { return }

            reconnectTask?.cancel()
            videoReadyTask?.cancel()
            currentURL = url
            previousDisplayed = nil
            lastLoggedPlayerState = nil
            refreshDiagnosticSampling()
            logDiagnostic("source changed; muted=\(isMuted) backdrop=\(providesBackdrop) caching=1000ms transport=tcp")
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
            logDiagnostic("stop requested")
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            stopBackdropCapture()
            isActive = false
            reconnectTask?.cancel()
            reconnectTask = nil
            videoReadyTask?.cancel()
            videoReadyTask = nil
            reconnectDelayNanoseconds = 2_000_000_000
            player.stop()
            player.media = nil
        }

        private func startBackdropCapture() {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("SecurityCenterBackdrop-" + UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch { return }
            backdropDirectory = directory
            backdropTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    let delay = self?.captureBackdrop() ?? 1_000_000_000
                    do { try await Task.sleep(nanoseconds: delay) }
                    catch { return }
                }
            }
        }

        private func captureBackdrop() -> UInt64 {
            guard isActive, backdropEnabled, let backdropDirectory else { return 1_000_000_000 }
            if let lastBackdropCaptureAt {
                let remaining = Self.backdropRefreshInterval - Date().timeIntervalSince(lastBackdropCaptureAt)
                if remaining > 0 { return UInt64(max(1, remaining) * 1_000_000_000) }
            }
            let file = backdropDirectory.appendingPathComponent("frame.png")
            // Live streams can keep reporting .buffering while displaying video.
            guard hasShownVideo, player.hasVideoOut else {
                try? FileManager.default.removeItem(at: file)
                onBackdropImageChange(nil)
                return 1_000_000_000
            }
            logDiagnostic("background snapshot requested")
            player.saveVideoSnapshot(at: file.path, withWidth: 256, andHeight: 0)
            // Retry promptly until the first successful frame; then sleep until it is due.
            return 1_000_000_000
        }

        func mediaPlayerSnapshot(_ notification: Notification) {
            Task { @MainActor [weak self] in self?.publishBackdropSnapshot() }
        }

        private func publishBackdropSnapshot() {
            guard isActive, backdropEnabled, let backdropDirectory else { return }
            let file = backdropDirectory.appendingPathComponent("frame.png")
            if let data = try? Data(contentsOf: file), let image = PlatformImage(data: data) {
                logDiagnostic("background snapshot completed")
                lastBackdropCaptureAt = Date()
                onBackdropImageChange(image)
                try? FileManager.default.removeItem(at: file)
            }
        }

        private func stopBackdropCapture() {
            backdropTask?.cancel()
            backdropTask = nil
            if let backdropDirectory { try? FileManager.default.removeItem(at: backdropDirectory) }
            backdropDirectory = nil
            lastBackdropCaptureAt = nil
            Task { @MainActor [onBackdropImageChange] in onBackdropImageChange(nil) }
        }

        func mediaPlayerStateChanged(_ notification: Notification) {
            if lastLoggedPlayerState != player.state.rawValue {
                lastLoggedPlayerState = player.state.rawValue
                logDiagnostic("VLC state=\(player.state.rawValue) videoOut=\(player.hasVideoOut) shownVideo=\(hasShownVideo)")
            }
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
            logDiagnostic("reconnect scheduled in \(delaySeconds)s")
            publish(.reconnecting(seconds: delaySeconds))
            reconnectTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let currentURL = self.currentURL, self.isActive else { return }
                    self.logDiagnostic("reconnect executing")
                    self.previousDisplayed = nil
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

        private func logDiagnostic(_ message: String) {
            let host = currentURL?.host ?? "none"
            let port = currentURL?.port ?? 554
            let path = currentURL?.path ?? ""
            StreamDebugLog.shared.write("RTSP \(diagnosticID)", "camera=\(diagnosticName) endpoint=\(host):\(port)\(path) \(message)")
        }

        private func refreshDiagnosticSampling() {
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            guard StreamDebugLog.shared.isEnabled, isActive, currentURL != nil else { return }
            previousDisplayed = nil
            logDiagnostic("diagnostics active")
            diagnosticsTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.logStatistics()
                    do { try await Task.sleep(nanoseconds: 5_000_000_000) }
                    catch { return }
                }
            }
        }

        private func logStatistics() {
            guard StreamDebugLog.shared.isEnabled, isActive, let media = player.media else { return }
            let stats = media.statistics
            let delta = previousDisplayed.map { stats.displayedPictures - $0 }
            previousDisplayed = stats.displayedPictures
            let size = player.videoSize
            logDiagnostic("stats state=\(player.state.rawValue) videoOut=\(player.hasVideoOut) size=\(size.width)x\(size.height) decoded=\(stats.decodedVideo) displayed=\(stats.displayedPictures) displayedDelta=\(delta.map(String.init) ?? "initial") lost=\(stats.lostPictures) audioProcessing=\(currentIsMuted ? "disabled" : "enabled") audioDecoded=\(stats.decodedAudio) audioPlayed=\(stats.playedAudioBuffers) bytes=\(stats.readBytes) inputBitrate=\(stats.inputBitrate) demuxCorrupted=\(stats.demuxCorrupted) demuxDiscontinuity=\(stats.demuxDiscontinuity) attachments=\(attachmentCount)")
        }

        private func configure(media: VLCMedia) {
            for option in RTSPVLCConfiguration.mediaOptions {
                media.addOption(option)
            }
            if currentIsMuted {
                media.addOption("no-audio")
            }
            logDiagnostic("media configured; audioProcessing=\(currentIsMuted ? "disabled" : "enabled") caching=1000ms transport=tcp")
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
