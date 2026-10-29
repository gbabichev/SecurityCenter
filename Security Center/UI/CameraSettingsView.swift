//
//  CameraSettingsView.swift
//  Security Center
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
#if os(iOS)
        case dismissSheet
#endif
        case dismissEditor
        case addCamera
    }

    @ObservedObject var viewModel: AppViewModel
    let initialCameraID: CameraConfig.ID?
    let startsAddingCamera: Bool
    var presentsEditorDirectly = false
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CameraConfig.emptyDraft
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var editorState: CameraEditorState = .idle
    @State private var connectionCheckState: CameraEditorState = .idle
    @State private var isPasswordVisible = false
    @State private var pendingLeaveAction: PendingLeaveAction?
    @State private var showingUnsavedChangesAlert = false
    @State private var showingDeleteCameraConfirmation = false
    @State private var didCopySourceURL = false
#if os(iOS)
    @State private var appThemeDraft: AppTheme = .system
    @State private var debugLoggingEnabledDraft = false
    @State private var blurredCameraBackgroundDraft = false
    @State private var viewBackgroundStyleDraft: ViewBackgroundStyle = .systemDefault
    @State private var keepsScreenAwakeDraft = false
    @State private var gridPictureStyleDraft: GridPictureStyle = .fillEachBox
    @State private var quietHoursDraft = QuietHoursSchedule()
    @State private var showQuietHoursInToolbarDraft = false
    @State private var quietHoursScheduleOverridesManualDraft = false
#endif

    @State private var showingCameraEditorSheet = false
    @State private var didHandleInitialPresentation = false
#if os(iOS)
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var showingAbout = false
    @State private var exportDocument = ConfigurationJSONDocument(data: Data())
    @State private var configurationAlert: ConfigurationAlert?
#endif

    var body: some View {
        if presentsEditorDirectly {
            directEditor
        } else {
#if os(macOS)
            macBody
#else
            iosBody
#endif
        }
    }

    private var directEditor: some View {
        cameraEditorSheet
            .onAppear { handleInitialPresentationIfNeeded() }
            .onChange(of: draft) { _, _ in
                guard !editorState.isValidating, !connectionCheckState.isValidating else { return }
                editorState = .idle
                connectionCheckState = .idle
            }
            .onChange(of: draft.kind) { _, kind in
                if kind == .genericRTSP { draft.feedMode = .rtsp }
            }
            .onChange(of: viewModel.cameras) { _, cameras in
                if let selectedCameraID, !cameras.contains(where: { $0.id == selectedCameraID }) {
                    dismiss()
                }
            }
    }

    #if os(macOS)
    private var macBody: some View {
        MacCameraSettingsList(viewModel: viewModel, onAdd: beginAddingCamera, onEdit: openEditor)
        .onChange(of: draft) { _, _ in
            guard !editorState.isValidating, !connectionCheckState.isValidating else { return }
            editorState = .idle
            connectionCheckState = .idle
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
        .onChange(of: showingCameraEditorSheet) { _, isPresented in
            if !isPresented {
                showingDeleteCameraConfirmation = false
            }
        }
        .sheet(isPresented: $showingCameraEditorSheet) {
            cameraEditorSheet
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
        }
        .padding(16)
        .onAppear {
            syncAppSettingsDraft()
            handleInitialPresentationIfNeeded()
        }
        .onChange(of: draft) { _, _ in
            guard !editorState.isValidating, !connectionCheckState.isValidating else { return }
            editorState = .idle
            connectionCheckState = .idle
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
        .onChange(of: showingCameraEditorSheet) { _, isPresented in
            if !isPresented {
                showingDeleteCameraConfirmation = false
            }
        }
        .sheet(isPresented: $showingCameraEditorSheet) {
            cameraEditorSheet
        }
        .sheet(isPresented: $showingAbout) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AboutView()
                    }
                    .padding(.top, 12)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showingAbout = false
                        }
                    }
                }
            }
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
            defaultFilename: "Security Center"
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

