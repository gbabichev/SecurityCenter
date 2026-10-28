//
//  ConfigurationTransferView.swift
//  Security Center
//
//  Created by Codex on 4/28/26.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationTransferView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingRemoveAllCamerasConfirmation = false
    @State private var showingResetGridsConfirmation = false
    @State private var exportDocument = ConfigurationJSONDocument(data: Data())
    @State private var importRequest: ConfigurationImportRequest?
    @State private var importCompleted = false
    @State private var alert: ConfigurationTransferAlert?

    var body: some View {
        Form {
            Section {
                importSection
            } header: {
                Text("Import Configuration")
            } footer: {
                Text("Choose what to import. Existing cameras and grids are kept; selected preferences are updated.")
            }
            Section("Export Configuration") {
                exportSection
            }
            Section {
                HStack {
                    Text("Remove every camera from this app.")
                    Spacer()
                    Button("Remove All Cameras…", role: .destructive) {
                        showingRemoveAllCamerasConfirmation = true
                    }
                    .disabled(viewModel.cameras.isEmpty)
                }
            } header: {
                Text("Reset Cameras")
            } footer: {
                Text("Saved grids and preferences are kept. Export your configuration first if you want a backup.")
            }
            Section {
                HStack {
                    Text("Restore a single empty 2×2 grid.")
                    Spacer()
                    Button("Reset Grids…", role: .destructive) {
                        showingResetGridsConfirmation = true
                    }
                }
            } header: {
                Text("Reset Grids")
            } footer: {
                Text("Removes saved grids and their camera assignments. Cameras and preferences are kept.")
            }
        }
        .formStyle(.grouped)
        .alert("Remove All Cameras?", isPresented: $showingRemoveAllCamerasConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove All Cameras", role: .destructive) {
                viewModel.deleteAllCameras()
            }
        } message: {
            Text("This permanently removes all cameras and clears their grid assignments. This cannot be undone.")
        }
        .alert("Reset All Grids?", isPresented: $showingResetGridsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Grids", role: .destructive) {
                viewModel.resetGrids()
            }
        } message: {
            Text("This removes every saved grid and its camera assignments, then creates an empty 2×2 grid. Your cameras are kept. This cannot be undone.")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result: result)
        }
        .sheet(item: $importRequest, onDismiss: {
            if importCompleted {
                importCompleted = false
                alert = ConfigurationTransferAlert(title: "Import Complete", message: "The selected configuration items were added.")
            }
        }) { request in
            ConfigurationImportSheet(viewModel: viewModel, request: request) {
                importCompleted = true
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Security Center"
        ) { result in
            if case .failure(let error) = result {
                alert = ConfigurationTransferAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var importSection: some View {
        HStack {
            Text("Choose a file, then review what to import.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Choose File…", systemImage: "doc.badge.plus") {
                showingImporter = true
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Save all cameras, grids, and preferences to a file.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    exportConfiguration()
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func handleImportSelection(result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let preview = try viewModel.previewConfigurationImport(data)
            importRequest = ConfigurationImportRequest(data: data, fileName: url.lastPathComponent, preview: preview)
        } catch {
            alert = ConfigurationTransferAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func exportConfiguration() {
        do {
            exportDocument = ConfigurationJSONDocument(data: try viewModel.exportConfigurationData())
            showingExporter = true
        } catch {
            alert = ConfigurationTransferAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

}

private struct ConfigurationImportRequest: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
    let preview: ConfigurationImportPreview
}

private enum ConfigurationImportPage: String, CaseIterable, Identifiable {
    case cameras = "Cameras", grids = "Grids", preferences = "Preferences"
    var id: Self { self }
}

private struct ConfigurationImportSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let request: ConfigurationImportRequest
    let onImported: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var page: ConfigurationImportPage = .cameras
    @State private var options: ConfigurationImportOptions
    @State private var alert: ConfigurationTransferAlert?

    init(viewModel: AppViewModel, request: ConfigurationImportRequest, onImported: @escaping () -> Void) {
        self.viewModel = viewModel
        self.request = request
        self.onImported = onImported
        _options = State(initialValue: ConfigurationImportOptions(
            selectedCameraIDs: Set(request.preview.cameras.map(\.id)),
            selectedGridIDs: Set(request.preview.grids.map(\.id)),
            importsAppSettings: false,
            importsQuietHours: false
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import Configuration")
                    .font(.title2.weight(.semibold))
                Label(request.fileName, systemImage: "doc.text")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Picker("Import category", selection: $page) {
                    ForEach(ConfigurationImportPage.allCases) { page in
                        Text(LocalizedStringKey(page.rawValue)).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(20)
            Divider()
            Form {
                switch page {
                case .cameras:
                    ConfigurationImportItemGroup(title: "Cameras", items: request.preview.cameras, selection: $options.selectedCameraIDs)
                case .grids:
                    ConfigurationImportItemGroup(title: "Grids", items: request.preview.grids, selection: $options.selectedGridIDs)
                case .preferences:
                    Section {
                        Toggle("App display settings", isOn: $options.importsAppSettings)
                            .disabled(!request.preview.includesAppSettings)
                        Toggle("Quiet hours", isOn: $options.importsQuietHours)
                            .disabled(!request.preview.includesQuietHours)
                    } header: {
                        Text("Preferences")
                    } footer: {
                        Text("Selected preferences replace your current settings. Unavailable options are not included in this file.")
                    }
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Existing cameras and grids are kept. Selected preferences are updated.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Selected: \(options.selectedCameraIDs.count) cameras, \(options.selectedGridIDs.count) grids")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Import Selected", action: applyImport)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canImport)
                }
            }
            .padding(20)
        }
        .frame(width: 640, height: 560)
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private var canImport: Bool {
        !options.selectedCameraIDs.isEmpty || !options.selectedGridIDs.isEmpty ||
            options.importsAppSettings || options.importsQuietHours
    }

    private func applyImport() {
        do {
            try viewModel.importConfigurationData(request.data, options: options)
            onImported()
            dismiss()
        } catch {
            alert = ConfigurationTransferAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }
}

private struct ConfigurationImportItemGroup: View {
    let title: LocalizedStringKey
    let items: [ConfigurationImportItem]
    @Binding var selection: Set<UUID>

    var body: some View {
        Section {
            if items.isEmpty {
                Text("No items in this file.")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("\(selection.count) of \(items.count) selected")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") { selection = Set(items.map(\.id)) }
                        .disabled(selection.count == items.count)
                    Button("Deselect All") { selection = [] }
                        .disabled(selection.isEmpty)
                }
                ForEach(items) { item in
                    Toggle(isOn: itemSelection(item.id)) {
                        Text(item.name)
                    }
                }
            }
        } header: {
            Text(title)
        }
    }

    private func itemSelection(_ id: UUID) -> Binding<Bool> {
        Binding {
            selection.contains(id)
        } set: { isSelected in
            if isSelected { selection.insert(id) } else { selection.remove(id) }
        }
    }
}

private struct ConfigurationTransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
#endif
