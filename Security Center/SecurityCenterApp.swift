//
//  SecurityCenterApp.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

@main
struct SecurityCenterApp: App {
    @StateObject private var viewModel = AppViewModel()
#if os(macOS)
    @State private var showingAbout = false
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var exportDocument = ConfigurationJSONDocument(data: Data())
    @State private var configurationAlert: ConfigurationAlert?
#endif

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
#if os(macOS)
                .overlay {
                    if showingAbout {
                        AboutOverlayView(isPresented: $showingAbout)
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
#endif
        }
#if os(macOS)
        //.windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Security Center") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingAbout = true
                    }
                }
            }

            CommandGroup(after: .newItem) {
                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import JSON…", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button {
                    exportConfiguration()
                } label: {
                    Label("Export JSON…", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
#endif
    }
}

#if os(macOS)
private extension SecurityCenterApp {
    func exportConfiguration() {
        do {
            exportDocument = ConfigurationJSONDocument(data: try viewModel.exportConfigurationData())
            showingExportPicker = true
        } catch {
            configurationAlert = ConfigurationAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func handleImport(result: Result<[URL], Error>) {
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
        } catch {
            configurationAlert = ConfigurationAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }
}

private struct ConfigurationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
#endif
