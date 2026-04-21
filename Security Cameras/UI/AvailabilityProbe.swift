//
//  AvailabilityProbe.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct AvailabilityProbe: View {
    let url: URL?
    let onStatusChange: (Bool) -> Void
    @State private var isRunning = false

    var body: some View {
        Color.clear
            .task {
                guard !isRunning else { return }
                isRunning = true
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
        guard let url else { return false }
        do {
            let (data, response) = try await CameraNetworkSession.shared.data(from: url)
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
    }
}
