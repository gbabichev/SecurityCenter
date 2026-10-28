//
//  ContentView.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSidebarItem: SidebarItem?
    @State private var showingSettings = false
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
#endif
    @State private var showingNewGridSheet = false
    @State private var editingGrid: GridLayout?
    @State private var settingsInitialCameraID: CameraConfig.ID?
    @State private var settingsStartsAddingCamera = false

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _selectedSidebarItem = State(initialValue: viewModel.selectedSidebarItem)
    }

    var body: some View {
        #if os(macOS)
        content
            .windowToolbarFullScreenVisibility(.onHover)
        #else
        content
        #endif
    }

    private var content: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                if viewModel.cameras.isEmpty {
                    noCamerasEmptyState
                } else if let selectedCamera {
                    CameraDetailView(viewModel: viewModel, camera: selectedCamera, isSettingsPresented: showingSettings)
                } else if let selectedGrid {
                    GridDetailView(viewModel: viewModel, layout: selectedGrid, isSettingsPresented: showingSettings)
                } else {
                    ContentUnavailableView(
                        "Select a Camera",
                        systemImage: "video",
                        description: Text("Choose a camera from the sidebar.")
                    )
                }
            }
            .toolbar {
                if viewModel.showQuietHoursInToolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            viewModel.toggleManualQuietHours()
                        } label: {
                            Label(quietHoursToolbarTitle, systemImage: viewModel.isQuietHoursActive ? "moon.fill" : "moon")
                        }
#if os(macOS)
                        .help(quietHoursToolbarTitle)
