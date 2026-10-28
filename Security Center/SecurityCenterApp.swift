//
//  SecurityCenterApp.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI
#if os(macOS)
import Combine
#endif

@main
struct SecurityCenterApp: App {
    private let mainWindowID = "main"
    // Child views observe camera updates; the scene only retains the shared model.
    // Observing every playback update here also rebuilds the native menus.
    @State private var viewModel = AppViewModel()
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

            QuietHoursCommands(viewModel: viewModel)

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

#if os(macOS)
private struct QuietHoursCommands: Commands {
    @StateObject private var state: QuietHoursMenuState
    private let viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _state = StateObject(wrappedValue: QuietHoursMenuState(viewModel: viewModel))
    }

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button {
                viewModel.toggleManualQuietHours()
            } label: {
                Label(
                    state.isActive ? "Turn Off Quiet Hours" : "Turn On Quiet Hours",
                    systemImage: "moon"
                )
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}

@MainActor
private final class QuietHoursMenuState: ObservableObject {
    @Published private(set) var isActive: Bool
    private var subscription: AnyCancellable?

    init(viewModel: AppViewModel) {
        isActive = viewModel.isQuietHoursActive
        subscription = viewModel.$isQuietHoursActive
            .removeDuplicates()
            .sink { [weak self] isActive in
                guard self?.isActive != isActive else { return }
                self?.isActive = isActive
            }
    }
}
#endif
