//
//  SecurityCenterApp.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

@main
struct SecurityCenterApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import JSON…") {
                    importConfiguration()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export JSON…") {
                    exportConfiguration()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
#endif
    }
}

#if os(macOS)
private extension SecurityCenterApp {
    func importConfiguration() {
        let panel = NSOpenPanel()
        panel.title = "Import Security Center JSON"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            try viewModel.importConfigurationData(data)
        } catch {
            presentAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "Export Security Center JSON"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Security Center.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try viewModel.exportConfigurationData()
            try data.write(to: url, options: .atomic)
        } catch {
            presentAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
#endif
