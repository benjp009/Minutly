//
//  MinutlyApp.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI

@main
struct MinutlyApp: App {
    @StateObject private var menuBarController = MenuBarController()
    @AppStorage("enableMenuBarMode") private var enableMenuBarMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
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
        // Set up menu bar if enabled
        if enableMenuBarMode {
            menuBarController.setupMenuBar()

            // Hide dock icon when in menu bar mode
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Show dock icon in regular mode
            NSApp.setActivationPolicy(.regular)
        }
    }
}
