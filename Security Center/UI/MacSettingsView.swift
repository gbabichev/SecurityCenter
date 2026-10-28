#if os(macOS)
import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class MacSettingsNavigation {
    var selection: MacSettingsTab = .general
    var cameraRequest: CameraSettingsRequest?

    func editCamera(_ id: CameraConfig.ID? = nil) {
        selection = .cameras
        cameraRequest = CameraSettingsRequest(cameraID: id)
    }
}

enum MacSettingsTab: Hashable {
    case general, quietHours, cameras, grids, configuration
}

struct CameraSettingsRequest: Equatable {
    let id = UUID()
    let cameraID: CameraConfig.ID?
}

struct MacSettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(MacSettingsNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selection) {
            GeneralSettingsPane(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(MacSettingsTab.general)
            QuietHoursSettingsPane(viewModel: viewModel)
                .tabItem { Label("Quiet Hours", systemImage: "moon") }
                .tag(MacSettingsTab.quietHours)
            CameraSettingsView(viewModel: viewModel, initialCameraID: nil, startsAddingCamera: false)
                .tabItem { Label("Cameras", systemImage: "video") }
                .tag(MacSettingsTab.cameras)
            GridSettingsPane(viewModel: viewModel)
                .tabItem { Label("Grids", systemImage: "square.grid.2x2") }
                .tag(MacSettingsTab.grids)
            ConfigurationTransferView(viewModel: viewModel)
                .tabItem { Label("Configuration", systemImage: "arrow.up.arrow.down") }
                .tag(MacSettingsTab.configuration)
        }
        .frame(width: 680, height: 500)
        .preferredColorScheme(viewModel.appTheme.colorScheme)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var logFolderError: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Blur camera background", isOn: $viewModel.blurredCameraBackground)
                Picker("Theme", selection: $viewModel.appTheme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                Picker("Camera background", selection: $viewModel.viewBackgroundStyle) {
                    ForEach(ViewBackgroundStyle.allCases) { Text($0.title).tag($0) }
                }
            }
            Section {
                Toggle("Keep screen awake", isOn: $viewModel.keepsScreenAwake)
            } header: {
                Text("Display")
            } footer: {
                Text("Prevent the screen from sleeping, including during quiet hours.")
            }
            Section {
                Toggle("Enable Debug Logging", isOn: $viewModel.debugLoggingEnabled)
                Button("Show Logs in Finder", systemImage: "folder") {
                    let folder = StreamDebugLog.shared.directoryURL
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    } catch { logFolderError = error.localizedDescription }
                }
                if let error = viewModel.debugLoggingError {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Records streaming events, decoder messages, and frame statistics. Keeps up to 20 MB of recent logs, including across app restarts.")
            }
        }
        .formStyle(.grouped)
        .alert("Could Not Open Logs", isPresented: Binding(get: { logFolderError != nil }, set: { if !$0 { logFolderError = nil } })) {
            Button("OK") { logFolderError = nil }
        } message: {
            Text(logFolderError ?? "")
        }
    }
}

private struct QuietHoursSettingsPane: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Enable daily schedule", isOn: $viewModel.quietHours.isEnabled)
                DatePicker("Start", selection: timeBinding(isStart: true), displayedComponents: .hourAndMinute)
                    .disabled(!viewModel.quietHours.isEnabled)
                DatePicker("End", selection: timeBinding(isStart: false), displayedComponents: .hourAndMinute)
                    .disabled(!viewModel.quietHours.isEnabled)
            } header: {
                Text("Daily Schedule")
            } footer: {
                Text("Black out the screen and pause all cameras during these hours. A schedule can run overnight.")
            }
            Section {
                Toggle("Show quiet hours button in toolbar", isOn: $viewModel.showQuietHoursInToolbar)
                Toggle("Let schedule override manual changes", isOn: $viewModel.quietHoursScheduleOverridesManual)
                    .disabled(!viewModel.showQuietHoursInToolbar)
            } header: {
                Text("Manual Control")
            } footer: {
                Text("When enabled, the schedule takes over again at its next start or end time.")
            }
            Section {
                LabeledContent("Current status", value: viewModel.isQuietHoursActive ? "Cameras paused" : "Cameras active")
            }
        }
        .formStyle(.grouped)
    }

    private func timeBinding(isStart: Bool) -> Binding<Date> {
        Binding {
            let schedule = viewModel.quietHours
            return schedule.date(for: isStart ? schedule.normalizedStartMinutes : schedule.normalizedEndMinutes)
        } set: { date in
            var schedule = viewModel.quietHours
            if isStart {
                schedule.startMinutes = QuietHoursSchedule.minutes(from: date)
            } else {
                schedule.endMinutes = QuietHoursSchedule.minutes(from: date)
            }
            viewModel.quietHours = schedule
        }
    }
}

struct MacCameraSettingsList: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var cameraToDelete: CameraConfig?
    let onAdd: () -> Void
    let onEdit: (CameraConfig) -> Void

    var body: some View {
        if viewModel.cameras.isEmpty {
            MacCameraSettingsEmptyState(onAdd: onAdd)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                MacCameraSettingsHeader(count: viewModel.cameras.count, onAdd: onAdd)
                Divider()
                List(viewModel.cameras) { camera in
                    MacCameraSettingsRow(
                        camera: camera,
                        onEdit: { onEdit(camera) },
                        onCopy: { _ = viewModel.duplicateCamera(camera) },
                        onDelete: { cameraToDelete = camera }
                    )
                        .contextMenu {
                            Button("Edit…") { onEdit(camera) }
                            Button("Copy Camera") { _ = viewModel.duplicateCamera(camera) }
                            Button("Delete", role: .destructive) { cameraToDelete = camera }
                        }
                }
                .listStyle(.inset)
            }
            .alert(item: $cameraToDelete) { camera in
                Alert(
                    title: Text("Delete Camera?"),
                    message: Text("Delete “\(camera.displayName)” and remove it from all grids? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete Camera")) {
                        cameraToDelete = nil
                        DispatchQueue.main.async { viewModel.deleteCamera(camera) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

private struct MacCameraSettingsEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Cameras", systemImage: "video")
        } description: {
            Text("Add a camera to start building your security view.")
        } actions: {
            Button("Add Camera…", systemImage: "plus", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct MacCameraSettingsHeader: View {
    let count: Int
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text("\(count) cameras")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Add Camera…", systemImage: "plus", action: onAdd)
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MacCameraSettingsRow: View {
    let camera: CameraConfig
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: camera.isEnabled ? "video" : "video.slash")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.displayName).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(camera.hostSummary)
                        if camera.feedMode == .rtsp {
                            Image(systemName: camera.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .accessibilityLabel(camera.isMuted ? "Muted" : "Audio enabled")
                        }
                        if !camera.isEnabled { Text("Disabled") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onEdit)
            CameraRowActionButton(title: "Edit Camera", systemImage: "pencil", action: onEdit)
            CameraRowActionButton(title: "Copy Camera", systemImage: "doc.on.doc", action: onCopy)
            CameraRowActionButton(title: "Delete Camera", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 6)
    }
}

private struct CameraRowActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 20, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(title)
    }
}
#endif