#if os(iOS)
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("App Settings", subtitle: "A few preferences for the whole app.")

            VStack(alignment: .leading, spacing: 12) {
                fieldBlock(title: "Theme", caption: "Choose how the app should appear.") {
                    optionButtons(
                        selection: $appThemeDraft,
                        options: AppTheme.allCases,
                        columns: 3
                    ) { $0.title }
                }

                fieldBlock(title: "View Background", caption: "Choose the background behind camera views.") {
                    optionButtons(
                        selection: $viewBackgroundStyleDraft,
                        options: ViewBackgroundStyle.allCases,
                        columns: 3
                    ) { $0.title }
                }

                Toggle("Blur camera background", isOn: $blurredCameraBackgroundDraft)

                fieldBlock(title: "Keep Screen Awake", caption: "Prevent the screen from sleeping, including during quiet hours.") {
                    HStack {
                        Text(keepsScreenAwakeDraft ? "On" : "Off")
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Toggle("Keep Screen Awake", isOn: $keepsScreenAwakeDraft)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

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

                fieldBlock(title: "Diagnostics", caption: "Record streaming details to help investigate camera problems. Logging starts when you tap Done.") {
                    Toggle("Enable Debug Logging", isOn: $debugLoggingEnabledDraft)
                    ShareLink(item: StreamDebugLog.shared.fileURL) {
                        Label("Share Debug Log", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!FileManager.default.fileExists(atPath: StreamDebugLog.shared.fileURL.path))
                    if let error = viewModel.debugLoggingError { Text(error).foregroundStyle(.red) }
                }

                fieldBlock(title: "Configuration", caption: "Import or export your app settings and cameras as JSON.") {
                    VStack(spacing: 10) {
                        Button {
                            showingAbout = true
                        } label: {
                            Label("About", systemImage: "info.circle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

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
            }
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

            Toggle("Show Quiet Hours in Toolbar", isOn: $showQuietHoursInToolbarDraft)

            Toggle("Schedule Overrides Manual", isOn: $quietHoursScheduleOverridesManualDraft)
                .disabled(!showQuietHoursInToolbarDraft)

            if quietHoursDraft.isEnabled {
                VStack(spacing: 12) {
                    quietHoursTimeField(title: "Start", selection: quietHoursStartDateBinding)
                    quietHoursTimeField(title: "End", selection: quietHoursEndDateBinding)
                }
            }

            Text(quietHoursStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Camera setup and app behavior.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                attemptToDismissSettingsSheet()
            }
            .buttonStyle(.bordered)
        }
    }
    private var cameraPickerCard: some View {
        settingsCard(title: "Cameras", subtitle: cameraPickerSubtitle) {
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
                                        HStack(spacing: 6) {
                                            Text(camera.connectionSummary)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            if camera.feedMode == .rtsp {
                                                Image(systemName: camera.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                    .accessibilityLabel(camera.isMuted ? "Muted" : "Audio enabled")
                                            }
                                        }
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
                                .background(
                                    selectedCameraID == camera.id
                                        ? AnyShapeStyle(.thinMaterial)
                                        : AnyShapeStyle(Color.primary.opacity(0.035)),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
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

    private var cameraPickerSubtitle: String {
        "Tap a camera below to edit it."
    }

#endif

    private var cameraEditorSheetContent: some View {
#if os(macOS)
        MacCameraEditor(
            draft: $draft,
            state: editorState,
            connectionCheckState: connectionCheckState,
            hasUnsavedChanges: hasUnsavedCameraChanges,
            isEditing: isEditing,
            canSave: !isPrimaryActionDisabled,
            didCopyLink: didCopySourceURL,
            onCancel: { attemptToLeaveEditor(.dismissEditor) },
            onSave: saveCamera,
            onDelete: { showingDeleteCameraConfirmation = true },
            onCopy: copyCamera,
            onCopyLink: copySourceURLToClipboard,
            onCheckConnection: checkCameraConnection
        )
#else
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
#endif
    }

    private var cameraEditorSheet: some View {
        cameraEditorSheetContent
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
        .confirmationDialog(
            "Delete Camera?",
            isPresented: $showingDeleteCameraConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Camera", role: .destructive) {
                deleteCurrentCamera()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the camera from the app.")
        }
        .interactiveDismissDisabled(hasUnsavedCameraChanges)
    }

#if os(iOS)
    private var editorCard: some View {
        settingsCard(
            title: isEditing ? "Edit Camera" : "Add Camera",
            subtitle: isEditing ? "Save updates after source validation." : "Camera is saved only after source validation."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorGroup("Camera Type") {
                    cameraTypePrimaryFields
                    if draft.kind == .reolink {
                        cameraTypeEditorFields
                    }
                }

                editorGroup("Basics") {
                    basicsEditorFields
                }

                editorGroup("Camera") {
                    if draft.kind == .reolink {
                        addressField
                        credentialsSection

                        if draft.feedMode == .snapshotPolling {
                            if draft.isEnabled {
                                protocolField
                            }
                            pollingFrequencyField
                        }

                        if draft.feedMode == .rtsp {
                            muteCameraField
                        }
                    } else {
                        genericRTSPURLField
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
    private var cameraTypePrimaryFields: some View {
        VStack(spacing: 12) {
            enabledField
            cameraKindField
        }
    }

    private var nameField: some View {
        fieldBlock(title: "Name", caption: "Optional label.") {
            TextField("Front Door", text: $draft.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var basicsEditorFields: some View {
        VStack(spacing: 12) {
            nameField
            displayNameField
        }
    }

    private var addressField: some View {
        fieldBlock(title: "Address", caption: "IP or host name.") {
            TextField("192.168.1.50", text: $draft.host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var cameraKindField: some View {
        fieldBlock(title: "Type", caption: "Choose which kind of camera connection to add.") {
            optionButtons(
                selection: $draft.kind,
                options: CameraKind.allCases,
                columns: 2
            ) { $0.title }
        }
    }

    private var displayNameField: some View {
        fieldBlock(title: "Display", caption: "Choose if this camera name appears on pictures, and where.") {
            Toggle("Show camera name on picture", isOn: $draft.showsNameInDisplay)

            if draft.showsNameInDisplay {
                optionButtons(
                    selection: $draft.nameLocation,
                    options: CameraNameLocation.allCases,
                    columns: 2
                ) { $0.title }
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

    private var cameraActionBar: some View {
        HStack(spacing: 12) {
            if isEditing {
                Button(role: .destructive) {
                    showingDeleteCameraConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Delete")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)

                Button(action: copyCamera) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
            }

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
        VStack(spacing: 12) {
            usernameField
            passwordField
        }
    }

    private var usernameField: some View {
        fieldBlock(title: "Username", caption: "Camera login user.") {
            TextField("admin", text: $draft.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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

    private var pollingFrequencyField: some View {
        fieldBlock(title: "Update Every", caption: "Choose how often JPG pictures refresh.") {
            HStack(spacing: 12) {
                Stepper(
                    "Update Every",
                    value: $draft.snapshotPollingIntervalSeconds,
                    in: 1...10
                )
                .labelsHidden()

                Text("\(draft.snapshotPollingIntervalSeconds)s")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .trailing)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var enabledField: some View {
        Toggle("Camera enabled", isOn: $draft.isEnabled)
    }

    @ViewBuilder
    private var cameraTypeEditorFields: some View {
        VStack(spacing: 12) {
            feedModeField
            streamVariantField
        }
    }

    private var feedModeField: some View {
        fieldBlock(title: "Feed Type", caption: "Choose camera source for display and probing.") {
            optionButtons(
                selection: $draft.feedMode,
                options: CameraFeedMode.allCases,
                columns: 2
            ) { $0.title }

            Text(draft.feedMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var genericRTSPURLField: some View {
        fieldBlock(title: "Camera Link", caption: "Paste the full live video link for this camera.") {
            TextField("rtsp://user:password@192.168.1.50:554/stream", text: $draft.genericRTSPURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var streamVariantField: some View {
        fieldBlock(title: "Stream Variant", caption: streamVariantCaption) {
            optionButtons(
                selection: $draft.streamVariant,
                options: CameraStreamVariant.allCases,
                columns: 2
            ) { $0.title }
        }
    }

    private var muteCameraField: some View {
        Toggle("Mute Camera", isOn: $draft.isMuted)
    }

    private var streamVariantCaption: String {
        switch draft.feedMode {
        case .snapshotPolling:
            return "Choose the larger or smaller picture."
        case .rtsp:
            return "Choose the larger or smaller live view."
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
        "Camera Link"
    }

    private var sourcePreviewCaption: String {
        guard draft.isEnabled else {
            return "Saved camera link. This camera is turned off right now."
        }
        switch draft.kind {
        case .reolink:
            switch draft.feedMode {
            case .snapshotPolling:
                return "Camera link used for picture updates."
            case .rtsp:
                return draft.streamVariant == .main
                    ? "Camera link used for the larger live view."
                    : "Camera link used for the smaller live view."
            }
        case .genericRTSP:
            return "Camera link used for live video."
        }
    }

#endif

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

#if os(iOS)
    private var hasUnsavedAppSettingsChanges: Bool {
        appThemeDraft != viewModel.appTheme
            || debugLoggingEnabledDraft != viewModel.debugLoggingEnabled
            || blurredCameraBackgroundDraft != viewModel.blurredCameraBackground
            || viewBackgroundStyleDraft != viewModel.viewBackgroundStyle
            || keepsScreenAwakeDraft != viewModel.keepsScreenAwake
            || gridPictureStyleDraft != viewModel.gridPictureStyle
            || quietHoursDraft != viewModel.quietHours
            || showQuietHoursInToolbarDraft != viewModel.showQuietHoursInToolbar
            || quietHoursScheduleOverridesManualDraft != viewModel.quietHoursScheduleOverridesManual
    }

#endif

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

#if os(iOS)
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
            .datePickerStyle(.compact)
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
        .title3.weight(.semibold)
    }

    private var settingTitleFont: Font {
        .subheadline.weight(.semibold)
    }

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

    private func checkCameraConnection() {
        guard !editorState.isValidating, !connectionCheckState.isValidating else { return }
        let candidate = draft
        connectionCheckState = .validating
        Task {
            do {
                try await viewModel.checkCameraConnection(from: candidate)
                connectionCheckState = .success("Connection successful.")
            } catch {
                connectionCheckState = .failure(error.localizedDescription)
            }
        }
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

    private func copyCamera() {
        guard isEditing else { return }
        let copy = viewModel.duplicateCamera(draft.sanitized)
        selectedCameraID = copy.id
        draft = copy
        editorState = .success("\(copy.displayName) copied.")
    }

    private func deleteCurrentCamera() {
        guard let selectedCameraID,
              let camera = viewModel.cameras.first(where: { $0.id == selectedCameraID }) else {
            return
        }
        showingDeleteCameraConfirmation = false
        DispatchQueue.main.async {
            viewModel.deleteCamera(camera)
            showingCameraEditorSheet = false
            resetEditor()
            if presentsEditorDirectly { dismiss() }
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
            showingCameraEditorSheet = true
#if os(iOS)
        case .dismissSheet:
            saveAppSettings()
            dismiss()
#endif
        case .dismissEditor:
            showingCameraEditorSheet = false
            resetEditor()
            if presentsEditorDirectly { dismiss() }
        case .addCamera:
            beginAddingCamera()
        }
    }

#if os(iOS)
    private func attemptToDismissSettingsSheet() {
        if hasUnsavedCameraChanges {
            pendingLeaveAction = .dismissSheet
            showingUnsavedChangesAlert = true
        } else {
            performLeaveAction(.dismissSheet)
        }
    }

#endif

    private func beginAddingCamera() {
        resetEditor()
        showingCameraEditorSheet = true
    }

    private func handleInitialPresentationIfNeeded() {
        guard !didHandleInitialPresentation else { return }
        didHandleInitialPresentation = true

        if startsAddingCamera {
            beginAddingCamera()
            return
        }

        guard let initialCameraID,
              let camera = viewModel.cameras.first(where: { $0.id == initialCameraID }) else {
            return
        }
        openEditor(for: camera)
    }

    private func openEditor(for camera: CameraConfig) {
        selectedCameraID = camera.id
        draft = camera
        editorState = .idle
        showingCameraEditorSheet = true
    }

#if os(iOS)

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
        connectionCheckState = .idle
        isPasswordVisible = false
    }

#if os(iOS)
    private func saveAppSettings() {
        viewModel.debugLoggingEnabled = debugLoggingEnabledDraft
        viewModel.appTheme = appThemeDraft
        viewModel.blurredCameraBackground = blurredCameraBackgroundDraft
        viewModel.viewBackgroundStyle = viewBackgroundStyleDraft
        viewModel.keepsScreenAwake = keepsScreenAwakeDraft
        viewModel.gridPictureStyle = gridPictureStyleDraft
        viewModel.quietHours = quietHoursDraft
        viewModel.showQuietHoursInToolbar = showQuietHoursInToolbarDraft
        viewModel.quietHoursScheduleOverridesManual = quietHoursScheduleOverridesManualDraft
    }

    private func syncAppSettingsDraft() {
        debugLoggingEnabledDraft = viewModel.debugLoggingEnabled
        appThemeDraft = viewModel.appTheme
        blurredCameraBackgroundDraft = viewModel.blurredCameraBackground
        viewBackgroundStyleDraft = viewModel.viewBackgroundStyle
        keepsScreenAwakeDraft = viewModel.keepsScreenAwake
        gridPictureStyleDraft = viewModel.gridPictureStyle
        quietHoursDraft = viewModel.quietHours
        showQuietHoursInToolbarDraft = viewModel.showQuietHoursInToolbar
        quietHoursScheduleOverridesManualDraft = viewModel.quietHoursScheduleOverridesManual
    }

#endif

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

enum CameraEditorState {
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
