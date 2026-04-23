//
//  SnapshotView.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

enum SnapshotScalingMode {
    case fit
    case fill
    case stretch
}

struct SnapshotView: View {
    let url: URL?
    var scalingMode: SnapshotScalingMode = .fit
    @State private var image: PlatformImage?
    let onStatusChange: (SnapshotStatus) -> Void

    var body: some View {
        ZStack {
            if let image {
                snapshotImage(image)
            } else {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
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
        guard let url else {
            await MainActor.run {
                image = nil
                onStatusChange(.failed)
            }
            return
        }
        do {
            let (data, response) = try await CameraNetworkSession.shared.data(from: url)
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

    @ViewBuilder
    private func snapshotImage(_ image: PlatformImage) -> some View {
#if os(iOS)
        let content = Image(uiImage: image).resizable()
#else
        let content = Image(nsImage: image).resizable()
#endif
        switch scalingMode {
        case .fill:
            content
                .scaledToFill()
                .clipped()
        case .fit:
            content
                .scaledToFit()
        case .stretch:
            content
        }
    }
}
