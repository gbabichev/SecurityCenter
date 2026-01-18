//
//  GridDetailView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct GridDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let option: GridOption

    private var gridCameras: [CameraConfig] {
        Array(viewModel.cameras.prefix(option.maxItems))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ForEach(0..<option.rows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<option.columns, id: \.self) { column in
                            let index = row * option.columns + column
                            gridCell(for: index)
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func gridCell(for index: Int) -> some View {
        let cameraID = viewModel.gridCameraID(option: option, index: index)
        let camera = viewModel.cameras.first { $0.id == cameraID }
        ZStack(alignment: viewModel.cameraNameLocation.alignment) {
            if let camera {
                SnapshotView(url: camera.snapshotURL) { _ in }
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay(
                        Rectangle()
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            }

            Menu {
                ForEach(viewModel.cameras) { camera in
                    Button(camera.displayName) {
                        viewModel.setGridCameraID(option: option, index: index, cameraID: camera.id)
                    }
                }
                Button("Clear") {
                    viewModel.setGridCameraID(option: option, index: index, cameraID: nil)
                }
            } label: {
                if viewModel.showCameraNameInDisplay {
                    Text(camera?.displayName ?? "Select Camera")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .cornerRadius(6)
                        .padding(8)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
