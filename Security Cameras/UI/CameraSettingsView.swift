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
    @State private var draft = CameraConfig.emptyDraft
    @State private var addCameraState: AddCameraState = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

#if os(macOS)
                HStack(alignment: .top, spacing: 20) {
                    leftColumn
                        .frame(width: 320)
                    rightColumn
                }
#else
                VStack(spacing: 20) {
                    rightColumn
                    leftColumn
                }
#endif

                actionBar
            }
            .padding(24)
        }
        .background(backgroundGradient)
        .onChange(of: draft) { _, _ in
            guard !addCameraState.isValidating else { return }
            addCameraState = .idle
        }
#if os(macOS)
        .frame(minWidth: 920, minHeight: 680)
#endif
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.1, blue: 0.16),
                Color(red: 0.02, green: 0.03, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Camera Setup", systemImage: "dot.radiowaves.left.and.right")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Add cameras only after live snapshot check passes. Existing cameras stay one tap away.")
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 10) {
                infoPill(title: "\(viewModel.cameras.count)", subtitle: "Saved")
                infoPill(title: "\(viewModel.availability.values.filter { $0 }.count)", subtitle: "Online")
                infoPill(title: draft.useHTTPS ? "HTTPS" : "HTTP", subtitle: "Protocol")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.54, blue: 0.4),
                    Color(red: 0.08, green: 0.24, blue: 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var leftColumn: some View {
        VStack(spacing: 20) {
            camerasCard
            displayCard
        }
    }

    private var rightColumn: some View {
        settingsCard(title: "Add Camera", subtitle: "Validate stream before save.") {
            VStack(alignment: .leading, spacing: 18) {
                statusCard

                fieldBlock(title: "Camera Name", caption: "Optional label shown in sidebar and overlays.") {
                    TextField("Front Door", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock(title: "Address", caption: "IP address or host name used for snapshot endpoint.") {
                    TextField("192.168.1.50", text: $draft.host)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
#endif
                        .textFieldStyle(.roundedBorder)
                }

                credentialsSection

                channelProtocolSection

                fieldBlock(title: "Snapshot URL", caption: "Generated from form values.") {
                    Text(draft.sanitized.formattedSnapshotURL)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white.opacity(0.82))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button(action: validateAndAddCamera) {
                    HStack {
                        if addCameraState.isValidating {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(addCameraState.isValidating ? "Validating…" : "Add Camera")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(Color(red: 0.55, green: 0.92, blue: 0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(isAddDisabled)
                .opacity(isAddDisabled ? 0.55 : 1)
            }
        }
    }

    private var camerasCard: some View {
        settingsCard(title: "Saved Cameras", subtitle: "Quick access to configured feeds.") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.cameras.isEmpty {
                    placeholderCard(
                        title: "No cameras yet",
                        message: "Run validation once. Passing camera appears here and in sidebar."
                    )
                } else {
                    ForEach(viewModel.cameras) { camera in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(camera.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(camera.host)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.72))
                                Text(camera.connectionSummary)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.mint)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.deleteCamera(camera)
                            } label: {
                                Image(systemName: "trash")
                                    .padding(10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.82))
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private var displayCard: some View {
        settingsCard(title: "Display", subtitle: "Overlay preferences for detail and grid views.") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Show camera name in display", isOn: $viewModel.showCameraNameInDisplay)
                    .tint(.mint)
                    .foregroundStyle(.white)

                Picker("Camera name location", selection: $viewModel.cameraNameLocation) {
                    ForEach(CameraNameLocation.allCases) { location in
                        Text(location.title)
                            .tag(location)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: addCameraState.symbolName)
                .font(.title3)
                .foregroundStyle(addCameraState.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(addCameraState.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(addCameraState.message)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(addCameraState.backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 16) {
            usernameField
            passwordField
        }
#else
        VStack(spacing: 16) {
            usernameField
            passwordField
        }
#endif
    }

    @ViewBuilder
    private var channelProtocolSection: some View {
#if os(macOS)
        HStack(alignment: .center, spacing: 16) {
            channelField
            Spacer(minLength: 0)
            protocolField
        }
#else
        VStack(alignment: .leading, spacing: 16) {
            channelField
            protocolField
        }
#endif
    }

    private var usernameField: some View {
        fieldBlock(title: "Username", caption: "Camera login user.") {
            TextField("admin", text: $draft.username)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif
                .textFieldStyle(.roundedBorder)
        }
    }

    private var passwordField: some View {
        fieldBlock(title: "Password", caption: "Stored with camera config.") {
            SecureField("Password", text: $draft.password)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var channelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Channel")
                .font(.headline)
                .foregroundStyle(.white)
            Stepper("Channel \(draft.channel)", value: $draft.channel, in: 0...15)
                .tint(.mint)
        }
    }

    private var protocolField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protocol")
                .font(.headline)
                .foregroundStyle(.white)
            Toggle(isOn: $draft.useHTTPS) {
                Text(draft.useHTTPS ? "Use HTTPS" : "Use HTTP")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .toggleStyle(.switch)
        }
    }

    private var isAddDisabled: Bool {
        draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || addCameraState.isValidating
    }

    private func infoPill(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: Capsule())
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.68))
            }

            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }

    private func placeholderCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundStyle(Color.white.opacity(0.12))
        )
    }

    private func fieldBlock<Content: View>(title: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validateAndAddCamera() {
        let candidate = draft
        addCameraState = .validating

        Task {
            do {
                let camera = try await viewModel.validateAndAddCamera(from: candidate)
                draft = .emptyDraft
                addCameraState = .success("\(camera.displayName) responded with snapshot image. Camera added.")
            } catch let error as CameraValidationError {
                addCameraState = .failure(error.localizedDescription)
            } catch {
                addCameraState = .failure(error.localizedDescription)
            }
        }
    }
}

private enum AddCameraState {
    case idle
    case validating
    case success(String)
    case failure(String)

    var isValidating: Bool {
        if case .validating = self {
            return true
        }
        return false
    }

    var title: String {
        switch self {
        case .idle:
            return "Ready to validate"
        case .validating:
            return "Checking camera"
        case .success:
            return "Camera confirmed"
        case .failure:
            return "Could not connect"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Add Camera runs live snapshot check first. Only working feeds get saved."
        case .validating:
            return "Connecting to snapshot endpoint now. This usually takes a few seconds."
        case .success(let message), .failure(let message):
            return message
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "bolt.badge.shield"
        case .validating:
            return "dot.radiowaves.left.and.right"
        case .success:
            return "checkmark.seal.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle:
            return .cyan
        case .validating:
            return .mint
        case .success:
            return .green
        case .failure:
            return .orange
        }
    }

    var backgroundColor: Color {
        switch self {
        case .idle:
            return .white.opacity(0.05)
        case .validating:
            return Color(red: 0.07, green: 0.28, blue: 0.27)
        case .success:
            return Color(red: 0.08, green: 0.3, blue: 0.16)
        case .failure:
            return Color(red: 0.34, green: 0.17, blue: 0.09)
        }
    }
}
