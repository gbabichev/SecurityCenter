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

struct CameraSettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CameraConfig(
        name: "",
        host: "",
        username: "admin",
        password: "",
        channel: 0,
        useHTTPS: false
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cameras")
                .font(.title2)

            List {
                ForEach(viewModel.cameras) { camera in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(camera.displayName)
                                .font(.headline)
                            Text(camera.host)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.deleteCamera(camera)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteCameras)
            }

            Form {
                Section("Add Camera") {
                    TextField("Name", text: $draft.name)
                    TextField("IP or Host", text: $draft.host)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    TextField("Username", text: $draft.username)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    SecureField("Password", text: $draft.password)
                    Stepper("Channel: \(draft.channel)", value: $draft.channel, in: 0...15)
                    Toggle("Use HTTPS", isOn: $draft.useHTTPS)
                }
            }

            HStack {
                Button("Done") {
                    dismiss()
                }
                Spacer()
                Button("Add Camera") {
                    viewModel.addCamera(from: draft)
                    resetDraft()
                }
                .disabled(draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 560)
    }

    private func resetDraft() {
        draft = CameraConfig(
            name: "",
            host: "",
            username: "admin",
            password: "",
            channel: 0,
            useHTTPS: false
        )
    }
}

struct CameraDetailView: View {
    let camera: CameraConfig
    @State private var snapshotStatus: SnapshotStatus = .loading

    var body: some View {
        Group {
            if snapshotStatus == .failed {
                ContentUnavailableView(
                    "Check camera settings",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Verify username, password, host, and channel.")
                )
                .background(snapshotProbeView)
            } else {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(camera.displayName)
                                .font(.title2)
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        SnapshotView(url: camera.snapshotURL) { status in
                            snapshotStatus = status
                        }
                        .cornerRadius(8)

                        Text(camera.host)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: 1200, maxHeight: 900)
                }
                .frame(minWidth: 900, minHeight: 600)
            }
        }
        .onChange(of: camera.snapshotURL) { _ in
            snapshotStatus = .loading
        }
    }

    private var snapshotProbeView: some View {
        SnapshotView(url: camera.snapshotURL) { status in
            snapshotStatus = status
        }
        .frame(width: 1, height: 1)
        .opacity(0)
    }
}

struct AvailabilityIndicator: View {
    let isAvailable: Bool

    var body: some View {
        Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(isAvailable ? .green : .secondary)
    }
}

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
            let (data, response) = try await URLSession.shared.data(from: url)
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
                await markSnapshotFailure()
                return
            }
            if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
               !contentType.localizedCaseInsensitiveContains("image/"),
               !data.isJPEG {
                await markSnapshotFailure()
                return
            }
#if os(iOS)
            guard let decoded = UIImage(data: data) else {
                await markSnapshotFailure()
                return
            }
#else
            guard let decoded = NSImage(data: data) else {
                await markSnapshotFailure()
                return
            }
#endif
            await markSnapshotSuccess(decoded)
        } catch {
            await markSnapshotFailure()
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
