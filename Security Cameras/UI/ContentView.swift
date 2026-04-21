//
//  ContentView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
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
                                Spacer()
                                AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                            }
                            .contentShape(Rectangle())
                            .tag(SidebarItem.camera(camera.id))
                            .background(
                                AvailabilityProbe(url: camera.snapshotURL) { isAvailable in
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
        //.windowToolbarFullScreenVisibility(.onHover)
        .sheet(isPresented: $viewModel.showSettings) {
            CameraSettingsView(viewModel: viewModel)
        }
    }
}
