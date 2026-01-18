//
//  SnapshotView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct SnapshotView: View {
    let url: URL?
    @State private var image: PlatformImage?
    let onStatusChange: (SnapshotStatus) -> Void

    var body: some View {
        ZStack {
            if let image {
#if os(iOS)
                Image(uiImage: image)
                    .resizable()
#else
                Image(nsImage: image)
                    .resizable()
#endif
            } else {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .task(id: url) {
            image = nil
            onStatusChange(.loading)
            await poll()
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            await fetchSnapshot()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func fetchSnapshot() async {
        guard let url else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                markSnapshotFailure()
                return
            }
            if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
               !contentType.localizedCaseInsensitiveContains("image/"),
               !data.isJPEG {
                markSnapshotFailure()
                return
            }
#if os(iOS)
            guard let decoded = UIImage(data: data) else {
                markSnapshotFailure()
                return
            }
#else
            guard let decoded = NSImage(data: data) else {
                markSnapshotFailure()
                return
            }
#endif
            markSnapshotSuccess(decoded)
        } catch {
            markSnapshotFailure()
        }
    }

    @MainActor
    private func markSnapshotFailure() {
        image = nil
        onStatusChange(.failed)
    }

    @MainActor
    private func markSnapshotSuccess(_ decoded: PlatformImage) {
        image = decoded
        onStatusChange(.ok)
    }
}
