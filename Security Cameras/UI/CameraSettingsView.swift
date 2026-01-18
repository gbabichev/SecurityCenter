//
//  CameraSettingsView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

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
