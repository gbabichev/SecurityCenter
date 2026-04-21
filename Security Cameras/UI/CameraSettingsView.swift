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
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var editorState: EditorState = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

#if os(macOS)
                HStack(alignment: .top, spacing: 14) {
                    camerasCard
                        .frame(width: 260)
                    VStack(spacing: 14) {
                        editorCard
                        displayCard
                    }
                }
#else
                VStack(spacing: 14) {
                    camerasCard
                    editorCard
                    displayCard
                }
#endif

                footer
            }
            .padding(16)
        }
        .onChange(of: draft) { _, _ in
            guard !editorState.isValidating else { return }
            editorState = .idle
        }
        .onChange(of: viewModel.cameras) { _, cameras in
            if let selectedCameraID, !cameras.contains(where: { $0.id == selectedCameraID }) {
                resetEditor()
            }
        }
#if os(macOS)
        .frame(minWidth: 760, minHeight: 540)
#endif
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text(isEditing ? "Edit selected camera." : "Add camera or pick one to edit.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEditing {
                Button("New Camera") {
                    resetEditor()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var camerasCard: some View {
        settingsCard(title: "Cameras", subtitle: "Click camera to edit.") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.cameras.isEmpty {
                    placeholderCard(title: "No cameras yet", message: "Use form to add first camera.")
                } else {
                    ForEach(viewModel.cameras) { camera in
                        Button {
                            selectedCameraID = camera.id
                            draft = camera
                            editorState = .idle
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(camera.displayName)
                                        .font(.headline)
                                    Text(camera.host)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(camera.connectionSummary)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                                    .padding(.top, 2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedCameraID == camera.id ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") {
                                selectedCameraID = camera.id
                                draft = camera
                                editorState = .idle
                            }
                            Button("Delete", role: .destructive) {
                                if selectedCameraID == camera.id {
                                    resetEditor()
                                }
                                viewModel.deleteCamera(camera)
                            }
                        }
                    }
                }
            }
        }
    }

    private var editorCard: some View {
        settingsCard(
            title: isEditing ? "Edit Camera" : "Add Camera",
            subtitle: isEditing ? "Save updates after live validation." : "Camera is saved only after live validation."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                statusCard

                fieldBlock(title: "Name", caption: "Optional label.") {
                    TextField("Front Door", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock(title: "Address", caption: "IP or host name.") {
                    TextField("192.168.1.50", text: $draft.host)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
#endif
                        .textFieldStyle(.roundedBorder)
                }

                credentialsSection

                protocolField

                HStack(spacing: 10) {
                    if isEditing {
                        Button("Cancel") {
                            resetEditor()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: saveCamera) {
                        HStack {
                            if editorState.isValidating {
                                ProgressView()
                            } else {
                                Image(systemName: isEditing ? "square.and.arrow.down.fill" : "plus.circle.fill")
                            }
                            Text(editorState.isValidating ? "Validating…" : (isEditing ? "Save Changes" : "Add Camera"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPrimaryActionDisabled)
                    .opacity(isPrimaryActionDisabled ? 0.55 : 1)
                }
            }
        }
    }

    private var displayCard: some View {
        settingsCard(title: "Display", subtitle: "Overlay preferences.") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show camera name in display", isOn: $viewModel.showCameraNameInDisplay)

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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: editorState.symbolName)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(editorState.title)
                    .font(.headline)
                Text(editorState.message(isEditing: isEditing))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 12) {
            usernameField
            passwordField
        }
#else
        VStack(spacing: 12) {
            usernameField
            passwordField
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

    private var protocolField: some View {
        HStack(spacing: 12) {
            Text("Protocol")
                .font(.headline)
            Spacer(minLength: 0)
            Toggle(draft.useHTTPS ? "HTTPS" : "HTTP", isOn: $draft.useHTTPS)
                .toggleStyle(.switch)
                .labelsHidden()
            Text(draft.useHTTPS ? "HTTPS" : "HTTP")
                .foregroundStyle(.secondary)
        }
    }

    private var isEditing: Bool {
        selectedCameraID != nil
    }

    private var isPrimaryActionDisabled: Bool {
        draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editorState.isValidating
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func placeholderCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundStyle(.quaternary)
        )
    }

    private func fieldBlock<Content: View>(title: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveCamera() {
        let candidate = draft
        let editingID = selectedCameraID
        editorState = .validating

        Task {
            do {
                let camera = try await viewModel.validateAndSaveCamera(from: candidate, editing: editingID)
                selectedCameraID = camera.id
                draft = camera
                editorState = .success(editingID == nil ? "\(camera.displayName) added." : "\(camera.displayName) updated.")
            } catch let error as CameraValidationError {
                editorState = .failure(error.localizedDescription)
            } catch {
                editorState = .failure(error.localizedDescription)
            }
        }
    }

    private func resetEditor() {
        selectedCameraID = nil
        draft = .emptyDraft
        editorState = .idle
    }
}

private enum EditorState {
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
            return "Ready"
        case .validating:
            return "Checking camera"
        case .success:
            return "Saved"
        case .failure:
            return "Could not connect"
        }
    }

    func message(isEditing: Bool) -> String {
        switch self {
        case .idle:
            return isEditing ? "Save changes after validation passes." : "Add camera after validation passes."
        case .validating:
            return "Connecting to snapshot endpoint."
        case .success(let message), .failure(let message):
            return message
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "slider.horizontal.3"
        case .validating:
            return "dot.radiowaves.left.and.right"
        case .success:
            return "checkmark.seal.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

}
