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
    @State private var settingsNavigation = MacSettingsNavigation()
    @State private var showingAbout = false
#endif

    var body: some Scene {
        WindowGroup(id: mainWindowID) {
            ContentView(viewModel: viewModel)
#if os(macOS)
                .environment(settingsNavigation)
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

            CommandGroup(after: .toolbar) {
                Button {
                    viewModel.toggleManualQuietHours()
                } label: {
                    Label(
                        viewModel.isQuietHoursActive ? "Turn Off Quiet Hours" : "Turn On Quiet Hours",
                        systemImage: "moon"
                    )
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }

        }

#endif
#if os(macOS)
        Settings {
            MacSettingsView(viewModel: viewModel)
                .environment(settingsNavigation)
        }
        .windowResizability(.contentSize)
#endif
    }
}
