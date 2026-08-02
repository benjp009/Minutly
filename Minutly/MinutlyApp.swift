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
    let meetingDetector: MeetingAppDetector
    private var cancellables = Set<AnyCancellable>()

    init() {
        let recorder = ScreenRecorder()
        self.recorder = recorder
        self.meetingDetector = MeetingAppDetector(recorder: recorder)
        setupObservers()
        syncMeetingDetection()
    }

    /// Meeting detection lives here rather than in a view so it keeps running with the
    /// window closed — which is exactly when a call starts.
    private func syncMeetingDetection() {
        applyMeetingDetectionSetting()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyMeetingDetectionSetting() }
            }
            .store(in: &cancellables)
    }

    private func applyMeetingDetectionSetting() {
        if UserDefaults.standard.bool(forKey: "enableMeetingDetection") {
            meetingDetector.start()
        } else {
            meetingDetector.stop()
        }
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
                    .opacity(showSplashScreen ? 0 : 1) // Show after splash screen (onboarding disabled)

                if false { // Onboarding temporarily disabled
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
        .defaultSize(width: 1000, height: 650)
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

        // Set as regular app to support full-screen mode
        NSApp.setActivationPolicy(.regular)

        // Enable full-screen support
        if let window = NSApp.windows.first {
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openSettingsAPI = Notification.Name("openSettingsAPI")
    static let openRecording = Notification.Name("openRecording")
}
