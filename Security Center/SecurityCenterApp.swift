//
//  SecurityCenterApp.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

@main
struct SecurityCenterApp: App {
    private let mainWindowID = "main"
    @StateObject private var viewModel = AppViewModel()
#if os(macOS)
    @NSApplicationDelegateAdaptor(SecurityCenterAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.showConfigurationTransferAction) private var showConfigurationTransferAction
    @State private var showingAbout = false
#endif

    var body: some Scene {
        WindowGroup(id: mainWindowID) {
            ContentView(viewModel: viewModel)
#if os(macOS)
                .frame(minWidth: 400, minHeight: 500)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .overlay {
                    if showingAbout {
                        AboutOverlayView(isPresented: $showingAbout)
                    }
                }
#endif
        }
#if os(macOS)
        //.windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Security Center", systemImage: "info.circle") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingAbout = true
                    }
                }

                Button {
                    AppUpdateCenter.shared.checkForUpdates(trigger: .manual)
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath.circle")
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Window", systemImage: "macwindow.badge.plus") {
                    openWindow(id: mainWindowID)
                }
                .keyboardShortcut("n")
            }

            CommandGroup(after: .newItem) {
                Button {
                    showConfigurationTransferAction?()
                } label: {
                    Label("Configuration…", systemImage: "arrow.up.arrow.down")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(showConfigurationTransferAction == nil)
            }
        }
#endif
    }
}
