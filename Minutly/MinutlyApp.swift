//
//  MinutlyApp.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI
import Combine

// Helper class to manage app state
@MainActor
class AppState: ObservableObject {
    let menuBarController = MenuBarController()
    let recorder: ScreenRecorder
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.recorder = ScreenRecorder()
        setupObservers()
    }

    private func setupObservers() {
        // Observe isRecording changes
        recorder.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                self.menuBarController.updateMenuBarIcon(
                    isRecording: isRecording,
                    isPreBuffering: self.recorder.isPreBuffering
                )
            }
            .store(in: &cancellables)

        // Observe isPreBuffering changes
        recorder.$isPreBuffering
            .sink { [weak self] isPreBuffering in
                guard let self = self else { return }
                self.menuBarController.updateMenuBarIcon(
                    isRecording: self.recorder.isRecording,
                    isPreBuffering: isPreBuffering
                )
            }
            .store(in: &cancellables)
    }
}

@main
struct MinutlyApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("enableMenuBarMode") private var enableMenuBarMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.recorder)
                .onAppear {
                    setupApp()
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func setupApp() {
        // Connect recorder to menu bar controller
        appState.menuBarController.setRecorder(appState.recorder)

        // Set up menu bar if enabled
        if enableMenuBarMode {
            appState.menuBarController.setupMenuBar()

            // Hide dock icon when in menu bar mode
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openRecording = Notification.Name("openRecording")
}
