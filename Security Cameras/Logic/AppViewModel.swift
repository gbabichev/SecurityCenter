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
    @AppStorage("gridAssignmentsJSON") private var gridAssignmentsJSON: String = "{}"

    @Published var cameras: [CameraConfig] = [] {
        didSet {
            persistCameras()
            reconcileSelectionAndAvailability()
        }
    }
    @Published var gridAssignments: [GridOption: [CameraConfig.ID?]] = [:] {
        didSet {
            persistGridAssignments()
        }
    }
    @Published var showSettings = false
    @Published var selectedSidebarItem: SidebarItem?
    @Published var availability: [CameraConfig.ID: Bool] = [:]

    init() {
        loadCameras()
        loadGridAssignments()
    }

    var selectedCamera: CameraConfig? {
        guard case let .camera(cameraID) = selectedSidebarItem else { return nil }
        return cameras.first { $0.id == cameraID }
    }

    var selectedGridOption: GridOption? {
        guard case let .grid(option) = selectedSidebarItem else { return nil }
        return option
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

    func gridCameraID(option: GridOption, index: Int) -> CameraConfig.ID? {
        normalizedGridAssignments(option: option)[safe: index] ?? nil
    }

    func setGridCameraID(option: GridOption, index: Int, cameraID: CameraConfig.ID?) {
        var assignments = normalizedGridAssignments(option: option)
        guard assignments.indices.contains(index) else { return }
        assignments[index] = cameraID
        gridAssignments[option] = assignments
    }

    private func loadCameras() {
        guard let data = camerasJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CameraConfig].self, from: data) else {
            return
        }
        cameras = decoded
    }

    private func loadGridAssignments() {
        guard let data = gridAssignmentsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GridAssignmentsPayload.self, from: data) else {
            gridAssignments = [:]
            return
        }
        gridAssignments = decoded.assignments
    }

    private func persistCameras() {
        guard let data = try? JSONEncoder().encode(cameras),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        camerasJSON = json
    }

    private func persistGridAssignments() {
        let payload = GridAssignmentsPayload(assignments: gridAssignments)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        gridAssignmentsJSON = json
    }

    private func reconcileSelectionAndAvailability() {
        let ids = Set(cameras.map(\.id))
        availability = availability.filter { ids.contains($0.key) }
        if case let .camera(cameraID) = selectedSidebarItem, !ids.contains(cameraID) {
            selectedSidebarItem = nil
        }
        gridAssignments = normalizedGridAssignments(removing: ids)
    }

    private func normalizedGridAssignments(option: GridOption) -> [CameraConfig.ID?] {
        var current = gridAssignments[option] ?? []
        let targetCount = option.maxItems
        if current.count < targetCount {
            current.append(contentsOf: Array(repeating: nil, count: targetCount - current.count))
        } else if current.count > targetCount {
            current = Array(current.prefix(targetCount))
        }
        return current
    }

    private func normalizedGridAssignments(removing validIDs: Set<CameraConfig.ID>) -> [GridOption: [CameraConfig.ID?]] {
        var normalized: [GridOption: [CameraConfig.ID?]] = [:]
        for option in GridOption.allCases {
            var assignments = normalizedGridAssignments(option: option)
            for index in assignments.indices {
                if let id = assignments[index], !validIDs.contains(id) {
                    assignments[index] = nil
                }
            }
            normalized[option] = assignments
        }
        return normalized
    }
}

private struct GridAssignmentsPayload: Codable {
    let assignments: [GridOption: [CameraConfig.ID?]]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
