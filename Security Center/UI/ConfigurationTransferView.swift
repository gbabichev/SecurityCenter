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
    @State private var importData: Data?
    @State private var importFileName: String?
    @State private var importPreview: ConfigurationImportPreview?
    @State private var importOptions = ConfigurationImportOptions.additiveDefault
    @State private var camerasExpanded = true
    @State private var gridsExpanded = true
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add from a file")
                Spacer()
                Button {
                    showingImporter = true
                } label: {
                    Label("Choose File…", systemImage: "doc.badge.plus")
                }
            }

            if let importFileName, let importPreview {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(importFileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }

                    ConfigurationImportItemGroup(
                        title: "Cameras",
                        systemImage: "video",
                        items: importPreview.cameras,
                        selection: $importOptions.selectedCameraIDs,
                        isExpanded: $camerasExpanded
                    )

                    Divider()

                    ConfigurationImportItemGroup(
                        title: "Grids",
                        systemImage: "square.grid.2x2",
                        items: importPreview.grids,
                        selection: $importOptions.selectedGridIDs,
                        isExpanded: $gridsExpanded
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("App display settings", isOn: $importOptions.importsAppSettings)
                            .disabled(!importPreview.includesAppSettings)
                        Toggle("Quiet hours", isOn: $importOptions.importsQuietHours)
                            .disabled(!importPreview.includesQuietHours)
                    }
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !previewSummary(importPreview).isEmpty {
                        Text(previewSummary(importPreview))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        Spacer()
                        Button {
                            applyImport()
                        } label: {
                            Label("Import Selected", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canImport)
                    }
                }
                .padding(.top, 4)
            } else {
                Text("Open a Security Center configuration file to select what to import.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var canImport: Bool {
        importData != nil &&
            (!importOptions.selectedCameraIDs.isEmpty ||
             !importOptions.selectedGridIDs.isEmpty ||
             importOptions.importsAppSettings ||
             importOptions.importsQuietHours)
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
            importPreview = try viewModel.previewConfigurationImport(data)
            importData = data
            importFileName = url.lastPathComponent
            importOptions = ConfigurationImportOptions(
                selectedCameraIDs: Set(importPreview?.cameras.map(\.id) ?? []),
                selectedGridIDs: Set(importPreview?.grids.map(\.id) ?? []),
                importsAppSettings: false,
                importsQuietHours: false
            )
            camerasExpanded = true
            gridsExpanded = true
        } catch {
            alert = ConfigurationTransferAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func applyImport() {
        do {
            guard let importData else { return }
            try viewModel.importConfigurationData(importData, options: importOptions)
            alert = ConfigurationTransferAlert(title: "Import Complete", message: "The selected configuration items were added.")
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

    private func previewSummary(_ preview: ConfigurationImportPreview) -> String {
        let cameraNames = preview.cameras.map(\.name).prefix(3).joined(separator: ", ")
        let gridNames = preview.grids.map(\.name).prefix(3).joined(separator: ", ")
        switch (cameraNames.isEmpty, gridNames.isEmpty) {
        case (false, false):
            return "Includes \(cameraNames) and grids \(gridNames)."
        case (false, true):
            return "Includes \(cameraNames)."
        case (true, false):
            return "Includes grids \(gridNames)."
        case (true, true):
            return ""
        }
    }
}

private struct ConfigurationImportItemGroup: View {
    let title: String
    let systemImage: String
    let items: [ConfigurationImportItem]
    @Binding var selection: Set<UUID>
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Select All") { selection = Set(items.map(\.id)) }
                    Button("Deselect All") { selection = [] }
                }
                .controlSize(.small)
                .padding(.bottom, 2)

                ForEach(items) { item in
                    Toggle(isOn: itemSelection(item.id)) {
                        Text(item.name).lineLimit(1).truncationMode(.tail)
                    }
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        } label: {
            Label("\(title) (\(items.count))", systemImage: systemImage)
        }
        .disabled(items.isEmpty)
    }

    private func itemSelection(_ id: UUID) -> Binding<Bool> {
        Binding {
            selection.contains(id)
        } set: { isSelected in
            if isSelected {
                selection.insert(id)
            } else {
                selection.remove(id)
            }
        }
    }
}

private struct ConfigurationTransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
#endif
