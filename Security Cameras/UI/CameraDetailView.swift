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
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 16) {
                        ZStack(alignment: viewModel.cameraNameLocation.alignment) {
                            SnapshotView(url: camera.snapshotURL) { status in
                                snapshotStatus = status
                            }
                            .cornerRadius(8)

                            if viewModel.showCameraNameInDisplay {
                                Text(camera.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .cornerRadius(8)
                                    .padding(8)
                            }
                        }

                        Text(camera.host)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: 1200, maxHeight: 900)
                }
                .frame(minWidth: 900, minHeight: 600)
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
}
