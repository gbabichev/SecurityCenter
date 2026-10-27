#if os(macOS)
import SwiftUI

struct MacCameraEditor: View {
    @Binding var draft: CameraConfig
    let state: CameraEditorState
    let connectionCheckState: CameraEditorState
    let hasUnsavedChanges: Bool
    let isEditing: Bool
    let canSave: Bool
    let didCopyLink: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onCopyLink: () -> Void
    let onCheckConnection: () -> Void
    @State private var section: CameraEditorSection = .connection

    private var isBusy: Bool { state.isValidating || connectionCheckState.isValidating }

    var body: some View {
        VStack(spacing: 0) {
            MacCameraEditorHeader(isEditing: isEditing, section: $section, isEnabled: $draft.isEnabled, onClose: onCancel)
                .disabled(isBusy)
            Divider()
            Group {
                switch section {
                case .connection:
                    CameraConnectionFields(draft: $draft, didCopyLink: didCopyLink, onCopyLink: onCopyLink, checkState: connectionCheckState, onCheckConnection: onCheckConnection)
                case .playback:
                    CameraPlaybackFields(draft: $draft)
                case .display:
                    CameraDisplayFields(draft: $draft)
                }
            }
            .disabled(isBusy)
            Divider()
            MacCameraEditorFooter(
                state: state, isEditing: isEditing, canSave: canSave,
                hasUnsavedChanges: hasUnsavedChanges, isBusy: isBusy,
                onCancel: onCancel, onSave: onSave, onDelete: onDelete, onCopy: onCopy
            )
        }
        .frame(width: 640, height: 560)
    }
}

private enum CameraEditorSection: Hashable {
    case connection, playback, display
}

private struct MacCameraEditorHeader: View {
    let isEditing: Bool
    @Binding var section: CameraEditorSection
    @Binding var isEnabled: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(isEditing ? "Edit Camera" : "Add Camera")
                    .font(.title2.weight(.semibold))
                Spacer()
                Toggle("Camera enabled", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .fixedSize()
                Button("Done", action: onClose)
                    .padding(.leading, 8)
            }
            Picker("Camera settings", selection: $section) {
                Text("Connection").tag(CameraEditorSection.connection)
                Text("Picture & Sound").tag(CameraEditorSection.playback)
                Text("Display").tag(CameraEditorSection.display)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CameraConnectionFields: View {
    @Binding var draft: CameraConfig
    let didCopyLink: Bool
    let onCopyLink: () -> Void
    let checkState: CameraEditorState
    let onCheckConnection: () -> Void
    @State private var isPasswordVisible = false

    var body: some View {
        Form {
            Section("Camera") {
                TextField("Name", text: $draft.name, prompt: Text("Optional"))
                Picker("Type", selection: $draft.kind) {
                    ForEach(CameraKind.allCases) { Text($0.title).tag($0) }
                }
                if draft.kind == .reolink {
                    Picker("Feed type", selection: $draft.feedMode) {
                        ForEach(CameraFeedMode.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            Section {
                if draft.kind == .reolink {
                    TextField("Address", text: $draft.host, prompt: Text("192.168.1.50"))
                    TextField("Username", text: $draft.username, prompt: Text("admin"))
                    LabeledContent("Password") {
                        HStack(spacing: 6) {
                            Group {
                                if isPasswordVisible {
                                    TextField("Password", text: $draft.password)
                                } else {
                                    SecureField("Password", text: $draft.password)
                                }
                            }
                            .labelsHidden()
                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(isPasswordVisible ? "Hide Password" : "Show Password")
                        }
                    }
                    if draft.feedMode == .snapshotPolling {
                        Picker("Protocol", selection: $draft.useHTTPS) {
                            Text("HTTP").tag(false)
                            Text("HTTPS").tag(true)
                        }
                    }
                } else {
                    TextField("Camera link", text: $draft.genericRTSPURL, prompt: Text("rtsp://192.168.1.50/stream"))
                }
            } header: {
                Text("Connection")
            } footer: {
                Text(draft.kind == .reolink ? "Enter the camera’s IP address or host name and login details." : "Paste the full live video link, including login details if required.")
            }
            HStack {
                Button("Check Connection", systemImage: "network", action: onCheckConnection)
                    .disabled(draft.kind == .reolink ? draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : draft.genericRTSPURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button(didCopyLink ? "Copied" : "Copy URL", systemImage: didCopyLink ? "checkmark" : "doc.on.doc", action: onCopyLink)
                    .disabled(draft.kind == .reolink ? draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : draft.genericRTSPURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            switch checkState {
            case .idle:
                EmptyView()
            default:
                CameraEditorFeedback(state: checkState)
            }
        }
        .formStyle(.grouped)
    }
}

private struct CameraPlaybackFields: View {
    @Binding var draft: CameraConfig

    var body: some View {
        Form {
            if draft.kind == .reolink {
                Section {
                    Picker("Picture quality", selection: $draft.streamVariant) {
                        ForEach(CameraStreamVariant.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Picture")
                } footer: {
                    Text(draft.feedMode.description)
                }
                if draft.feedMode == .snapshotPolling {
                    Section("Picture Updates") {
                        Stepper("Refresh every \(draft.snapshotPollingIntervalSeconds) seconds", value: $draft.snapshotPollingIntervalSeconds, in: 1...10)
                    }
                }
            }
            if draft.kind == .genericRTSP || draft.feedMode == .rtsp {
                Section {
                    Toggle("Mute camera", isOn: $draft.isMuted)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Muted cameras skip audio processing. Changing this setting briefly reconnects the stream.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CameraDisplayFields: View {
    @Binding var draft: CameraConfig

    var body: some View {
        Form {
            Section {
                Toggle("Show camera name on picture", isOn: $draft.showsNameInDisplay)
                Picker("Name position", selection: $draft.nameLocation) {
                    ForEach(CameraNameLocation.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!draft.showsNameInDisplay)
            } header: {
                Text("Camera Label")
            } footer: {
                Text("The camera name appears in the selected corner in single-camera and grid views.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct MacCameraEditorFooter: View {
    let state: CameraEditorState
    let isEditing: Bool
    let canSave: Bool
    let hasUnsavedChanges: Bool
    let isBusy: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CameraEditorFeedback(state: state)
            HStack(spacing: 8) {
                if isEditing {
                    Button("Delete…", role: .destructive, action: onDelete)
                        .disabled(isBusy)
                    Button("Copy", systemImage: "doc.on.doc", action: onCopy)
                        .disabled(isBusy)
                }
                Spacer()
                if isEditing && !hasUnsavedChanges {
                    Button("Done", action: onCancel)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isBusy)
                } else {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                        .disabled(isBusy)
                    Button(isEditing ? "Save Changes" : "Add Camera", action: onSave)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave || isBusy)
                }
            }
        }
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CameraEditorFeedback: View {
    let state: CameraEditorState

    var body: some View {
        switch state {
        case .idle:
            Text("The connection is checked when you save.")
                .font(.callout).foregroundStyle(.secondary)
        case .validating:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking camera connection…")
            }
            .accessibilityElement(children: .combine)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}
#endif
