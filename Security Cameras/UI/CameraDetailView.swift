//
//  CameraDetailView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct CameraDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let camera: CameraConfig
    @State private var snapshotStatus: SnapshotStatus = .loading

    var body: some View {
        Group {
            if snapshotStatus == .failed {
                ContentUnavailableView(
                    "Check camera settings",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Verify username, password, host, and channel.")
                )
                .background(snapshotProbeView)
            } else {
                GeometryReader { proxy in
                    ZStack {
                        Color.black
                            .ignoresSafeArea()

                        ZStack(alignment: overlayAlignment) {
                            SnapshotView(url: camera.snapshotURL, contentMode: .fit) { status in
                                snapshotStatus = status
                            }

                            cameraOverlay
                        }
                        .padding(16)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                    }
                }
            }
        }
        .onChange(of: camera.snapshotURL) {
            snapshotStatus = .loading
        }
    }

    private var snapshotProbeView: some View {
        SnapshotView(url: camera.snapshotURL) { status in
            snapshotStatus = status
        }
        .frame(width: 1, height: 1)
        .opacity(0)
    }

    private var overlayAlignment: Alignment {
        switch viewModel.cameraNameLocation {
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
        if viewModel.showCameraNameInDisplay {
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
