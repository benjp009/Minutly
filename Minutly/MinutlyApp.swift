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
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showSplashScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState.recorder)
                    .onAppear {
                        setupApp()
                    }
                    .opacity(showSplashScreen || !onboardingCompleted ? 0 : 1)

                if !onboardingCompleted {
                    OnboardingContainerView()
                        .environmentObject(appState.recorder)
                        .transition(.opacity)
                        .zIndex(2)
                }

                if showSplashScreen {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .onAppear {
                // Dismiss splash screen after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showSplashScreen = false
                    }
                }
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

        // Always set up menu bar (app is menu bar only)
        appState.menuBarController.setupMenuBar()

        // Ensure dock icon is hidden (LSUIElement in Info.plist handles this at launch)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openRecording = Notification.Name("openRecording")
}
