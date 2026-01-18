//
//  AppViewModel.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @AppStorage("camerasJSON") private var camerasJSON: String = "[]"

    @Published var cameras: [CameraConfig] = [] {
        didSet {
            persistCameras()
            reconcileSelectionAndAvailability()
        }
    }
    @Published var showSettings = false
    @Published var selectedCameraID: CameraConfig.ID?
    @Published var availability: [CameraConfig.ID: Bool] = [:]

    init() {
        loadCameras()
    }

    var selectedCamera: CameraConfig? {
        guard let selectedCameraID else { return nil }
        return cameras.first { $0.id == selectedCameraID }
    }

    func updateAvailability(for cameraID: CameraConfig.ID, isAvailable: Bool) {
        availability[cameraID] = isAvailable
    }

    func deleteCameras(at offsets: IndexSet) {
        cameras.remove(atOffsets: offsets)
    }

    func deleteCamera(_ camera: CameraConfig) {
        cameras.removeAll { $0.id == camera.id }
    }

    func addCamera(from draft: CameraConfig) {
        let trimmedHost = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let camera = CameraConfig(
            name: trimmedName,
            host: trimmedHost,
            username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: draft.password,
            channel: draft.channel,
            useHTTPS: draft.useHTTPS
        )
        cameras.append(camera)
    }

    private func loadCameras() {
        guard let data = camerasJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CameraConfig].self, from: data) else {
            return
        }
        cameras = decoded
    }

    private func persistCameras() {
        guard let data = try? JSONEncoder().encode(cameras),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        camerasJSON = json
    }

    private func reconcileSelectionAndAvailability() {
        let ids = Set(cameras.map(\.id))
        availability = availability.filter { ids.contains($0.key) }
        if let selectedCameraID, !ids.contains(selectedCameraID) {
            self.selectedCameraID = nil
        }
    }
}
