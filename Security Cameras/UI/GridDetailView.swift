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

    var body: some View {
        GeometryReader { proxy in
            let spacing = 12.0
            let padding = 16.0
            let cellWidth = max(
                0,
                (proxy.size.width - (padding * 2) - (spacing * Double(option.columns - 1))) / Double(option.columns)
            )
            let cellHeight = max(
                0,
                (proxy.size.height - (padding * 2) - (spacing * Double(option.rows - 1))) / Double(option.rows)
            )

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: spacing) {
                    ForEach(0..<option.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<option.columns, id: \.self) { column in
                                let index = row * option.columns + column
                                gridCell(for: index)
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(padding)
            }
        }
    }

    @ViewBuilder
    private func gridCell(for index: Int) -> some View {
        let cameraID = viewModel.gridCameraID(option: option, index: index)
        let camera = viewModel.cameras.first { $0.id == cameraID }
        ZStack(alignment: viewModel.cameraNameLocation.alignment) {
            if let camera {
                SnapshotView(url: camera.snapshotURL, contentMode: .fit) { _ in }
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
