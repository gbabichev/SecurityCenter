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
        case dismissSheet
        case dismissEditor
    }

    @ObservedObject var viewModel: AppViewModel
    let initialCameraID: CameraConfig.ID?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CameraConfig.emptyDraft
    @State private var selectedCameraID: CameraConfig.ID?
    @State private var editorState: EditorState = .idle
    @State private var isPasswordVisible = false
    @State private var pendingLeaveAction: PendingLeaveAction?
    @State private var showingUnsavedChangesAlert = false
    @State private var showingDeleteCameraConfirmation = false
    @State private var didCopySourceURL = false
    @State private var appThemeDraft: AppTheme = .system
    @State private var gridPictureStyleDraft: GridPictureStyle = .fillEachBox
    @State private var quietHoursDraft = QuietHoursSchedule()
    @State private var showQuietHoursInToolbarDraft = false
    @State private var quietHoursScheduleOverridesManualDraft = false
    @State private var showingCameraEditorSheet = false
#if os(iOS)
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
        }
        .padding(16)
        .onAppear {
            syncAppSettingsDraft()
            openInitialCameraIfNeeded()
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
        .interactiveDismissDisabled(hasUnsavedAppSettingsChanges)
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
        }
        .padding(16)
        .onAppear {
            syncAppSettingsDraft()
            openInitialCameraIfNeeded()
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
        .onChange(of: showingCameraEditorSheet) { _, isPresented in
            if !isPresented {
                showingDeleteCameraConfirmation = false
            }
        }
        .sheet(isPresented: $showingCameraEditorSheet) {
            cameraEditorSheet
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

    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("App Settings", subtitle: "A few preferences for the whole app.")

#if os(macOS)
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(
                    "Theme",
                    systemImage: "circle.lefthalf.filled",
                    subtitle: appThemeDraft.title
                ) {
                    Picker("Theme", selection: $appThemeDraft) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme)
                        }
                    }
                    .frame(maxWidth: 360)
                    .pickerStyle(.segmented)
                }

                Divider()

                SettingsRow(
                    "Camera Grid",
                    systemImage: "square.grid.2x2",
                    subtitle: gridPictureStyleDraft.description
                ) {
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
                fieldBlock(title: "Theme", caption: "Choose how the app should appear.") {
                    optionButtons(
                        selection: $appThemeDraft,
                        options: AppTheme.allCases,
                        columns: 3
                    ) { $0.title }
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
#if os(macOS)
            SettingsRow(
                "Turn on quiet hours",
                systemImage: "moon.fill",
                subtitle: "Black out the screen and pause all camera traffic."
            ) {
                Toggle(isOn: quietHoursEnabledBinding) {
                }
                .toggleStyle(.switch)
            }
#else
            Toggle("Turn on quiet hours", isOn: quietHoursEnabledBinding)
#endif

#if os(macOS)
            SettingsRow(
                "Show Quiet Hours in Toolbar",
                systemImage: "moon",
                subtitle: "Add a toolbar button for turning quiet hours on or off."
            ) {
                Toggle(isOn: $showQuietHoursInToolbarDraft) {
                }
                .toggleStyle(.switch)
            }
#else
            Toggle("Show Quiet Hours in Toolbar", isOn: $showQuietHoursInToolbarDraft)
#endif

#if os(macOS)
            SettingsRow(
                "Schedule Overrides Manual",
                systemImage: "clock",
                subtitle: "Scheduled quiet hours take back over when they start or end."
            ) {
                Toggle(isOn: $quietHoursScheduleOverridesManualDraft) {
                }
                .toggleStyle(.switch)
                .disabled(!showQuietHoursInToolbarDraft)
            }
            .opacity(showQuietHoursInToolbarDraft ? 1 : 0.5)
#else
            Toggle("Schedule Overrides Manual", isOn: $quietHoursScheduleOverridesManualDraft)
                .disabled(!showQuietHoursInToolbarDraft)
#endif

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

    private var cameraSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Camera Settings", subtitle: cameraSettingsSubtitle)
            cameraPickerCard
        }
    }

    private var cameraSettingsSubtitle: String {
        "Pick a camera to edit, or start a new one."
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
#if os(macOS)
        "Click a camera below to edit it."
#else
        "Tap a camera below to edit it."
#endif
    }

    private var cameraEditorSheet: some View {
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
#if os(macOS)
        .frame(minWidth: 760, minHeight: 620)
#endif
    }

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
#if os(macOS)
        VStack(spacing: 12) {
            enabledField
            cameraKindField
        }
#else
        VStack(spacing: 12) {
            enabledField
            cameraKindField
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
    private var basicsEditorFields: some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 12) {
            nameField
            displayNameField
        }
#else
        VStack(spacing: 12) {
            nameField
            displayNameField
        }
