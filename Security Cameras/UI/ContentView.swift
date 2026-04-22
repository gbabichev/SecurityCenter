//
//  ContentView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

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
            List(selection: $viewModel.selectedSidebarItem) {
                Section("Cameras") {
                    if viewModel.cameras.isEmpty {
                        Text("No Cameras")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.cameras) { camera in
                            HStack {
                                Text(camera.displayName)
                                    .foregroundStyle(camera.isEnabled ? .primary : .secondary)
                                Spacer()
                                if camera.isEnabled {
                                    AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                                } else {
                                    Image(systemName: "pause.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .opacity(camera.isEnabled ? 1 : 0.55)
                            .contentShape(Rectangle())
                            .tag(SidebarItem.camera(camera.id))
                            .background(
                                AvailabilityProbe(camera: camera) { isAvailable in
                                    viewModel.updateAvailability(for: camera.id, isAvailable: isAvailable)
                                }
                            )
                        }
                    }
                }

                Section("Grids") {
                    ForEach(GridOption.allCases) { option in
                        Text(option.title)
                            .tag(SidebarItem.grid(option))
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let selectedCamera = viewModel.selectedCamera {
                    CameraDetailView(viewModel: viewModel, camera: selectedCamera)
                        .ignoresSafeArea()
                } else if let selectedGrid = viewModel.selectedGridOption {
                    GridDetailView(viewModel: viewModel, option: selectedGrid)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Select a Camera",
                        systemImage: "video",
                        description: Text("Choose a camera from the sidebar.")
                    )
                }
            }
        }
        .navigationTitle("Security Cameras")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            CameraSettingsView(viewModel: viewModel)
        }
    }
}
