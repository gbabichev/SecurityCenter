//
//  ContentView.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingNewGridSheet = false
    @State private var newGridName = ""
    @State private var newGridColumns = 2
    @State private var newGridRows = 2

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
                if let selectedCamera = viewModel.selectedCamera {
                    CameraDetailView(viewModel: viewModel, camera: selectedCamera)
                } else if let selectedGrid = viewModel.selectedGrid {
                    GridDetailView(viewModel: viewModel, layout: selectedGrid)
                } else {
                    ContentUnavailableView(
                        "Select a Camera",
                        systemImage: "video",
                        description: Text("Choose a camera from the sidebar.")
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            CameraSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingNewGridSheet) {
            newGridSheet
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedSidebarItem) {
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
                        .background(
                            AvailabilityProbe(camera: camera, isPaused: viewModel.isQuietHoursActive) { isAvailable in
                                viewModel.updateAvailability(for: camera.id, isAvailable: isAvailable)
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
                    viewModel.showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    private var newGridSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Grid")
                    .font(.title2.weight(.semibold))
                Text("Create a saved grid layout for your cameras.")
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
                    showingNewGridSheet = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    let grid = viewModel.addGrid(name: newGridName, columns: newGridColumns, rows: newGridRows)
                    viewModel.selectedSidebarItem = .grid(grid.id)
                    showingNewGridSheet = false
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
        newGridName = ""
        newGridColumns = 2
        newGridRows = 2
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
}
