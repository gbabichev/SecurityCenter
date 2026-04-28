//
//  ConfigurationTransferView.swift
//  Security Center
//
//  Created by Codex on 4/28/26.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

private struct ShowConfigurationTransferActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var showConfigurationTransferAction: (() -> Void)? {
        get { self[ShowConfigurationTransferActionKey.self] }
        set { self[ShowConfigurationTransferActionKey.self] = newValue }
    }
}

struct ConfigurationTransferView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = ConfigurationJSONDocument(data: Data())
    @State private var importData: Data?
    @State private var importFileName: String?
    @State private var importPreview: ConfigurationImportPreview?
    @State private var importOptions = ConfigurationImportOptions.additiveDefault
    @State private var camerasExpanded = true
    @State private var gridsExpanded = true
    @State private var alert: ConfigurationTransferAlert?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Divider()

            importSection

            Divider()

            exportSection

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
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

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Configuration")
                    .font(.title3.weight(.semibold))
                Text("Import selected parts of a JSON file or export the current setup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Import")
                Spacer()
                Button {
                    showingImporter = true
                } label: {
                    Label("Choose JSON…", systemImage: "doc.badge.plus")
                }
            }

            if let importFileName, let importPreview {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(importFileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }

                    importItemGroup(
                        title: "Cameras",
                        systemImage: "video",
                        items: importPreview.cameras,
                        selection: $importOptions.selectedCameraIDs,
                        isExpanded: $camerasExpanded
                    )

                    importItemGroup(
                        title: "Grids",
                        systemImage: "square.grid.2x2",
                        items: importPreview.grids,
                        selection: $importOptions.selectedGridIDs,
                        isExpanded: $gridsExpanded
                    )

                    Toggle("App display settings", isOn: $importOptions.importsAppSettings)
                        .disabled(!importPreview.includesAppSettings)
                    Toggle("Quiet hours", isOn: $importOptions.importsQuietHours)
                        .disabled(!importPreview.includesQuietHours)

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
                .padding(14)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("Choose a Security Center JSON export, then select what to add to this setup.")
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
            sectionTitle("Export")

            HStack {
                Text("Save the current cameras, grids, assignments, and app settings as JSON.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    exportConfiguration()
                } label: {
                    Label("Export JSON…", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
    }

    private var canImport: Bool {
        importData != nil &&
            (!importOptions.selectedCameraIDs.isEmpty ||
             !importOptions.selectedGridIDs.isEmpty ||
             importOptions.importsAppSettings ||
             importOptions.importsQuietHours)
    }

    private func importItemGroup(
        title: String,
        systemImage: String,
        items: [ConfigurationImportItem],
        selection: Binding<Set<UUID>>,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 12)
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                    Text("\(title) (\(items.count))")
                    Spacer()
                    Button(selection.wrappedValue.count == items.count ? "None" : "All") {
                        if selection.wrappedValue.count == items.count {
                            selection.wrappedValue = []
                        } else {
                            selection.wrappedValue = Set(items.map(\.id))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(items.isEmpty)
                }
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)

            if isExpanded.wrappedValue && !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        Toggle(isOn: itemSelectionBinding(item.id, selection: selection)) {
                            Text(item.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding(.leading, 22)
            }
        }
    }

    private func itemSelectionBinding(_ id: UUID, selection: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue.contains(id)
        } set: { isSelected in
            if isSelected {
                selection.wrappedValue.insert(id)
            } else {
                selection.wrappedValue.remove(id)
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

private struct ConfigurationTransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
#endif
