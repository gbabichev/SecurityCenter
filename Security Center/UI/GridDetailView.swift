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
                Color.black
                    .ignoresSafeArea()

                if viewModel.isQuietHoursActive {
                    QuietHoursSaverView(endLabel: viewModel.quietHours.endLabel)
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
                    scalingMode: viewModel.gridPictureStyle == .showWholePicture ? .fit : .stretch,
                    pollingIntervalSeconds: camera.snapshotPollingIntervalSeconds
                ) { _ in }
            case .rtsp:
                RTSPStreamView(
                    url: camera.rtspURL,
                    isMuted: camera.isMuted,
                    scalingMode: viewModel.gridPictureStyle == .showWholePicture ? .fit : .stretch
                ) { _ in }
                .id("\(camera.id.uuidString)-\(viewModel.gridPictureStyle.rawValue)")
            }
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
