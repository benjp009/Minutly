//
//  MinutlyApp.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI
import Combine
import UserNotifications

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
    @State private var showSplashScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState.recorder)
                    .onAppear {
                        setupApp()
                    }
                    .opacity(showSplashScreen ? 0 : 1)

                if showSplashScreen {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(2)
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
        // Migration: Clean up old cloud-related data
        migrateUserDefaults()
        cleanupKeychain()

        // Request notification permission for meeting reminders
        requestNotificationPermission()

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

    // MARK: - Migration

    private func migrateUserDefaults() {
        let defaults = UserDefaults.standard

        // Remove deprecated cloud-related keys
        let keysToRemove = [
            "transcriptionProvider",
            "summaryModel",
            "transcriptionAPIConfigured",
            "summarizationAPIConfigured",
            "onboardingCompleted",
            "currentOnboardingPage"
        ]

        for key in keysToRemove {
            if defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                print("🗑️ Removed deprecated key: \(key)")
            }
        }

        print("✅ Migrated UserDefaults (removed cloud keys)")
    }

    private func cleanupKeychain() {
        do {
            // Remove cloud API keys (keep encryption_key for recordings)
            try? KeychainService.shared.deleteAPIKey(for: "assemblyai")
            try? KeychainService.shared.deleteAPIKey(for: "openai")

            print("✅ Cleaned up cloud API keys from Keychain")
        } catch {
            print("⚠️ Keychain cleanup warning: \(error)")
        }
    }

    // MARK: - Permissions

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied - meeting reminders will not work")
            }
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openSettingsAPI = Notification.Name("openSettingsAPI")
    static let openRecording = Notification.Name("openRecording")
}