#endif
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
#if os(macOS)
        SettingsRow("Type", subtitle: "Choose which kind of camera connection to add.") {
            Picker("Type", selection: $draft.kind) {
                ForEach(CameraKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
#else
        fieldBlock(title: "Type", caption: "Choose which kind of camera connection to add.") {
            optionButtons(
                selection: $draft.kind,
                options: CameraKind.allCases,
                columns: 2
            ) { $0.title }
        }
#endif
    }

    private var displayNameField: some View {
        fieldBlock(title: "Display", caption: "Choose if this camera name appears on pictures, and where.") {
#if os(macOS)
            SettingsRow(
                "Show camera name on picture",
                systemImage: "character.textbox",
                subtitle: "Overlay the camera label on the image."
            ) {
                Toggle(isOn: $draft.showsNameInDisplay) {
                }
                .toggleStyle(.switch)
            }
#else
            Toggle("Show camera name on picture", isOn: $draft.showsNameInDisplay)
#endif

            if draft.showsNameInDisplay {
#if os(iOS)
                optionButtons(
                    selection: $draft.nameLocation,
                    options: CameraNameLocation.allCases,
                    columns: 2
                ) { $0.title }
#else
                SettingsRow("Position") {
                    Picker("Position", selection: $draft.nameLocation) {
                        ForEach(CameraNameLocation.allCases) { location in
                            Text(location.title)
                                .tag(location)
                        }
                    }
                    .pickerStyle(.menu)
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
#if os(macOS)
        SettingsRow(
            "Protocol",
            systemImage: "lock.shield",
            subtitle: "Use HTTPS instead of HTTP for JPG snapshots."
        ) {
            Toggle(isOn: $draft.useHTTPS) {
            }
            .toggleStyle(.switch)
        }
#else
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
#endif
    }

    private var pollingFrequencyField: some View {
#if os(macOS)
        SettingsRow(
            "Update Every",
            systemImage: "clock.arrow.circlepath",
            subtitle: "Choose how often JPG pictures refresh."
        ) {
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
                    .frame(minWidth: 32, alignment: .trailing)
            }
            .frame(maxWidth: 160)
        }
#else
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
#endif
    }

    private var enabledField: some View {
#if os(macOS)
        SettingsRow(
            "Camera enabled",
            systemImage: "power",
            subtitle: "Allow this camera to appear and connect normally."
        ) {
            Toggle("", isOn: $draft.isEnabled)
                .toggleStyle(.switch)
        }
#else
        Toggle("Camera enabled", isOn: $draft.isEnabled)
#endif
    }

    @ViewBuilder
    private var cameraTypeEditorFields: some View {
#if os(macOS)
        VStack(spacing: 12) {
            feedModeField
            streamVariantField
        }
#else
        VStack(spacing: 12) {
            feedModeField
            streamVariantField
        }
#endif
    }

    private var feedModeField: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow("Feed Type", subtitle: "Choose camera source for display and probing.") {
                Picker("Feed Type", selection: $draft.feedMode) {
                    ForEach(CameraFeedMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            Text(draft.feedMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
#else
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
#endif
    }

    private var genericRTSPURLField: some View {
        fieldBlock(title: "Camera Link", caption: "Paste the full live video link for this camera.") {
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
#if os(macOS)
        SettingsRow("Stream Variant", subtitle: streamVariantCaption) {
            Picker("Stream Variant", selection: $draft.streamVariant) {
                ForEach(CameraStreamVariant.allCases) { variant in
                    Text(variant.title)
                        .tag(variant)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
#else
        fieldBlock(title: "Stream Variant", caption: streamVariantCaption) {
            optionButtons(
                selection: $draft.streamVariant,
                options: CameraStreamVariant.allCases,
                columns: 2
            ) { $0.title }
        }
#endif
    }

    private var muteCameraField: some View {
#if os(macOS)
        SettingsRow(
            "Mute Camera",
            systemImage: "speaker.slash",
            subtitle: "Turn off audio playback for this stream."
        ) {
            Toggle(isOn: $draft.isMuted) {
            }
            .toggleStyle(.switch)
        }
#else
        Toggle("Mute Camera", isOn: $draft.isMuted)
#endif
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
        appThemeDraft != viewModel.appTheme
            || gridPictureStyleDraft != viewModel.gridPictureStyle
            || quietHoursDraft != viewModel.quietHours
            || showQuietHoursInToolbarDraft != viewModel.showQuietHoursInToolbar
            || quietHoursScheduleOverridesManualDraft != viewModel.quietHoursScheduleOverridesManual
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
#if os(macOS)
        SettingsRow(title) {
            DatePicker(
                title,
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.field)
        }
#else
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
#endif
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
        case .dismissSheet:
            saveAppSettings()
            dismiss()
        case .dismissEditor:
            showingCameraEditorSheet = false
            resetEditor()
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

    private func beginAddingCamera() {
        resetEditor()
        showingCameraEditorSheet = true
    }

    private func openInitialCameraIfNeeded() {
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
        isPasswordVisible = false
    }

    private func saveAppSettings() {
        viewModel.appTheme = appThemeDraft
        viewModel.gridPictureStyle = gridPictureStyleDraft
        viewModel.quietHours = quietHoursDraft
        viewModel.showQuietHoursInToolbar = showQuietHoursInToolbarDraft
        viewModel.quietHoursScheduleOverridesManual = quietHoursScheduleOverridesManualDraft
    }

    private func syncAppSettingsDraft() {
        appThemeDraft = viewModel.appTheme
        gridPictureStyleDraft = viewModel.gridPictureStyle
        quietHoursDraft = viewModel.quietHours
        showQuietHoursInToolbarDraft = viewModel.showQuietHoursInToolbar
        quietHoursScheduleOverridesManualDraft = viewModel.quietHoursScheduleOverridesManual
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
