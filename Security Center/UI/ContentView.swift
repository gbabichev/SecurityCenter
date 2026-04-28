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
    @State private var showingConfigurationTransfer = false
#endif
    @State private var showingNewGridSheet = false
    @State private var editingGrid: GridLayout?
    @State private var settingsInitialCameraID: CameraConfig.ID?
    @State private var settingsStartsAddingCamera = false
    @State private var newGridName = ""
    @State private var newGridColumns = 2
    @State private var newGridRows = 2

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
                startsAddingCamera: settingsStartsAddingCamera
            )
        }
        .sheet(isPresented: $showingNewGridSheet) {
            newGridSheet
        }
#if os(macOS)
        .sheet(isPresented: $showingConfigurationTransfer) {
            ConfigurationTransferView(viewModel: viewModel)
        }
        .focusedValue(\.showConfigurationTransferAction) {
            showingConfigurationTransfer = true
        }
#endif
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
            Button {
                settingsInitialCameraID = nil
                settingsStartsAddingCamera = true
                showingSettings = true
            } label: {
                Label("Add Camera", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section("Cameras") {
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
                HStack {
                    Text("Grids")
                    Spacer()
                    Button {
                        startNewGrid()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
#if os(iOS)
        .navigationTitle("Cameras")
#endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    private var quietHoursToolbarTitle: String {
        viewModel.isQuietHoursActive ? "Turn Off Quiet Hours" : "Turn On Quiet Hours"
    }

    private var newGridSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(editingGrid == nil ? "New Grid" : "Edit Grid")
                    .font(.title2.weight(.semibold))
                Text(editingGrid == nil ? "Create a saved grid layout for your cameras." : "Update this saved grid layout.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Grid Setup", subtitle: "Name it if you want, then choose the layout size.")

                VStack(alignment: .leading, spacing: 14) {
                    fieldBlock(title: "Name", caption: "Optional label shown in the sidebar.") {
                        TextField("2x2", text: $newGridName)
                            .textFieldStyle(.roundedBorder)
                    }

#if os(macOS)
                    HStack(alignment: .top, spacing: 12) {
                        stepperField(title: "Columns", value: $newGridColumns)
                        stepperField(title: "Rows", value: $newGridRows)
                    }
#else
                    VStack(spacing: 12) {
                        stepperField(title: "Columns", value: $newGridColumns)
                        stepperField(title: "Rows", value: $newGridRows)
                    }
#endif
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
            )

            HStack {
                Spacer()

                Button("Cancel") {
                    dismissGridSheet()
                }
                .buttonStyle(.bordered)

                Button(editingGrid == nil ? "Create" : "Save") {
                    if let grid = editingGrid {
                        let updatedGrid = viewModel.updateGrid(grid, name: newGridName, columns: newGridColumns, rows: newGridRows)
                        selectSidebarItem(.grid(updatedGrid.id))
                    } else {
                        let grid = viewModel.addGrid(name: newGridName, columns: newGridColumns, rows: newGridRows)
                        selectSidebarItem(.grid(grid.id))
                    }
                    dismissGridSheet()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
#if os(macOS)
        .frame(width: 520)
#endif
        .presentationDetents([.medium])
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func fieldBlock<Content: View>(title: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepperField(title: String, value: Binding<Int>) -> some View {
        fieldBlock(title: title, caption: "Choose how many \(title.lowercased()) this grid uses.") {
            HStack(spacing: 12) {
                Stepper(title, value: value, in: 1...6)
                    .labelsHidden()

                Text("\(value.wrappedValue)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 28, alignment: .center)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func startNewGrid() {
        editingGrid = nil
        newGridName = ""
        newGridColumns = 2
        newGridRows = 2
        showingNewGridSheet = true
    }

    private func startEditingGrid(_ grid: GridLayout) {
        editingGrid = grid
        newGridName = grid.name
        newGridColumns = grid.columns
        newGridRows = grid.rows
        showingNewGridSheet = true
    }

    private func dismissGridSheet() {
        showingNewGridSheet = false
        editingGrid = nil
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
