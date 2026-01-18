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
            if viewModel.cameras.isEmpty {
                ContentUnavailableView(
                    "No Cameras",
                    systemImage: "video",
                    description: Text("Open Settings to add your first IP camera.")
                )
            } else {
                List(viewModel.cameras, selection: $viewModel.selectedCameraID) { camera in
                    HStack {
                        Text(camera.displayName)
                        Spacer()
                        AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                    }
                    .contentShape(Rectangle())
                    .tag(camera.id)
                    .background(
                        AvailabilityProbe(url: camera.snapshotURL) { isAvailable in
                            viewModel.updateAvailability(for: camera.id, isAvailable: isAvailable)
                        }
                    )
                }
            }
        } detail: {
            if let selectedCamera = viewModel.selectedCamera {
                CameraDetailView(camera: selectedCamera)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Select a Camera",
                    systemImage: "video",
                    description: Text("Choose a camera from the sidebar.")
                )
            }
        }
        .navigationTitle("Security Cameras")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
