//
//  CameraDetailView.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct CameraDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let camera: CameraConfig
    @State private var streamStatus: SnapshotStatus = .loading

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ZStack(alignment: overlayAlignment) {
                    if viewModel.isQuietHoursActive {
                        quietHoursView
                    } else if camera.isEnabled {
                        contentView
                    } else {
                        disabledView
                    }

                    streamStatusOverlay
                    cameraOverlay
                }
                .padding(viewModel.isQuietHoursActive ? 0 : 16)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .center
                )
            }
        }
        .onChange(of: camera.feedMode) {
            streamStatus = .loading
        }
        .onChange(of: viewModel.isQuietHoursActive) { _, isActive in
            streamStatus = isActive ? .ok : .loading
        }
        .onChange(of: camera.snapshotURL) {
            streamStatus = .loading
        }
        .onChange(of: camera.rtspURL) {
            streamStatus = .loading
        }
        .hideCursorWhenIdle(enabled: !viewModel.showSettings)
    }

    @ViewBuilder
    private var contentView: some View {
        switch camera.feedMode {
        case .snapshotPolling:
            SnapshotView(url: camera.snapshotURL, scalingMode: .fit) { status in
                streamStatus = status
            }
        case .rtsp:
            RTSPStreamView(url: camera.rtspURL, isMuted: camera.isMuted) { status in
                streamStatus = status
            }
        }
    }

    @ViewBuilder
    private var streamStatusOverlay: some View {
        if viewModel.isQuietHoursActive || !camera.isEnabled {
            EmptyView()
        } else {
            switch streamStatus {
            case .loading:
                ProgressView(loadingTitle)
                    .controlSize(.large)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
            case .failed:
                ContentUnavailableView(
                    failureTitle,
                    systemImage: "exclamationmark.triangle",
                    description: Text(failureMessage)
                )
                .padding(24)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(24)
            case .ok:
                EmptyView()
            }
        }
    }

    private var disabledView: some View {
        ContentUnavailableView(
            "Camera disabled",
            systemImage: "pause.circle",
            description: Text("Enable this camera in settings to resume polling or streaming.")
        )
    }

    private var quietHoursView: some View {
        QuietHoursSaverView(endLabel: viewModel.quietHours.endLabel)
    }

    private var loadingTitle: String {
        switch camera.feedMode {
        case .snapshotPolling:
            "Loading snapshot…"
        case .rtsp:
            "Opening live stream…"
        }
    }

    private var failureTitle: String {
        switch camera.feedMode {
        case .snapshotPolling:
            "Snapshot unavailable"
        case .rtsp:
            "Live stream unavailable"
        }
    }

    private var failureMessage: String {
        switch camera.kind {
        case .reolink:
            switch camera.feedMode {
            case .snapshotPolling:
                "Verify username, password, host, channel, and HTTP or HTTPS setting."
            case .rtsp:
                "Verify host, username, password, channel, and that live video is enabled on camera."
            }
        case .genericRTSP:
            "Verify the camera link and that the stream is reachable."
        }
    }

    private var overlayAlignment: Alignment {
        switch camera.nameLocation {
        case .topLeft:
            .topLeading
        case .topRight:
            .topTrailing
        case .bottomLeft:
            .bottomLeading
        case .bottomRight:
            .bottomTrailing
        }
    }

    @ViewBuilder
    private var cameraOverlay: some View {
        if !viewModel.isQuietHoursActive && camera.showsNameInDisplay {
            Text(camera.displayName)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: overlayAlignment)
        }
    }
}
