//
//  CameraSettingsView.swift
//  Security Cameras
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

#if os(iOS)
import UniformTypeIdentifiers
import UIKit
#else
import AppKit
#endif

struct CameraSettingsView: View {
    private enum PendingLeaveAction {
        case selectCamera(CameraConfig)
        case resetEditor
        case dismissSheet
#if os(iOS)
        case dismissEditor
#endif
    }

    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CameraConfig.emptyDraft
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var editorState: EditorState = .idle
    @State private var isPasswordVisible = false
    @State private var pendingLeaveAction: PendingLeaveAction?
    @State private var showingUnsavedChangesAlert = false
    @State private var didCopySourceURL = false
    @State private var gridPictureStyleDraft: GridPictureStyle = .fillEachBox
    @State private var quietHoursDraft = QuietHoursSchedule()
#if os(iOS)
    @State private var showingCameraEditorSheet = false
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var exportDocument = ConfigurationJSONDocument(data: Data())
    @State private var configurationAlert: ConfigurationAlert?
#endif

    var body: some View {
#if os(macOS)
        macBody
#else
        iosBody
#endif
    }

    #if os(macOS)
    private var macBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appSettingsSection

                    cameraSettingsSection
                }
                .padding(.top, 4)
            }

            cameraActionBar

            footer
        }
        .padding(16)
        .onAppear {
            syncAppSettingsDraft()
        }
        .onChange(of: draft) { _, _ in
            guard !editorState.isValidating else { return }
            editorState = .idle
        }
        .onChange(of: draft.kind) { _, kind in
            if kind == .genericRTSP {
                draft.feedMode = .rtsp
            }
        }
        .onChange(of: viewModel.cameras) { _, cameras in
            if let selectedCameraID, !cameras.contains(where: { $0.id == selectedCameraID }) {
                resetEditor()
            }
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Keep Editing", role: .cancel) {
                pendingLeaveAction = nil
            }
            Button("Discard Changes", role: .destructive) {
                performPendingLeaveAction()
            }
        } message: {
            Text("You have unsaved changes for this camera. Discard them and continue?")
        }
        .interactiveDismissDisabled(hasUnsavedCameraChanges || hasUnsavedAppSettingsChanges)
#if os(macOS)
        .frame(minWidth: 850, minHeight: 620)
