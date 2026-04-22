//
//  CameraSettingsView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct CameraSettingsView: View {
    private enum SettingsTab: Hashable {
        case app
        case camera
    }

    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CameraConfig.emptyDraft
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var editorState: EditorState = .idle
    @State private var selectedTab: SettingsTab = .camera
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            TabView(selection: $selectedTab) {
                appSettingsTab
                    .tabItem {
                        Label("App Settings", systemImage: "gearshape")
                    }
                    .tag(SettingsTab.app)

                cameraSettingsTab
                    .tabItem {
                        Label("Camera Settings", systemImage: "video")
                    }
                    .tag(SettingsTab.camera)
            }

            footer
        }
        .padding(16)
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

    private var appSettingsTab: some View {
        ScrollView {
            settingsCard(title: "App Settings", subtitle: "Preferences for the whole app.") {
                VStack(alignment: .leading, spacing: 12) {
                    fieldBlock(title: "Camera Grid", caption: "Choose how pictures should look in the grid view.") {
                        Picker("Camera Grid", selection: $viewModel.gridPictureStyle) {
                            ForEach(GridPictureStyle.allCases) { style in
                                Text(style.title)
                                    .tag(style)
                            }
                        }
#if os(iOS)
                        .pickerStyle(.menu)
#else
                        .pickerStyle(.segmented)
#endif

                        Text(viewModel.gridPictureStyle.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var cameraSettingsTab: some View {
        ScrollView {
#if os(macOS)
            HStack(alignment: .top, spacing: 14) {
                camerasCard
                    .frame(width: 260)
                VStack(spacing: 14) {
                    editorCard
                    displayCard
                }
            }
            .padding(.top, 4)
#else
            VStack(spacing: 14) {
                camerasCard
                editorCard
                displayCard
            }
            .padding(.top, 4)
#endif
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedTab == .camera && isEditing {
                Button("New Camera") {
                    resetEditor()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var headerSubtitle: String {
        switch selectedTab {
        case .app:
            return "Manage app-wide preferences."
        case .camera:
            return isEditing ? "Edit selected camera." : "Add camera or pick one to edit."
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
                            .contentShape(Rectangle())
                            .background(selectedCameraID == camera.id ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            subtitle: isEditing ? "Save updates after source validation." : "Camera is saved only after source validation."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                nameAndAddressRow

                credentialsSection

                enabledField
                feedModeField

                if draft.isEnabled && draft.feedMode == .snapshotPolling {
                    protocolField
                }

                streamVariantField

                if draft.feedMode == .rtsp {
                    muteCameraField
                }

                sourcePreviewField

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
                            } else if let saveButtonSymbolName {
                                Image(systemName: saveButtonSymbolName)
                            } else {
                                EmptyView()
                            }
                            Text(saveButtonTitle)
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

    @ViewBuilder
    private var nameAndAddressRow: some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 12) {
            nameField
            addressField
        }
#else
        VStack(spacing: 12) {
            nameField
            addressField
        }
#endif
    }

    private var nameField: some View {
        fieldBlock(title: "Name", caption: "Optional label.") {
            TextField("Front Door", text: $draft.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var addressField: some View {
        fieldBlock(title: "Address", caption: "IP or host name.") {
            TextField("192.168.1.50", text: $draft.host)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
#endif
                .textFieldStyle(.roundedBorder)
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

    private var saveButtonTitle: String {
        switch editorState {
        case .idle:
            return isEditing ? "Save Changes" : "Add Camera"
        case .validating:
            return "Validating…"
        case .success(let message), .failure(let message):
            return message
        }
    }

    private var saveButtonSymbolName: String? {
        switch editorState {
        case .idle:
            return isEditing ? "square.and.arrow.down.fill" : "plus.circle.fill"
        case .validating:
            return nil
        case .success:
            return "checkmark.seal.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
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
            HStack(spacing: 8) {
                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $draft.password)
                    } else {
                        SecureField("Password", text: $draft.password)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button(isPasswordVisible ? "Hide" : "Show") {
                    isPasswordVisible.toggle()
                }
                .buttonStyle(.bordered)
            }
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

    private var enabledField: some View {
        Toggle("Camera enabled", isOn: $draft.isEnabled)
    }

    private var feedModeField: some View {
        fieldBlock(title: "Feed Type", caption: "Choose camera source for display and probing.") {
            Picker("Feed Type", selection: $draft.feedMode) {
                ForEach(CameraFeedMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
#if os(iOS)
            .pickerStyle(.menu)
#else
            .pickerStyle(.segmented)
#endif

            Text(draft.feedMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var streamVariantField: some View {
        fieldBlock(title: "Stream Variant", caption: streamVariantCaption) {
            Picker("Stream Variant", selection: $draft.streamVariant) {
                ForEach(CameraStreamVariant.allCases) { variant in
                    Text(variant.title)
                        .tag(variant)
                }
            }
#if os(iOS)
            .pickerStyle(.menu)
#else
            .pickerStyle(.segmented)
#endif
        }
    }

    private var muteCameraField: some View {
        Toggle("Mute Camera", isOn: $draft.isMuted)
    }

    private var streamVariantCaption: String {
        switch draft.feedMode {
        case .snapshotPolling:
            return "Choose mainstream or substream JPEG snapshots."
        case .rtsp:
            return "Choose main stream or lower-bandwidth substream."
        }
    }

    private var sourcePreviewField: some View {
        fieldBlock(title: sourcePreviewTitle, caption: sourcePreviewCaption) {
            Button("Copy URL to Clipboard") {
                copySourceURLToClipboard()
            }
            .buttonStyle(.bordered)
        }
    }

    private var sourcePreviewTitle: String {
        switch draft.feedMode {
        case .snapshotPolling:
            return "Snapshot URL"
        case .rtsp:
            return "RTSP URL"
        }
    }

    private var sourcePreviewCaption: String {
        guard draft.isEnabled else {
            return "Stored source. Camera is disabled, so app will not poll or stream it."
        }
        switch draft.feedMode {
        case .snapshotPolling:
            return "Reolink JPEG endpoint used for polling."
        case .rtsp:
            return "RTSP endpoint used for live playback through VLCKit (\(draft.streamVariant.title.lowercased()))."
        }
    }

    private var sourcePreviewValue: String {
        switch draft.feedMode {
        case .snapshotPolling:
            return draft.formattedSnapshotURL
        case .rtsp:
            return draft.formattedRTSPURL
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
        isPasswordVisible = false
    }

    private func copySourceURLToClipboard() {
#if os(iOS)
        UIPasteboard.general.string = sourcePreviewValue
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sourcePreviewValue, forType: .string)
#endif
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

    func message(isEditing: Bool, feedMode: CameraFeedMode) -> String {
        switch self {
        case .idle:
            switch feedMode {
            case .snapshotPolling:
                return isEditing ? "Save changes after JPEG snapshot validation passes." : "Add camera after JPEG snapshot validation passes."
            case .rtsp:
                return isEditing ? "Save changes after RTSP reachability validation passes." : "Add camera after RTSP reachability validation passes."
            }
        case .validating:
            switch feedMode {
            case .snapshotPolling:
                return "Connecting to snapshot endpoint."
            case .rtsp:
                return "Connecting to RTSP service."
            }
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
