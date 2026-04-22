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
    @State private var activeSelectionIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let spacing = 0.0
            let padding = 0.0
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
        .hideCursorWhenIdle(enabled: !viewModel.showSettings)
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
        ZStack {
            if let camera {
                gridContent(for: camera)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay(
                        Rectangle()
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            }

            if let camera, camera.showsNameInDisplay {
                Text(camera.displayName)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: camera.nameLocation.alignment)
            }

            if camera == nil {
                emptyCellButton(for: index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                menuButton(for: index, camera: camera)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .contentShape(Rectangle())
        .clipped()
        .onTapGesture(count: 2) {
            guard camera != nil else { return }
            activeSelectionIndex = index
        }
        .popover(isPresented: bindingForSelectionPopover(index: index), arrowEdge: .bottom) {
            selectionPopover(for: index)
        }
    }

    @ViewBuilder
    private func gridContent(for camera: CameraConfig) -> some View {
        if !camera.isEnabled {
            Rectangle()
                .fill(.black)
                .overlay(
                    ContentUnavailableView(
                        "Disabled",
                        systemImage: "pause.circle",
                        description: Text("Enable in settings")
                    )
                )
        } else {
            switch camera.feedMode {
            case .snapshotPolling:
                SnapshotView(
                    url: camera.snapshotURL,
                    scalingMode: viewModel.gridPictureStyle == .showWholePicture ? .fit : .stretch
                ) { _ in }
            case .rtsp:
                rtspGridView(for: camera)
            }
        }
    }

    @ViewBuilder
    private func rtspGridView(for camera: CameraConfig) -> some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if viewModel.gridPictureStyle == .showWholePicture {
                    let fittedSize = fittedVideoSize(in: proxy.size)
                    RTSPStreamView(url: camera.rtspURL, isMuted: camera.isMuted) { _ in }
                        .frame(width: fittedSize.width, height: fittedSize.height)
                } else {
                    RTSPStreamView(url: camera.rtspURL, isMuted: camera.isMuted) { _ in }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func fittedVideoSize(in size: CGSize) -> CGSize {
        let aspectRatio = 16.0 / 9.0
        let fittedWidth = min(size.width, size.height * aspectRatio)
        let fittedHeight = min(size.height, size.width / aspectRatio)
        return CGSize(width: fittedWidth, height: fittedHeight)
    }

    private func menuButton(for index: Int, camera: CameraConfig?) -> some View {
        Menu {
            ForEach(viewModel.cameras) { candidate in
                Button(candidate.displayName) {
                    viewModel.setGridCameraID(option: option, index: index, cameraID: candidate.id)
                }
            }
            Button("Clear") {
                viewModel.setGridCameraID(option: option, index: index, cameraID: nil)
            }
        } label: {
            if camera == nil {
                Text("Select Camera")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.7), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .padding(8)
                    .background(.black.opacity(0.45), in: Circle())
                    .foregroundStyle(.white)
            }
        }
        .padding(8)
    }

    private func emptyCellButton(for index: Int) -> some View {
        Button {
            activeSelectionIndex = index
        } label: {
            Text("Select Camera")
                .font(.headline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func bindingForSelectionPopover(index: Int) -> Binding<Bool> {
        Binding(
            get: { activeSelectionIndex == index },
            set: { isPresented in
                if isPresented {
                    activeSelectionIndex = index
                } else if activeSelectionIndex == index {
                    activeSelectionIndex = nil
                }
            }
        )
    }

    private func selectionPopover(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Camera")
                .font(.headline)

            if viewModel.cameras.isEmpty {
                Text("No cameras available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.cameras) { camera in
                    Button(camera.displayName) {
                        viewModel.setGridCameraID(option: option, index: index, cameraID: camera.id)
                        activeSelectionIndex = nil
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 180)
    }
}