#endif
    }
    #endif

    #if os(iOS)
    private var iosBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appSettingsSection
                    cameraPickerCard
                }
                .padding(.top, 4)
            }

            footer
        }
        .padding(16)
        .onAppear {
            syncAppSettingsDraft()
        }
        .onChange(of: draft) { _, _ in
            guard !editorState.isValidating else { return }
            editorState = .idle
        }
        .onChange(of: draft.kind) { _, kind in
            if kind == .genericRTSP {
                draft.feedMode = .rtsp
            }
        }
        .onChange(of: viewModel.cameras) { _, cameras in
            if let selectedCameraID, !cameras.contains(where: { $0.id == selectedCameraID }) {
                resetEditor()
                showingCameraEditorSheet = false
            }
        }
        .sheet(isPresented: $showingCameraEditorSheet) {
            iosCameraEditorSheet
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Security Cameras"
        ) { result in
            if case .failure(let error) = result {
                configurationAlert = ConfigurationAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .alert(item: $configurationAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .interactiveDismissDisabled(hasUnsavedAppSettingsChanges)
    }
    #endif

    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("App Settings", subtitle: "A few preferences for the whole app.")

#if os(macOS)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera Grid")
                                .font(.headline)
                            Text(gridPictureStyleDraft.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Picker("Camera Grid", selection: $gridPictureStyleDraft) {
                        ForEach(GridPictureStyle.allCases) { style in
                            Text(style.title)
                                .tag(style)
                        }
                    }
                    .frame(maxWidth: 360)
                    .pickerStyle(.segmented)
                }

                Divider()

                quietHoursSettingsBlock
            }
#else
            VStack(alignment: .leading, spacing: 12) {
                fieldBlock(title: "Camera Grid", caption: "Choose how pictures should look in the grid view.") {
                    optionButtons(
                        selection: $gridPictureStyleDraft,
                        options: GridPictureStyle.allCases,
                        columns: 2
                    ) { $0.title }

                    Text(gridPictureStyleDraft.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                quietHoursSettingsBlock

                fieldBlock(title: "Configuration", caption: "Import or export your app settings and cameras as JSON.") {
                    HStack(spacing: 10) {
                        Button {
                            showingImportPicker = true
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            exportConfiguration()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
#endif
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
        )
    }

    private var quietHoursSettingsBlock: some View {
        fieldBlock(title: "Quiet Hours", caption: "Black out the screen and pause all camera traffic during these hours.") {
            Toggle("Turn on quiet hours", isOn: quietHoursEnabledBinding)

            if quietHoursDraft.isEnabled {
#if os(macOS)
                HStack(spacing: 16) {
                    quietHoursTimeField(title: "Start", selection: quietHoursStartDateBinding)
                    quietHoursTimeField(title: "End", selection: quietHoursEndDateBinding)
                }
#else
                VStack(spacing: 12) {
                    quietHoursTimeField(title: "Start", selection: quietHoursStartDateBinding)
                    quietHoursTimeField(title: "End", selection: quietHoursEndDateBinding)
                }
#endif
            }

            Text(quietHoursStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    #if os(macOS)
    private var cameraSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Camera Settings", subtitle: cameraSettingsSubtitle)

#if os(macOS)
            HStack(alignment: .top, spacing: 14) {
                camerasCard
                    .frame(width: 260)
                Divider()
                    .padding(.vertical, 4)
                editorCard
            }
#else
            VStack(spacing: 14) {
                cameraPickerCard
                editorCard
            }
#endif
        }
    }

    private var cameraSettingsSubtitle: String {
        "Pick a camera on the left, then edit on the right."
    }
    #endif

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Camera setup and app behavior.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

#if os(macOS)
            if isEditing {
                Button("New Camera") {
                    attemptToLeaveEditor(.resetEditor)
                }
                .buttonStyle(.bordered)
            }
#endif
        }
    }

    #if os(macOS)
    private var camerasCard: some View {
        settingsCard(title: "Cameras", subtitle: "Click camera to edit.") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.cameras.isEmpty {
                    placeholderCard(title: "No cameras yet", message: "Use form to add first camera.")
                } else {
                    ForEach(Array(viewModel.cameras.enumerated()), id: \.element.id) { index, camera in
                        Button {
                            attemptToLeaveEditor(.selectCamera(camera))
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(camera.displayName)
                                        .font(.headline)
                                    Text(camera.hostSummary)
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
                            .background {
                                if selectedCameraID == camera.id {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.thinMaterial)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") {
                                attemptToLeaveEditor(.selectCamera(camera))
                            }
                            Button("Delete", role: .destructive) {
                                if selectedCameraID == camera.id {
                                    resetEditor()
                                }
                                viewModel.deleteCamera(camera)
                            }
                        }

                        if index < viewModel.cameras.count - 1 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
        )
    }
    #endif

    #if os(iOS)
    private var cameraPickerCard: some View {
        settingsCard(title: "Cameras", subtitle: "Tap a camera below to edit it.") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    beginAddingCamera()
                } label: {
                    Label("New Camera", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                if viewModel.cameras.isEmpty {
                    placeholderCard(title: "No cameras yet", message: "Start by adding your first camera.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(viewModel.cameras.enumerated()), id: \.element.id) { index, camera in
                            Button {
                                openEditor(for: camera)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(camera.displayName)
                                            .font(.headline)
                                        Text(camera.hostSummary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Text(camera.connectionSummary)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    if camera.isEnabled {
                                        AvailabilityIndicator(isAvailable: viewModel.availability[camera.id] ?? false)
                                    } else {
                                        Image(systemName: "pause.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    if selectedCameraID == camera.id {
                                        resetEditor()
                                    }
                                    viewModel.deleteCamera(camera)
                                }
                            }

                            if index < viewModel.cameras.count - 1 {
                                Divider()
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
        )
    }

    private var iosCameraEditorSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Camera" : "Add Camera")
                        .font(.title2.weight(.semibold))
                    Text(isEditing ? "Update this camera and save when ready." : "Enter camera details, then save.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    attemptToLeaveEditor(.dismissEditor)
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                editorCard
                    .padding(.top, 4)
            }

            cameraActionBar
        }
        .padding(16)
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Keep Editing", role: .cancel) {
                pendingLeaveAction = nil
            }
            Button("Discard Changes", role: .destructive) {
                performPendingLeaveAction()
            }
        } message: {
            Text("You have unsaved changes for this camera. Discard them and continue?")
        }
        .interactiveDismissDisabled(hasUnsavedCameraChanges)
    }
    #endif

    private var editorCard: some View {
        settingsCard(
            title: isEditing ? "Edit Camera" : "Add Camera",
            subtitle: isEditing ? "Save updates after source validation." : "Camera is saved only after source validation."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorGroup("Camera Type") {
                    cameraKindField
                }

                editorGroup("Basics") {
                    basicsFields
                    enabledField
                }

                editorGroup("Display") {
                    displayNameField
                }

                if draft.kind == .reolink {
                    editorGroup("Access") {
                        credentialsSection
                    }
                }

                editorGroup("Connection") {
                    if draft.kind == .reolink {
                        feedModeField

                        if draft.isEnabled && draft.feedMode == .snapshotPolling {
                            protocolField
                        }

                        streamVariantField
                    } else {
                        genericRTSPURLField
                        muteCameraField
                    }

                    if draft.kind == .reolink && draft.feedMode == .rtsp {
                        muteCameraField
                    }

                    sourcePreviewField
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
        )
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

    @ViewBuilder
    private var basicsFields: some View {
        if draft.kind == .reolink {
            nameAndAddressRow
        } else {
            VStack(spacing: 12) {
                nameField
            }
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

    private var cameraKindField: some View {
        fieldBlock(title: "Type", caption: "Choose which kind of camera connection to add.") {
#if os(iOS)
            optionButtons(
                selection: $draft.kind,
                options: CameraKind.allCases,
                columns: 2
            ) { $0.title }
#else
            Picker("Type", selection: $draft.kind) {
                ForEach(CameraKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
#endif
        }
    }

    private var displayNameField: some View {
        fieldBlock(title: "Display", caption: "Choose if this camera name appears on pictures, and where.") {
            Toggle("Show camera name on picture", isOn: $draft.showsNameInDisplay)

            if draft.showsNameInDisplay {
#if os(iOS)
                optionButtons(
                    selection: $draft.nameLocation,
                    options: CameraNameLocation.allCases,
                    columns: 2
                ) { $0.title }
#else
                HStack(alignment: .center, spacing: 12) {
                    Text("Position")
                        .foregroundStyle(.secondary)

                    Picker("Position", selection: $draft.nameLocation) {
                        ForEach(CameraNameLocation.allCases) { location in
                            Text(location.title)
                                .tag(location)
                        }
                    }
#if os(iOS)
                    .pickerStyle(.menu)
#else
                    .pickerStyle(.menu)
#endif

                    Spacer(minLength: 0)
                }
#endif
            }
        }
    }

    private var saveButtonTitle: String {
        switch editorState {
        case .idle:
            if isEditing {
                return hasUnsavedCameraChanges ? "Save Changes" : "No Changes"
            }
            return "Add Camera"
        case .validating:
            return "Validating…"
        case .success(let message), .failure(let message):
            return message
        }
    }

    private var saveButtonSymbolName: String? {
        switch editorState {
        case .idle:
            if isEditing {
                return hasUnsavedCameraChanges ? "square.and.arrow.down.fill" : "checkmark.circle.fill"
            }
            return "plus.circle.fill"
        case .validating:
            return nil
        case .success:
            return "checkmark.seal.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    private var saveButtonTint: Color {
        switch editorState {
        case .idle:
            if isEditing {
                return hasUnsavedCameraChanges ? .orange : .gray
            }
            return .accentColor
        case .validating:
            return .accentColor
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                attemptToDismissSettingsSheet()
            }
            .buttonStyle(.bordered)
        }
    }

    private var cameraActionBar: some View {
        HStack(spacing: 12) {
            Button(action: saveCamera) {
                HStack {
                    if editorState.isValidating {
                        ProgressView()
                    } else if let saveButtonSymbolName {
                        Image(systemName: saveButtonSymbolName)
                    }
                    Text(saveButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(saveButtonTint)
            .disabled(isPrimaryActionDisabled)
            .opacity(isPrimaryActionDisabled ? 0.55 : 1)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.75), lineWidth: 1)
        )
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

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .frame(width: 18, height: 18)
                }
                .accessibilityLabel(isPasswordVisible ? "Hide Password" : "Show Password")
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
#if os(iOS)
            optionButtons(
                selection: $draft.feedMode,
                options: CameraFeedMode.allCases,
                columns: 2
            ) { $0.title }
#else
            Picker("Feed Type", selection: $draft.feedMode) {
                ForEach(CameraFeedMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
#endif

            Text(draft.feedMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var genericRTSPURLField: some View {
        fieldBlock(title: "RTSP URL", caption: "Paste the full RTSP stream URL for this camera.") {
            TextField("rtsp://user:password@192.168.1.50:554/stream", text: $draft.genericRTSPURL)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
#endif
                .textFieldStyle(.roundedBorder)
        }
    }

    private var streamVariantField: some View {
        fieldBlock(title: "Stream Variant", caption: streamVariantCaption) {
#if os(iOS)
            optionButtons(
                selection: $draft.streamVariant,
                options: CameraStreamVariant.allCases,
                columns: 2
            ) { $0.title }
#else
            Picker("Stream Variant", selection: $draft.streamVariant) {
                ForEach(CameraStreamVariant.allCases) { variant in
                    Text(variant.title)
                        .tag(variant)
                }
            }
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
            Button {
                copySourceURLToClipboard()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: didCopySourceURL ? "checkmark" : "document.on.document")
                    Text(didCopySourceURL ? "Copied" : "Copy URL")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    didCopySourceURL
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color.primary.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundStyle(didCopySourceURL ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var sourcePreviewTitle: String {
        switch draft.kind {
        case .reolink:
            switch draft.feedMode {
            case .snapshotPolling:
                return "Snapshot URL"
            case .rtsp:
                return "RTSP URL"
            }
        case .genericRTSP:
            return "RTSP URL"
        }
    }

    private var sourcePreviewCaption: String {
        guard draft.isEnabled else {
            return "Stored source. Camera is disabled, so app will not poll or stream it."
        }
        switch draft.kind {
        case .reolink:
            switch draft.feedMode {
            case .snapshotPolling:
                return "Reolink JPEG endpoint used for polling."
            case .rtsp:
                return "RTSP endpoint used for live playback through VLCKit (\(draft.streamVariant.title.lowercased()))."
            }
        case .genericRTSP:
            return "Generic RTSP endpoint used for live playback through VLCKit."
        }
    }

    private var sourcePreviewValue: String {
        switch draft.kind {
        case .reolink:
            switch draft.feedMode {
            case .snapshotPolling:
                return draft.formattedSnapshotURL
            case .rtsp:
                return draft.formattedRTSPURL
            }
        case .genericRTSP:
            return draft.formattedRTSPURL
        }
    }

    private var isEditing: Bool {
        selectedCameraID != nil
    }

    private var hasUnsavedAppSettingsChanges: Bool {
        gridPictureStyleDraft != viewModel.gridPictureStyle || quietHoursDraft != viewModel.quietHours
    }

    private var baselineDraft: CameraConfig {
        guard let selectedCameraID else {
            return .emptyDraft
        }
        return viewModel.cameras.first(where: { $0.id == selectedCameraID }) ?? .emptyDraft
    }

    private var hasUnsavedCameraChanges: Bool {
        comparableDraft(draft) != comparableDraft(baselineDraft)
    }

    private var isPrimaryActionDisabled: Bool {
        let isMissingRequiredField: Bool
        switch draft.kind {
        case .reolink:
            isMissingRequiredField = draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .genericRTSP:
            isMissingRequiredField = draft.genericRTSPURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if isMissingRequiredField || editorState.isValidating {
            return true
        }
        if isEditing && !hasUnsavedCameraChanges {
            return true
        }
        return false
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(title, subtitle: subtitle)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(sectionTitleFont)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func editorGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(settingTitleFont)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quietHoursTimeField(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(settingTitleFont)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
#if os(macOS)
            .datePickerStyle(.field)
#else
            .datePickerStyle(.compact)
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quietHoursEnabledBinding: Binding<Bool> {
        Binding(
            get: { quietHoursDraft.isEnabled },
            set: { quietHoursDraft.isEnabled = $0 }
        )
    }

    private var quietHoursStartDateBinding: Binding<Date> {
        Binding(
            get: { quietHoursDraft.date(for: quietHoursDraft.normalizedStartMinutes) },
            set: { quietHoursDraft.startMinutes = QuietHoursSchedule.minutes(from: $0) }
        )
    }

    private var quietHoursEndDateBinding: Binding<Date> {
        Binding(
            get: { quietHoursDraft.date(for: quietHoursDraft.normalizedEndMinutes) },
            set: { quietHoursDraft.endMinutes = QuietHoursSchedule.minutes(from: $0) }
        )
    }

    private var quietHoursStatusText: String {
        if !quietHoursDraft.isEnabled {
            return "Quiet hours are off."
        }
        let isActive = quietHoursDraft.isActive(at: Date())
        if isActive {
            return "Quiet hours are active now. Cameras are paused until \(quietHoursDraft.endLabel)."
        }
        return "Runs daily from \(quietHoursDraft.startLabel) to \(quietHoursDraft.endLabel)."
    }

    private var sectionTitleFont: Font {
#if os(iOS)
        .title3.weight(.semibold)
#else
        .headline.weight(.semibold)
#endif
    }

    private var settingTitleFont: Font {
#if os(iOS)
        .subheadline.weight(.semibold)
#else
        .headline
#endif
    }

    #if os(iOS)
    private func optionButtons<Option: Identifiable & Hashable>(
        selection: Binding<Option>,
        options: [Option],
        columns: Int,
        title: @escaping (Option) -> String
    ) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)

        return LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(
                            selection.wrappedValue == option
                                ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(Color.primary.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(selection.wrappedValue == option ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    #endif

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

    private func comparableDraft(_ camera: CameraConfig) -> CameraConfig {
        var comparable = camera.sanitized
        comparable.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return comparable
    }

    private func attemptToLeaveEditor(_ action: PendingLeaveAction) {
        if hasUnsavedCameraChanges {
            pendingLeaveAction = action
            showingUnsavedChangesAlert = true
        } else {
            performLeaveAction(action)
        }
    }

    private func performPendingLeaveAction() {
        guard let action = pendingLeaveAction else { return }
        pendingLeaveAction = nil
        performLeaveAction(action)
    }

    private func performLeaveAction(_ action: PendingLeaveAction) {
        switch action {
        case .selectCamera(let camera):
            selectedCameraID = camera.id
            draft = camera
            editorState = .idle
#if os(iOS)
            showingCameraEditorSheet = true
#endif
        case .resetEditor:
            resetEditor()
        case .dismissSheet:
            saveAppSettings()
            dismiss()
#if os(iOS)
        case .dismissEditor:
            showingCameraEditorSheet = false
            resetEditor()
#endif
        }
    }

    private func attemptToDismissSettingsSheet() {
        if hasUnsavedCameraChanges {
            pendingLeaveAction = .dismissSheet
            showingUnsavedChangesAlert = true
        } else {
            performLeaveAction(.dismissSheet)
        }
    }

    #if os(iOS)
    private func beginAddingCamera() {
        resetEditor()
        showingCameraEditorSheet = true
    }

    private func openEditor(for camera: CameraConfig) {
        selectedCameraID = camera.id
        draft = camera
        editorState = .idle
        showingCameraEditorSheet = true
    }

    private func exportConfiguration() {
        do {
            exportDocument = ConfigurationJSONDocument(data: try viewModel.exportConfigurationData())
            showingExportPicker = true
        } catch {
            configurationAlert = ConfigurationAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            try viewModel.importConfigurationData(data)
            syncAppSettingsDraft()
        } catch {
            configurationAlert = ConfigurationAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }
    #endif

    private func resetEditor() {
        selectedCameraID = nil
        draft = .emptyDraft
        editorState = .idle
        isPasswordVisible = false
    }

    private func saveAppSettings() {
        viewModel.gridPictureStyle = gridPictureStyleDraft
        viewModel.quietHours = quietHoursDraft
    }

    private func syncAppSettingsDraft() {
        gridPictureStyleDraft = viewModel.gridPictureStyle
        quietHoursDraft = viewModel.quietHours
    }

    private func copySourceURLToClipboard() {
#if os(iOS)
        UIPasteboard.general.string = sourcePreviewValue
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sourcePreviewValue, forType: .string)
#endif
        didCopySourceURL = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                didCopySourceURL = false
            }
        }
    }
}

#if os(iOS)
private struct ConfigurationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
#endif

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
}
