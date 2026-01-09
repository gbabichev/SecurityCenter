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

    var body: some View {
        NavigationStack {
            Group {
                if cameras.isEmpty {
                    ContentUnavailableView(
                        "No Cameras",
                        systemImage: "video",
                        description: Text("Open Settings to add your first IP camera.")
                    )
                } else {
                    List(cameras) { camera in
                        CameraRowView(camera: camera)
                    }
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
        }
        .sheet(isPresented: $showSettings) {
            CameraSettingsView(cameras: $cameras)
        }
        .onAppear(perform: loadCameras)
        .onChange(of: cameras, saveCameras)
        .padding()
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(camera.displayName)
                            .font(.headline)
                        Text(camera.host)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

struct CameraRowView: View {
    let camera: CameraConfig

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SnapshotView(url: camera.snapshotURL)
                .frame(width: 160, height: 90)
                .clipped()
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 4) {
                Text(camera.displayName)
                    .font(.headline)
                Text(camera.host)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
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
        while true {
            await fetchSnapshot()
            try? await Task.sleep(nanoseconds: 5_000_000_000)
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
