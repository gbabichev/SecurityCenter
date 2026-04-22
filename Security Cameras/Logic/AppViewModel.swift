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
    @AppStorage("gridPictureStyle") private var gridPictureStyleRaw = GridPictureStyle.fillEachBox.rawValue
    private var isLoading = true

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
    @Published var gridPictureStyle: GridPictureStyle = .fillEachBox {
        didSet {
            gridPictureStyleRaw = gridPictureStyle.rawValue
        }
    }
    @Published var showSettings = false
    @Published var selectedSidebarItem: SidebarItem?
    @Published var availability: [CameraConfig.ID: Bool] = [:]

    init() {
        loadGridAssignments()
        loadCameras()
        gridPictureStyle = GridPictureStyle(rawValue: gridPictureStyleRaw) ?? .fillEachBox
        isLoading = false
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

    func exportConfigurationData() throws -> Data {
        let payload = AppConfigurationPayload(
            version: 1,
            cameras: cameras,
            gridAssignments: gridAssignments.reduce(into: [:]) { result, item in
                result[item.key.rawValue] = item.value
            },
            gridPictureStyle: gridPictureStyle
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    func importConfigurationData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(AppConfigurationPayload.self, from: data)

        cameras = payload.cameras
        gridAssignments = payload.gridAssignments.reduce(into: [:]) { result, item in
            if let option = GridOption(rawValue: item.key) {
                result[option] = item.value
            }
        }
        gridPictureStyle = payload.gridPictureStyle
        availability = [:]
        selectedSidebarItem = cameras.first.map { .camera($0.id) }
    }

    func validateAndSaveCamera(from draft: CameraConfig, editing existingID: CameraConfig.ID? = nil) async throws -> CameraConfig {
        var camera = draft.sanitized
        if let existingID {
            camera.id = existingID
        }

        try await validateCamera(camera, ignoring: existingID)

        if let index = cameras.firstIndex(where: { $0.id == camera.id }) {
            cameras[index] = camera
        } else {
            cameras.append(camera)
        }
        availability[camera.id] = camera.isEnabled
        return camera
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
        var assignments: [GridOption: [CameraConfig.ID?]] = [:]
        for (key, value) in decoded.assignments {
            if let option = GridOption(rawValue: key) {
                assignments[option] = value
            }
        }
        gridAssignments = assignments
    }

    private func persistCameras() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(cameras),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        camerasJSON = json
    }

    private func persistGridAssignments() {
        guard !isLoading else { return }
        var rawAssignments: [String: [CameraConfig.ID?]] = [:]
        for (option, value) in gridAssignments {
            rawAssignments[option.rawValue] = value
        }
        let payload = GridAssignmentsPayload(assignments: rawAssignments)
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

    private func validateCamera(_ camera: CameraConfig, ignoring ignoredID: CameraConfig.ID?) async throws {
        guard !camera.host.isEmpty else {
            throw CameraValidationError.missingHost
        }
        guard validationURL(for: camera) != nil else {
            throw CameraValidationError.invalidURL
        }
        guard !cameras.contains(where: { existing in
            existing.id != ignoredID
                && existing.id != camera.id
                && existing.host.caseInsensitiveCompare(camera.host) == .orderedSame
                && existing.channel == camera.channel
                && existing.feedMode == camera.feedMode
                && (camera.feedMode == .rtsp || existing.useHTTPS == camera.useHTTPS)
        }) else {
            throw CameraValidationError.duplicateCamera
        }

        guard camera.isEnabled else { return }

        switch camera.feedMode {
        case .snapshotPolling:
            try await validateSnapshotCamera(camera)
        case .rtsp:
            try await RTSPConnectionService.validate(camera: camera)
        }
    }

    private func validationURL(for camera: CameraConfig) -> URL? {
        switch camera.feedMode {
        case .snapshotPolling:
            camera.snapshotURL
        case .rtsp:
            camera.rtspURL
        }
    }

    private func validateSnapshotCamera(_ camera: CameraConfig) async throws {
        guard let url = camera.snapshotURL else {
            throw CameraValidationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await CameraNetworkSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CameraValidationError.invalidResponse
            }
            switch http.statusCode {
            case 200...299:
                break
            case 401, 403:
                throw CameraValidationError.unauthorized
            default:
                throw CameraValidationError.unexpectedStatus(http.statusCode)
            }
            if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
               contentType.localizedCaseInsensitiveContains("image/") {
                return
            }
            guard data.isJPEG else {
                throw CameraValidationError.invalidResponse
            }
        } catch let error as CameraValidationError {
            throw error
        } catch {
            throw CameraValidationError.transport(error.localizedDescription)
        }
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
    let assignments: [String: [CameraConfig.ID?]]
}

private struct AppConfigurationPayload: Codable {
    let version: Int
    let cameras: [CameraConfig]
    let gridAssignments: [String: [CameraConfig.ID?]]
    let gridPictureStyle: GridPictureStyle
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
