//
//  GridDetailView.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct GridDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let layout: GridLayout
#if os(iOS)
    @State private var activeSelectionIndex: Int?
#endif

    var body: some View {
        GeometryReader { proxy in
            let spacing = 0.0
            let padding = 0.0
            let cellWidth = max(
                0,
                (proxy.size.width - (padding * 2) - (spacing * Double(layout.columns - 1))) / Double(layout.columns)
            )
            let cellHeight = max(
                0,
                (proxy.size.height - (padding * 2) - (spacing * Double(layout.rows - 1))) / Double(layout.rows)
            )

            ZStack {
                viewBackground

                if viewModel.isQuietHoursActive {
                    QuietHoursSaverView(endLabel: viewModel.quietHoursSaverEndLabel)
                } else {
                    VStack(spacing: spacing) {
                        ForEach(0..<layout.rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<layout.columns, id: \.self) { column in
                                    let index = row * layout.columns + column
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
        .hideCursorWhenIdle(enabled: !viewModel.showSettings)
    }

    @ViewBuilder
    private func gridCell(for index: Int) -> some View {
        let cameraID = viewModel.gridCameraID(layout: layout, index: index)
        let camera = viewModel.cameras.first { $0.id == cameraID }

        ZStack {
            if let camera {
                gridContent(for: camera, index: index)
            } else {
                Rectangle()
                    .fill(viewModel.viewBackgroundStyle.color ?? .clear)
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
                emptyCellMenu(for: index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .contentShape(Rectangle())
        .clipped()
#if os(macOS)
        .overlay {
            if camera != nil {
                DoubleClickMenuAnchor(
                    items: selectionMenuItems(for: index, includeClear: true)
                )
            }
        }
#else
        .onTapGesture(count: 2) {
            guard camera != nil else { return }
            activeSelectionIndex = index
        }
        .popover(isPresented: bindingForSelectionPopover(index: index), arrowEdge: .bottom) {
            selectionPopover(for: index)
        }
#endif
    }

    @ViewBuilder
    private func gridContent(for camera: CameraConfig, index: Int) -> some View {
        GridCameraContent(
            camera: camera,
            gridPictureStyle: viewModel.gridPictureStyle,
            backgroundColor: viewModel.viewBackgroundStyle.color,
            startupDelayNanoseconds: startupDelayNanoseconds(for: index),
            onStatusChange: { status in
                viewModel.updatePlaybackAvailability(for: camera.id, status: status)
            }
        )
    }

    private func startupDelayNanoseconds(for index: Int) -> UInt64 {
        UInt64(min(index, 12)) * 250_000_000
    }

    @ViewBuilder
    private var viewBackground: some View {
        if let color = viewModel.viewBackgroundStyle.color {
            color.ignoresSafeArea()
        }
    }

    private func emptyCellMenu(for index: Int) -> some View {
        Menu {
            if viewModel.cameras.isEmpty {
                Text("No cameras available")
            } else {
                ForEach(selectionMenuItems(for: index, includeClear: false)) { item in
                    Button(item.title, action: item.action)
                }
            }
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

    private func selectionMenuItems(for index: Int, includeClear: Bool) -> [GridSelectionMenuItem] {
        var items = viewModel.cameras.map { camera in
            GridSelectionMenuItem(title: camera.displayName) {
                viewModel.setGridCameraID(layout: layout, index: index, cameraID: camera.id)
#if os(iOS)
                activeSelectionIndex = nil
#endif
            }
        }

        if includeClear {
            items.append(
                GridSelectionMenuItem(title: "Clear") {
                    viewModel.setGridCameraID(layout: layout, index: index, cameraID: nil)
#if os(iOS)
                    activeSelectionIndex = nil
#endif
                }
            )
        }

        return items
    }

    #if os(iOS)
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
                        viewModel.setGridCameraID(layout: layout, index: index, cameraID: camera.id)
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
    #endif
}

private struct GridSelectionMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}

private struct GridCameraContent: View {
    let camera: CameraConfig
    let gridPictureStyle: GridPictureStyle
    let backgroundColor: Color?
    let startupDelayNanoseconds: UInt64
    let onStatusChange: (SnapshotStatus) -> Void
    @State private var isReady = false
    @State private var status: SnapshotStatus = .loading
    @State private var rtspPlaybackState: RTSPPlaybackState = .connecting

    var body: some View {
        ZStack {
            Group {
                if !camera.isEnabled {
                    disabledContent
                } else if isReady {
                    cameraContent
                } else {
                    startupLoadingContent
                }
            }

            if camera.isEnabled {
                statusOverlay
            }
        }
        .task(id: startupKey) {
            isReady = false
            status = .loading
            rtspPlaybackState = .connecting
            onStatusChange(.loading)
            if startupDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: startupDelayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            isReady = true
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        switch camera.feedMode {
        case .snapshotPolling:
            SnapshotView(
                url: camera.snapshotURL,
                scalingMode: gridPictureStyle == .showWholePicture ? .fit : .stretch,
                pollingIntervalSeconds: camera.snapshotPollingIntervalSeconds,
                backgroundColor: backgroundColor
            ) { newStatus in
                status = newStatus
                onStatusChange(newStatus)
            }
        case .rtsp:
            RTSPStreamView(
                url: camera.rtspURL,
                isMuted: camera.isMuted,
                scalingMode: gridPictureStyle == .showWholePicture ? .fit : .stretch,
                backgroundColor: backgroundColor,
                onStatusChange: { newStatus in
                    status = newStatus
                    onStatusChange(newStatus)
                },
                onPlaybackStateChange: { state in
                    rtspPlaybackState = state
                }
            )
            .id("\(camera.id.uuidString)-\(gridPictureStyle.rawValue)")
        }
    }

    private var disabledContent: some View {
        Rectangle()
            .fill(backgroundColor ?? .clear)
            .overlay(
                ContentUnavailableView(
                    "Disabled",
                    systemImage: "pause.circle",
                    description: Text("Enable in settings")
                )
            )
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch status {
        case .loading:
            loadingBadge(statusTitle)
        case .failed:
            loadingBadge(camera.feedMode == .rtsp ? "Stream unavailable" : "Snapshot unavailable", systemImage: "exclamationmark.triangle")
        case .ok:
            EmptyView()
        }
    }

    private var startupLoadingContent: some View {
        Rectangle()
            .fill(backgroundColor ?? .clear)
    }

    private func loadingBadge(_ title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }

            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.72), in: Capsule())
    }

    private var statusTitle: String {
        switch camera.feedMode {
        case .snapshotPolling:
            return "Loading snapshot…"
        case .rtsp:
            return rtspPlaybackState.title
        }
    }

    private var startupKey: GridCameraStartupKey {
        GridCameraStartupKey(
            camera: camera,
            gridPictureStyle: gridPictureStyle,
            startupDelayNanoseconds: startupDelayNanoseconds
        )
    }
}

private struct GridCameraStartupKey: Hashable {
    let camera: CameraConfig
    let gridPictureStyle: GridPictureStyle
    let startupDelayNanoseconds: UInt64
}

#if os(macOS)
private struct DoubleClickMenuAnchor: NSViewRepresentable {
    let items: [GridSelectionMenuItem]

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items)
    }

    func makeNSView(context: Context) -> DoubleClickMenuView {
        let view = DoubleClickMenuView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: DoubleClickMenuView, context: Context) {
        context.coordinator.items = items
        nsView.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var items: [GridSelectionMenuItem]

        init(items: [GridSelectionMenuItem]) {
            self.items = items
        }

        func showMenu(at point: NSPoint, in view: NSView) {
            let menu = NSMenu()
            for (index, item) in items.enumerated() {
                let menuItem = NSMenuItem(title: item.title, action: #selector(handleMenuItem(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.tag = index
                menu.addItem(menuItem)
            }
            menu.popUp(positioning: nil, at: point, in: view)
        }

        @objc
        private func handleMenuItem(_ sender: NSMenuItem) {
            guard items.indices.contains(sender.tag) else { return }
            items[sender.tag].action()
        }
    }
}

private final class DoubleClickMenuView: NSView {
    weak var coordinator: DoubleClickMenuAnchor.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            coordinator?.showMenu(at: point, in: self)
        }
    }
}
#endif
