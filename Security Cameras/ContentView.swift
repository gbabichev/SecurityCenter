//
//  ContentView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

struct ContentView: View {
    @AppStorage("camerasJSON") private var camerasJSON: String = "[]"
    @State private var cameras: [CameraConfig] = []
    @State private var showSettings = false
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var availability: [CameraConfig.ID: Bool] = [:]

    var body: some View {
        NavigationSplitView {
            if cameras.isEmpty {
                ContentUnavailableView(
                    "No Cameras",
                    systemImage: "video",
                    description: Text("Open Settings to add your first IP camera.")
                )
            } else {
                List(cameras, selection: $selectedCameraID) { camera in
                    HStack {
                        Text(camera.displayName)
                        Spacer()
                        AvailabilityIndicator(isAvailable: availability[camera.id] ?? false)
                    }
                    .contentShape(Rectangle())
                    .tag(camera.id)
                    .background(
                        AvailabilityProbe(url: camera.snapshotURL) { isAvailable in
                            availability[camera.id] = isAvailable
                        }
                    )
                }
            }
        } detail: {
            if let selectedCamera = selectedCamera {
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
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            CameraSettingsView(cameras: $cameras)
        }
        .onAppear(perform: loadCameras)
        .onChange(of: cameras, saveCameras)
    }

    private var selectedCamera: CameraConfig? {
        guard let selectedCameraID else { return nil }
        return cameras.first { $0.id == selectedCameraID }
    }

    private func loadCameras() {
        guard let data = camerasJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CameraConfig].self, from: data) else {
            return
        }
        cameras = decoded
    }

    private func saveCameras() {
        guard let data = try? JSONEncoder().encode(cameras),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        camerasJSON = json
    }
}

struct CameraSettingsView: View {
    @Binding var cameras: [CameraConfig]
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
                ForEach(cameras) { camera in
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
                            deleteCamera(camera)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteCameras)
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
                    addCamera()
                }
                .disabled(draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 560)
    }

    private func deleteCameras(at offsets: IndexSet) {
        cameras.remove(atOffsets: offsets)
    }

    private func deleteCamera(_ camera: CameraConfig) {
        cameras.removeAll { $0.id == camera.id }
    }

    private func addCamera() {
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

    var body: some View {
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

                SnapshotView(url: camera.snapshotURL)
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
    @State private var isRunning = false

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
        .task {
            guard !isRunning else { return }
            isRunning = true
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
            let (data, _) = try await URLSession.shared.data(from: url)
#if os(iOS)
            image = UIImage(data: data)
#else
            image = NSImage(data: data)
#endif
        } catch {
            // Ignore transient errors while polling.
        }
    }
}

private extension Data {
    var isJPEG: Bool {
        guard count >= 4 else { return false }
        return self[startIndex] == 0xFF
            && self[index(after: startIndex)] == 0xD8
            && self[index(before: endIndex)] == 0xD9
            && self[index(before: index(before: endIndex))] == 0xFF
    }
}

struct CameraConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var username: String
    var password: String
    var channel: Int
    var useHTTPS: Bool

    var displayName: String {
        name.isEmpty ? "Camera" : name
    }

    var snapshotURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/cgi-bin/api.cgi"
        components.queryItems = [
            URLQueryItem(name: "cmd", value: "Snap"),
            URLQueryItem(name: "channel", value: "\(channel)"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        return components.url
    }
}
