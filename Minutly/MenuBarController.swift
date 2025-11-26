//
//  MenuBarController.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @Published var isMenuBarMode = false

    var recorder: ScreenRecorder?
    var calendarMonitor: CalendarMonitorService?

    func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Minutly")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 600)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())

        isMenuBarMode = true
        print("✅ Menu bar icon created")
    }

    func removeMenuBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        popover = nil
        isMenuBarMode = false
        print("🗑️ Menu bar icon removed")
    }

    @objc private func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }

    func updateMenuBarIcon(isRecording: Bool, isPreBuffering: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = false
            // Make it red
            if let image = button.image {
                let coloredImage = NSImage(size: image.size)
                coloredImage.lockFocus()
                NSColor.red.set()
                image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
                coloredImage.unlockFocus()
                button.image = coloredImage
            }
        } else if isPreBuffering {
            button.image = NSImage(systemSymbolName: "circlebadge.fill", accessibilityDescription: "Pre-buffering")
            button.image?.isTemplate = false
            // Make it orange
            if let image = button.image {
                let coloredImage = NSImage(size: image.size)
                coloredImage.lockFocus()
                NSColor.orange.set()
                image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
                coloredImage.unlockFocus()
                button.image = coloredImage
            }
        } else {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Minutly")
            button.image?.isTemplate = true
        }
    }

    func createMenu(recorder: ScreenRecorder, calendarMonitor: CalendarMonitorService, onShowWindow: @escaping () -> Void, onQuit: @escaping () -> Void) {
        let menu = NSMenu()

        // Status item
        let statusItem = NSMenuItem(title: "Minutly", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Recording status
        let recordingStatus = NSMenuItem(title: recorder.isRecording ? "🔴 Recording..." : (recorder.isPreBuffering ? "🟠 Pre-buffering..." : "⚪️ Ready"), action: nil, keyEquivalent: "")
        recordingStatus.isEnabled = false
        menu.addItem(recordingStatus)

        menu.addItem(NSMenuItem.separator())

        // Start/Stop Recording
        if recorder.isRecording {
            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(handleStopRecording), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
        } else if !recorder.isPreBuffering {
            let startItem = NSMenuItem(title: "Start Recording", action: #selector(handleStartRecording), keyEquivalent: "")
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Meeting Detection
        let detectionItem = NSMenuItem(title: calendarMonitor.isMonitoring ? "✅ Meeting Detection On" : "⚪️ Meeting Detection Off", action: nil, keyEquivalent: "")
        detectionItem.isEnabled = false
        menu.addItem(detectionItem)

        menu.addItem(NSMenuItem.separator())

        // Show Window
        let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(handleShowWindow), keyEquivalent: "w")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Minutly", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu

        // Store references
        self.recorder = recorder
        self.calendarMonitor = calendarMonitor
    }

    @objc private func handleStartRecording() {
        Task { @MainActor in
            await recorder?.startRecording()
        }
    }

    @objc private func handleStopRecording() {
        Task { @MainActor in
            await recorder?.stopRecording()
        }
    }

    @objc private func handleShowWindow() {
        // Show main window
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func handleSettings() {
        handleShowWindow()
        // Post notification to open settings
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