#endif
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            CameraSettingsView(
                viewModel: viewModel,
                initialCameraID: settingsInitialCameraID,
                startsAddingCamera: settingsStartsAddingCamera,
                presentsEditorDirectly: settingsStartsAddingCamera || settingsInitialCameraID != nil
            )
        }
        .sheet(isPresented: $showingNewGridSheet) {
            NavigationStack {
                GridSettingsEditor(viewModel: viewModel, existingGrid: editingGrid) { grid in
                    selectSidebarItem(.grid(grid.id))
                }
            }
        }
        .onChange(of: showingSettings) { _, isPresented in
            if !isPresented {
                settingsInitialCameraID = nil
                settingsStartsAddingCamera = false
            }
        }
        .onChange(of: viewModel.cameras.map(\.id)) {
            normalizeWindowSelection()
        }
        .onChange(of: viewModel.grids.map(\.id)) {
            normalizeWindowSelection()
        }
        .preferredColorScheme(viewModel.appTheme.colorScheme)
    }

    private var noCamerasEmptyState: some View {
        ContentUnavailableView {
            Label("No Cameras", systemImage: "video.badge.plus")
        } description: {
            Text("Add a camera to start building your security view.")
        } actions: {
            Button(action: startAddingCamera) {
                Label("Add Camera", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section {
                if viewModel.cameras.isEmpty {
                    Text("No Cameras")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.cameras) { camera in
                        HStack {
                            Image(systemName: cameraSidebarIconName(for: camera))
                                .foregroundStyle(.secondary)
                            Text(camera.displayName)
                                .foregroundStyle(camera.isEnabled ? .primary : .secondary)
                            Spacer()
                            if !camera.isEnabled {
                                Image(systemName: "pause.circle")
                                    .foregroundStyle(.secondary)
                            } else if viewModel.isQuietHoursActive {
                                Image(systemName: "moon.fill")
                                    .foregroundStyle(.secondary)
                            } else {
                                AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                            }
                        }
                        .opacity(camera.isEnabled ? 1 : 0.55)
                        .contentShape(Rectangle())
                        .tag(SidebarItem.camera(camera.id))
                        .contextMenu {
                            Button("Edit") {
                                settingsInitialCameraID = camera.id
                                settingsStartsAddingCamera = false
                                showingSettings = true
                            }

                            Button("Delete", role: .destructive) {
                                viewModel.deleteCamera(camera)
                            }
                        }
                        .background(
                            AvailabilityProbe(camera: camera, isPaused: viewModel.isQuietHoursActive) { isAvailable in
                                viewModel.updateProbeAvailability(for: camera.id, isAvailable: isAvailable)
                            }
                        )
                    }
                }
            } header: {
                SidebarSectionHeader(title: "Cameras", addLabel: "Add Camera", onAdd: startAddingCamera)
            }

            Section {
                ForEach(viewModel.grids) { grid in
                    Text(grid.title)
                        .tag(SidebarItem.grid(grid.id))
                        .contextMenu {
                            Button("Edit Grid") {
                                startEditingGrid(grid)
                            }

                            Button("Delete Grid", role: .destructive) {
                                viewModel.deleteGrid(grid)
                            }
                            .disabled(viewModel.grids.count <= 1)
                        }
                }
            } header: {
                SidebarSectionHeader(title: "Grids", addLabel: "Add Grid", onAdd: startNewGrid)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
#if os(iOS)
        .navigationTitle("Cameras")
#endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
#if os(macOS)
                    openSettings()
#else
                    showingSettings = true
#endif
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    private var quietHoursToolbarTitle: String {
        viewModel.isQuietHoursActive ? "Turn Off Quiet Hours" : "Turn On Quiet Hours"
    }

    private func startAddingCamera() {
        settingsInitialCameraID = nil
        settingsStartsAddingCamera = true
        showingSettings = true
    }

    private func startNewGrid() {
        editingGrid = nil
        showingNewGridSheet = true
    }

    private func startEditingGrid(_ grid: GridLayout) {
        editingGrid = grid
        showingNewGridSheet = true
    }

    private func cameraSidebarIconName(for camera: CameraConfig) -> String {
        switch camera.feedMode {
        case .snapshotPolling:
            return "photo"
        case .rtsp:
            return "video"
        }
    }

    private var selectionBinding: Binding<SidebarItem?> {
        Binding {
            selectedSidebarItem
        } set: { newValue in
            selectSidebarItem(newValue)
        }
    }

    private var selectedCamera: CameraConfig? {
        guard case let .camera(cameraID) = selectedSidebarItem else { return nil }
        return viewModel.cameras.first { $0.id == cameraID }
    }

    private var selectedGrid: GridLayout? {
        guard case let .grid(gridID) = selectedSidebarItem else { return nil }
        return viewModel.grids.first { $0.id == gridID }
    }

    private func selectSidebarItem(_ item: SidebarItem?) {
        let normalizedItem = normalizedSidebarItem(item)
        selectedSidebarItem = normalizedItem
        persistSelectedSidebarItem(normalizedItem)
    }

    private func normalizeWindowSelection() {
        let normalizedItem = normalizedSidebarItem(selectedSidebarItem)
        guard normalizedItem != selectedSidebarItem else { return }
        selectedSidebarItem = normalizedItem
    }

    private func normalizedSidebarItem(_ item: SidebarItem?) -> SidebarItem? {
        guard !viewModel.cameras.isEmpty else { return nil }
        guard let item else { return nil }
        switch item {
        case .camera(let cameraID):
            return viewModel.cameras.contains { $0.id == cameraID } ? item : nil
        case .grid(let gridID):
            return viewModel.grids.contains { $0.id == gridID } ? item : nil
        }
    }

    private func persistSelectedSidebarItem(_ item: SidebarItem?) {
        DispatchQueue.main.async {
            guard selectedSidebarItem == item else { return }
            viewModel.selectedSidebarItem = item
        }
    }
}

private struct SidebarSectionHeader: View {
    let title: LocalizedStringKey
    let addLabel: LocalizedStringKey
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: onAdd) {
                Label(addLabel, systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help(addLabel)
            .padding(.trailing, 8)
        }
    }
}
