//
//  AvailabilityProbe.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct AvailabilityProbe: View {
    let camera: CameraConfig
    let isPaused: Bool
    let onStatusChange: (Bool) -> Void

    var body: some View {
        Color.clear
            .onChange(of: isPaused) { _, paused in
                if paused {
                    onStatusChange(false)
                }
            }
            .task(id: ProbeTaskKey(camera: camera, isPaused: isPaused)) {
                await poll()
            }
    }

    private func poll() async {
        while !Task.isCancelled {
            let isAvailable = await checkAvailability()
            onStatusChange(isAvailable)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    private func checkAvailability() async -> Bool {
        guard camera.isEnabled, !isPaused else { return false }

        switch camera.feedMode {
        case .snapshotPolling:
            guard let url = camera.snapshotURL else { return false }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 6
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("image/*", forHTTPHeaderField: "Accept")

                let (data, response) = try await CameraNetworkSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    return false
                }
                if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
                   contentType.localizedCaseInsensitiveContains("image/") {
                    return true
                }
                return data.isJPEG
            } catch {
                return false
            }
        case .rtsp:
            return await RTSPConnectionService.canReach(camera: camera)
        }
    }
}

private struct ProbeTaskKey: Hashable {
    let camera: CameraConfig
    let isPaused: Bool
}
