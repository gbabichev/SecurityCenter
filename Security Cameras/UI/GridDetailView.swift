//
//  GridDetailView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct GridDetailView: View {
    let cameras: [CameraConfig]
    let option: GridOption

    private var gridCameras: [CameraConfig] {
        Array(cameras.prefix(option.maxItems))
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
                            if index < gridCameras.count {
                                gridCell(for: gridCameras[index])
                            } else {
                                Rectangle()
                                    .fill(.black)
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func gridCell(for camera: CameraConfig) -> some View {
        ZStack(alignment: .topLeading) {
            SnapshotView(url: camera.snapshotURL) { _ in }
                .cornerRadius(8)
            Text(camera.displayName)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.6))
                .cornerRadius(6)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
