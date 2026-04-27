//
//  AppViewModel.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    private let defaults = UserDefaults.standard
    private var isLoading = true
    private var quietHoursTimer: AnyCancellable?

    private enum StorageKey {
        static let camerasJSON = "camerasJSON"
        static let gridsJSON = "gridsJSON"
        static let gridAssignmentsJSON = "gridAssignmentsJSON"
        static let gridPictureStyle = "gridPictureStyle"
        static let selectedSidebarItem = "selectedSidebarItem"
        static let quietHoursJSON = "quietHoursJSON"
        static let appTheme = "appTheme"
        static let viewBackgroundStyle = "viewBackgroundStyle"
        static let showQuietHoursInToolbar = "showQuietHoursInToolbar"
        static let quietHoursScheduleOverridesManual = "quietHoursScheduleOverridesManual"
    }

    private var usesImplicitDefaultGrid: Bool {
        (defaults.string(forKey: StorageKey.gridsJSON) ?? "").isEmpty
    }

    @Published var cameras: [CameraConfig] = [] {
        didSet {
            persistCameras()
            reconcileSelectionAndAvailability()
        }
    }
    @Published var grids: [GridLayout] = [] {
        didSet {
            persistGrids()
            reconcileSelectionAndAvailability()
        }
    }
    @Published var gridAssignments: [GridLayout.ID: [CameraConfig.ID?]] = [:] {
        didSet {
            persistGridAssignments()
        }
    }
    @Published var gridPictureStyle: GridPictureStyle = .fillEachBox {
        didSet {
            defaults.set(gridPictureStyle.rawValue, forKey: StorageKey.gridPictureStyle)
        }
    }
    @Published var appTheme: AppTheme = .system {
        didSet {
            defaults.set(appTheme.rawValue, forKey: StorageKey.appTheme)
        }
    }
    @Published var viewBackgroundStyle: ViewBackgroundStyle = .systemDefault {
        didSet {
            defaults.set(viewBackgroundStyle.rawValue, forKey: StorageKey.viewBackgroundStyle)
        }
    }
    @Published var quietHours = QuietHoursSchedule() {
        didSet {
            persistQuietHours()
            refreshQuietHoursState()
        }
    }
    @Published var showQuietHoursInToolbar = false {
        didSet {
            defaults.set(showQuietHoursInToolbar, forKey: StorageKey.showQuietHoursInToolbar)
            if !showQuietHoursInToolbar {
                quietHoursManualOverride = nil
                refreshQuietHoursState()
            }
        }
    }
    @Published var quietHoursScheduleOverridesManual = false {
        didSet {
            defaults.set(quietHoursScheduleOverridesManual, forKey: StorageKey.quietHoursScheduleOverridesManual)
            refreshQuietHoursState()
        }
    }
    @Published var showSettings = false
    @Published var selectedSidebarItem: SidebarItem? {
        didSet {
            persistSelectedSidebarItem()
        }
    }
    @Published var availability: [CameraConfig.ID: Bool] = [:]
    @Published private(set) var isQuietHoursActive = false
    private var quietHoursManualOverride: Bool?
    private var lastScheduledQuietHoursActive: Bool?
    private var playbackAvailabilityOverrides: [CameraConfig.ID: Bool] = [:]

    init() {
        loadGrids()
        loadGridAssignments()
        loadCameras()
        loadQuietHours()
        showQuietHoursInToolbar = defaults.bool(forKey: StorageKey.showQuietHoursInToolbar)
        quietHoursScheduleOverridesManual = defaults.bool(forKey: StorageKey.quietHoursScheduleOverridesManual)
        appTheme = AppTheme(rawValue: defaults.string(forKey: StorageKey.appTheme) ?? AppTheme.system.rawValue) ?? .system
        viewBackgroundStyle = ViewBackgroundStyle(
            rawValue: defaults.string(forKey: StorageKey.viewBackgroundStyle) ?? ViewBackgroundStyle.systemDefault.rawValue
        ) ?? .systemDefault
        gridPictureStyle = GridPictureStyle(
            rawValue: defaults.string(forKey: StorageKey.gridPictureStyle) ?? GridPictureStyle.fillEachBox.rawValue
        ) ?? .fillEachBox
        restoreSelectedSidebarItem()
        quietHoursTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshQuietHoursState()
            }
        refreshQuietHoursState()
        isLoading = false
    }

    var selectedCamera: CameraConfig? {
        guard case let .camera(cameraID) = selectedSidebarItem else { return nil }
        return cameras.first { $0.id == cameraID }
    }

    var selectedGrid: GridLayout? {
        guard case let .grid(gridID) = selectedSidebarItem else { return nil }
        return grids.first { $0.id == gridID }
    }

    var quietHoursSaverEndLabel: String? {
        quietHoursManualOverride == true && !quietHoursScheduleOverridesManual ? nil : quietHours.endLabel
    }

    func updateProbeAvailability(for cameraID: CameraConfig.ID, isAvailable: Bool) {
        if let playbackAvailability = playbackAvailabilityOverrides[cameraID] {
            availability[cameraID] = playbackAvailability
            return
        }
        availability[cameraID] = isAvailable
    }

    func updatePlaybackAvailability(for cameraID: CameraConfig.ID, status: SnapshotStatus) {
        let isAvailable = status == .ok
        playbackAvailabilityOverrides[cameraID] = isAvailable
        availability[cameraID] = isAvailable
    }

    func clearPlaybackAvailability(for cameraID: CameraConfig.ID) {
        playbackAvailabilityOverrides[cameraID] = nil
    }

    func deleteCamera(_ camera: CameraConfig) {
        cameras.removeAll { $0.id == camera.id }
    }

    func addGrid(name: String = "", columns: Int, rows: Int) -> GridLayout {
        let grid = GridLayout(name: name, columns: columns, rows: rows)
        grids.append(grid)
        selectedSidebarItem = .grid(grid.id)
        return grid
    }

    func updateGrid(_ grid: GridLayout, name: String, columns: Int, rows: Int) -> GridLayout {
        let updatedGrid = GridLayout(id: grid.id, name: name, columns: columns, rows: rows)
        guard let index = grids.firstIndex(where: { $0.id == grid.id }) else {
            return updatedGrid
        }

        grids[index] = updatedGrid

        var assignments = gridAssignments[grid.id] ?? []
        let targetCount = updatedGrid.maxItems
        if assignments.count < targetCount {
            assignments.append(contentsOf: Array(repeating: nil, count: targetCount - assignments.count))
        } else if assignments.count > targetCount {
            assignments = Array(assignments.prefix(targetCount))
        }
        gridAssignments[grid.id] = assignments
        selectedSidebarItem = .grid(updatedGrid.id)
        return updatedGrid
    }

    func deleteGrid(_ grid: GridLayout) {
        guard grids.count > 1 else { return }
        grids.removeAll { $0.id == grid.id }
    }

    func duplicateCamera(_ camera: CameraConfig) -> CameraConfig {
        var copy = camera
        copy.id = UUID()
        let trimmedName = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = trimmedName.isEmpty ? "Camera Copy" : "\(trimmedName) Copy"
        cameras.append(copy)
        availability[copy.id] = copy.isEnabled
        return copy
    }

    func updateQuietHours(enabled: Bool) {
        quietHours.isEnabled = enabled
    }

    func updateQuietHours(startMinutes: Int) {
        quietHours.startMinutes = startMinutes
    }

    func updateQuietHours(endMinutes: Int) {
        quietHours.endMinutes = endMinutes
    }

    func toggleManualQuietHours() {
        guard showQuietHoursInToolbar else { return }
        quietHoursManualOverride = isQuietHoursActive ? false : true
        refreshQuietHoursState()
    }

    func exportConfigurationData() throws -> Data {
        let payload = AppConfigurationPayload(
            cameras: cameras,
            grids: grids,
            gridAssignments: gridAssignments.reduce(into: [:]) { result, item in
                result[item.key.uuidString] = item.value
            },
            gridPictureStyle: gridPictureStyle,
            appTheme: appTheme,
            viewBackgroundStyle: viewBackgroundStyle,
            showQuietHoursInToolbar: showQuietHoursInToolbar,
            quietHoursScheduleOverridesManual: quietHoursScheduleOverridesManual,
            quietHours: quietHours
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    func importConfigurationData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(AppConfigurationPayload.self, from: data)
        let importedGridState = importedGridState(from: payload)

        cameras = payload.cameras
        grids = importedGridState.grids
        gridAssignments = importedGridState.assignments
        gridPictureStyle = payload.gridPictureStyle
        appTheme = payload.appTheme ?? .system
        viewBackgroundStyle = payload.viewBackgroundStyle ?? .systemDefault
        showQuietHoursInToolbar = payload.showQuietHoursInToolbar ?? false
        quietHoursScheduleOverridesManual = payload.quietHoursScheduleOverridesManual ?? false
        quietHours = payload.quietHours ?? QuietHoursSchedule()
        availability = [:]
        playbackAvailabilityOverrides = [:]
        restoreSelectedSidebarItem()
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

    func gridCameraID(layout: GridLayout, index: Int) -> CameraConfig.ID? {
        normalizedGridAssignments(layout: layout)[safe: index] ?? nil
    }

    func setGridCameraID(layout: GridLayout, index: Int, cameraID: CameraConfig.ID?) {
        var assignments = normalizedGridAssignments(layout: layout)
        guard assignments.indices.contains(index) else { return }
        assignments[index] = cameraID
        gridAssignments[layout.id] = assignments
    }

    private func loadCameras() {
        let rawValue = defaults.string(forKey: StorageKey.camerasJSON) ?? "[]"
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CameraConfig].self, from: data) else {
            return
        }
        cameras = decoded
    }

    private func loadGrids() {
        let rawValue = defaults.string(forKey: StorageKey.gridsJSON) ?? ""
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([GridLayout].self, from: data),
              !decoded.isEmpty else {
            grids = [.defaultGrid]
            return
        }
        grids = decoded
    }

    private func loadGridAssignments() {
        let rawValue = defaults.string(forKey: StorageKey.gridAssignmentsJSON) ?? "{}"
        guard let data = rawValue.data(using: .utf8) else {
            gridAssignments = [:]
            return
        }

        if let decoded = try? JSONDecoder().decode(GridAssignmentsPayload.self, from: data) {
            var assignments: [GridLayout.ID: [CameraConfig.ID?]] = [:]
            for (key, value) in decoded.assignments {
                if let gridID = UUID(uuidString: key) {
                    assignments[gridID] = value
                }
            }
            if usesImplicitDefaultGrid,
               assignments[GridLayout.defaultGridID] == nil,
               let legacyDefaultAssignments = assignments.first?.value,
               assignments.count == 1 {
                assignments = [GridLayout.defaultGridID: legacyDefaultAssignments]
            }
            gridAssignments = assignments
            return
        }

        if let decoded = try? JSONDecoder().decode(LegacyGridAssignmentsPayload.self, from: data) {
            migrateLegacyGridAssignments(decoded.assignments)
            return
        }

        gridAssignments = [:]
    }

    private func loadQuietHours() {
        let rawValue = defaults.string(forKey: StorageKey.quietHoursJSON) ?? ""
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(QuietHoursSchedule.self, from: data) else {
            quietHours = QuietHoursSchedule()
            return
        }
        quietHours = decoded
    }

    private func persistCameras() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(cameras),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(json, forKey: StorageKey.camerasJSON)
    }

    private func persistGrids() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(grids),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(json, forKey: StorageKey.gridsJSON)
    }

    private func persistGridAssignments() {
        guard !isLoading else { return }
        var rawAssignments: [String: [CameraConfig.ID?]] = [:]
        for (gridID, value) in gridAssignments {
            rawAssignments[gridID.uuidString] = value
        }
        let payload = GridAssignmentsPayload(assignments: rawAssignments)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(json, forKey: StorageKey.gridAssignmentsJSON)
    }

    private func persistSelectedSidebarItem() {
        guard !isLoading else { return }
        defaults.set(encodedSidebarItem(selectedSidebarItem), forKey: StorageKey.selectedSidebarItem)
    }

    private func persistQuietHours() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(quietHours),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(json, forKey: StorageKey.quietHoursJSON)
    }

    private func refreshQuietHoursState(now: Date = Date()) {
        let scheduledQuietHoursActive = quietHours.isActive(at: now)
        if quietHoursScheduleOverridesManual,
           let lastScheduledQuietHoursActive,
           lastScheduledQuietHoursActive != scheduledQuietHoursActive {
            quietHoursManualOverride = nil
        }
        lastScheduledQuietHoursActive = scheduledQuietHoursActive
        if quietHoursScheduleOverridesManual && quietHoursManualOverride == false && scheduledQuietHoursActive {
            quietHoursManualOverride = nil
        }
        if quietHoursManualOverride == false && !scheduledQuietHoursActive {
            quietHoursManualOverride = nil
        }
        isQuietHoursActive = quietHoursManualOverride ?? scheduledQuietHoursActive
    }

    private func restoreSelectedSidebarItem() {
        let rawValue = defaults.string(forKey: StorageKey.selectedSidebarItem) ?? ""
        selectedSidebarItem = normalizedSidebarItem(decodedSidebarItem(rawValue))
    }

    private func reconcileSelectionAndAvailability() {
        let ids = Set(cameras.map(\.id))
        availability = availability.filter { ids.contains($0.key) }
        playbackAvailabilityOverrides = playbackAvailabilityOverrides.filter { ids.contains($0.key) }
        selectedSidebarItem = normalizedSidebarItem(selectedSidebarItem)
        gridAssignments = normalizedGridAssignments(removing: ids)
    }

    private func normalizedSidebarItem(_ item: SidebarItem?) -> SidebarItem? {
        guard !cameras.isEmpty else { return nil }
        guard let item else { return nil }
        switch item {
        case .camera(let cameraID):
            return cameras.contains(where: { $0.id == cameraID }) ? item : nil
        case .grid(let gridID):
            if grids.contains(where: { $0.id == gridID }) {
                return item
            }
            if usesImplicitDefaultGrid,
               grids.count == 1,
               grids.first?.id == GridLayout.defaultGridID {
                return .grid(GridLayout.defaultGridID)
            }
            return nil
        }
    }

    private func encodedSidebarItem(_ item: SidebarItem?) -> String {
        guard let item else { return "" }
        switch item {
        case .camera(let cameraID):
            return "camera:\(cameraID.uuidString)"
        case .grid(let gridID):
            return "grid:\(gridID.uuidString)"
        }
    }

    private func decodedSidebarItem(_ rawValue: String) -> SidebarItem? {
        guard !rawValue.isEmpty else { return nil }
        let parts = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        switch parts[0] {
        case "camera":
            guard let cameraID = UUID(uuidString: parts[1]) else { return nil }
            return .camera(cameraID)
        case "grid":
            guard let gridID = UUID(uuidString: parts[1]) else { return nil }
            return .grid(gridID)
        default:
            return nil
        }
    }

    private func importedGridState(from payload: AppConfigurationPayload) -> (grids: [GridLayout], assignments: [GridLayout.ID: [CameraConfig.ID?]]) {
        if let grids = payload.grids, !grids.isEmpty {
            let assignments = payload.gridAssignments.reduce(into: [GridLayout.ID: [CameraConfig.ID?]]()) { result, item in
                if let gridID = UUID(uuidString: item.key) {
                    result[gridID] = item.value
                }
            }
            return (grids, assignments)
        }

        var migratedGrids: [GridLayout] = []
        var migratedAssignments: [GridLayout.ID: [CameraConfig.ID?]] = [:]
        for option in LegacyGridOption.allCases {
            guard let assignments = payload.gridAssignments[option.rawValue] else { continue }
            let grid = option.layout
            migratedGrids.append(grid)
            migratedAssignments[grid.id] = assignments
        }

        if !migratedGrids.isEmpty {
            return (migratedGrids, migratedAssignments)
        }

        return ([.defaultGrid], [:])
    }

    private func migrateLegacyGridAssignments(_ legacyAssignments: [String: [CameraConfig.ID?]]) {
        guard defaults.string(forKey: StorageKey.gridsJSON) == nil else {
            gridAssignments = [:]
            return
        }

        var migratedGrids: [GridLayout] = []
        var migratedAssignments: [GridLayout.ID: [CameraConfig.ID?]] = [:]

        for option in LegacyGridOption.allCases {
            guard let assignments = legacyAssignments[option.rawValue] else { continue }
            let grid = option.layout
            migratedGrids.append(grid)
            migratedAssignments[grid.id] = assignments
        }

        grids = migratedGrids.isEmpty ? [.defaultGrid] : migratedGrids
        gridAssignments = migratedAssignments
    }

    private func validateCamera(_ camera: CameraConfig, ignoring ignoredID: CameraConfig.ID?) async throws {
        switch camera.kind {
        case .reolink:
            guard !camera.host.isEmpty else {
                throw CameraValidationError.missingHost
            }
        case .genericRTSP:
            guard camera.rtspURL?.host != nil else {
                throw CameraValidationError.invalidURL
            }
        }

        guard validationURL(for: camera) != nil else {
            throw CameraValidationError.invalidURL
        }
        guard !cameras.contains(where: { existing in
            guard existing.id != ignoredID, existing.id != camera.id, existing.kind == camera.kind else {
                return false
            }

            switch camera.kind {
            case .reolink:
                return existing.host.caseInsensitiveCompare(camera.host) == .orderedSame
                    && existing.channel == camera.channel
                    && existing.feedMode == camera.feedMode
                    && (camera.feedMode == .rtsp || existing.useHTTPS == camera.useHTTPS)
            case .genericRTSP:
                return existing.genericRTSPURL.caseInsensitiveCompare(camera.genericRTSPURL) == .orderedSame
            }
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
        do {
            try await performSnapshotValidation(camera: camera, timeout: 8)
        } catch let error as CameraValidationError {
            if let suggestedUseHTTPS = await detectWorkingSnapshotProtocol(for: camera),
               suggestedUseHTTPS != camera.useHTTPS {
                throw CameraValidationError.protocolMismatch(useHTTPS: suggestedUseHTTPS)
            }
            throw error
        } catch {
            if let suggestedUseHTTPS = await detectWorkingSnapshotProtocol(for: camera),
               suggestedUseHTTPS != camera.useHTTPS {
                throw CameraValidationError.protocolMismatch(useHTTPS: suggestedUseHTTPS)
            }
            throw CameraValidationError.transport(error.localizedDescription)
        }
    }

    private func performSnapshotValidation(camera: CameraConfig, timeout: TimeInterval) async throws {
        guard let url = camera.snapshotURL else {
            throw CameraValidationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("image/*", forHTTPHeaderField: "Accept")

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
    }

    private func detectWorkingSnapshotProtocol(for camera: CameraConfig) async -> Bool? {
        guard camera.kind == .reolink else { return nil }

        var alternateCamera = camera
        alternateCamera.useHTTPS.toggle()

        do {
            try await performSnapshotValidation(camera: alternateCamera, timeout: 4)
            return alternateCamera.useHTTPS
        } catch {
            return nil
        }
    }

    private func normalizedGridAssignments(layout: GridLayout) -> [CameraConfig.ID?] {
        var current = gridAssignments[layout.id] ?? []
        let targetCount = layout.maxItems
        if current.count < targetCount {
            current.append(contentsOf: Array(repeating: nil, count: targetCount - current.count))
        } else if current.count > targetCount {
            current = Array(current.prefix(targetCount))
        }
        return current
    }

    private func normalizedGridAssignments(removing validIDs: Set<CameraConfig.ID>) -> [GridLayout.ID: [CameraConfig.ID?]] {
        var normalized: [GridLayout.ID: [CameraConfig.ID?]] = [:]
        for layout in grids {
            var assignments = normalizedGridAssignments(layout: layout)
            for index in assignments.indices {
                if let id = assignments[index], !validIDs.contains(id) {
                    assignments[index] = nil
                }
            }
            normalized[layout.id] = assignments
        }
        return normalized
    }
}

private struct GridAssignmentsPayload: Codable {
    let assignments: [String: [CameraConfig.ID?]]
}

private struct AppConfigurationPayload: Codable {
    let cameras: [CameraConfig]
    let grids: [GridLayout]?
    let gridAssignments: [String: [CameraConfig.ID?]]
    let gridPictureStyle: GridPictureStyle
    let appTheme: AppTheme?
    let viewBackgroundStyle: ViewBackgroundStyle?
    let showQuietHoursInToolbar: Bool?
    let quietHoursScheduleOverridesManual: Bool?
    let quietHours: QuietHoursSchedule?
}

private struct LegacyGridAssignmentsPayload: Codable {
    let assignments: [String: [CameraConfig.ID?]]
}

private enum LegacyGridOption: String, CaseIterable {
    case grid2x2
    case grid2x4
    case grid4x4

    var layout: GridLayout {
        switch self {
        case .grid2x2:
            return GridLayout(name: "2x2", columns: 2, rows: 2)
        case .grid2x4:
            return GridLayout(name: "2x4", columns: 2, rows: 4)
        case .grid4x4:
            return GridLayout(name: "4x4", columns: 4, rows: 4)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
