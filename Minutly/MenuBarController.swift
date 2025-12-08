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
    private var eventMonitor: Any?
    private var popover: NSPopover?
    @Published var isMenuBarMode = false
    @Published var selectedRecordingURL: URL?
    private var blinkingTimer: Timer?
    private var isBlinkingOn = false

    var recorder: ScreenRecorder?

    func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use AppIcon for the menu bar icon
            if let appIcon = NSImage(named: "AppIcon") {
                let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
                resizedIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                resizedIcon.unlockFocus()
                resizedIcon.isTemplate = true
                button.image = resizedIcon
            } else {
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Minutly")
            }
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover
        setupPopover()

        isMenuBarMode = true
        print("✅ Menu bar icon created")
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 1000, height: 650)
        popover.behavior = .transient
        popover.animates = true

        // Create ContentView with recorder
        if let recorder = recorder {
            let contentView = ContentView()
                .environmentObject(recorder)
                .frame(width: 1000, height: 650)

            popover.contentViewController = NSHostingController(rootView: contentView)
        }

        self.popover = popover
    }

    func removeMenuBar() {
        popover?.performClose(nil)
        popover = nil

        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        isMenuBarMode = false
        print("🗑️ Menu bar icon removed")
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Show menu on both left and right click
        showMenu()
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        guard let popover = popover else { return }

        // Calculate position to align sidebar to left
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero

        // Position the popover so the sidebar (300px wide) aligns with the left edge
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Adjust the popover window position to align sidebar to the left of the button
        if let popoverWindow = popover.contentViewController?.view.window {
            var frame = popoverWindow.frame
            // Move window left so that the sidebar (first 300px) aligns with button
            frame.origin.x = buttonFrame.minX - 300
            popoverWindow.setFrame(frame, display: true)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // Start/Stop Recording action
        let recordingTitle = (recorder?.isRecording ?? false) ? "Stop Recording" : "Start Recording"
        let recordingIcon = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        let startRecordingItem = NSMenuItem(title: recordingTitle, action: #selector(handleToggleRecording), keyEquivalent: "")
        startRecordingItem.target = self
        startRecordingItem.image = recordingIcon
        menu.addItem(startRecordingItem)

        menu.addItem(NSMenuItem.separator())

        // Last 3 Recordings section
        if let recordings = recorder?.recordings, !recordings.isEmpty {
            let recordingsToShow = Array(recordings.prefix(3))

            for recording in recordingsToShow {
                let fileName = recording.deletingPathExtension().lastPathComponent
                let item = NSMenuItem(title: fileName, action: #selector(handleRecordingSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = recording
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Open App
        let openAppItem = NSMenuItem(title: "Open App", action: #selector(handleOpenApp), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Minutly", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at status item
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func handleToggleRecording() {
        guard let recorder = recorder else { return }

        Task {
            if recorder.isRecording {
                await recorder.stopRecording()
                stopBlinking()
            } else {
                await recorder.startRecording()
                startBlinking()
            }
        }
    }

    private func startBlinking() {
        stopBlinking()
        isBlinkingOn = false
        blinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.isBlinkingOn.toggle()
            self?.updateBlinkingIcon()
        }
    }

    private func stopBlinking() {
        blinkingTimer?.invalidate()
        blinkingTimer = nil
        isBlinkingOn = false
    }

    private func updateBlinkingIcon() {
        guard let button = statusItem?.button else { return }

        if isBlinkingOn {
            // Show red recording icon
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = false
            if let image = button.image {
                let coloredImage = NSImage(size: image.size)
                coloredImage.lockFocus()
                NSColor.red.set()
                image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
                coloredImage.unlockFocus()
                button.image = coloredImage
            }
        } else {
            // Show dark black recording icon (dimmed)
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = false
            if let image = button.image {
                let coloredImage = NSImage(size: image.size)
                coloredImage.lockFocus()
                NSColor.black.set()
                image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 0.4)
                coloredImage.unlockFocus()
                button.image = coloredImage
            }
        }
    }

    @objc private func handleOpenApp() {
        openMainWindow()
    }

    @objc private func handleRecordingSelected(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        selectedRecordingURL = url
        NotificationCenter.default.post(name: .openRecording, object: url)
        openMainWindow()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateMenuBarIcon(isRecording: Bool, isPreBuffering: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            startBlinking()
        } else if isPreBuffering {
            stopBlinking()
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
            stopBlinking()
            // Reset to default AppIcon
            if let appIcon = NSImage(named: "AppIcon") {
                let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
                resizedIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                resizedIcon.unlockFocus()
                resizedIcon.isTemplate = true
                button.image = resizedIcon
            } else {
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Minutly")
                button.image?.isTemplate = true
            }
        }
    }

    func setRecorder(_ recorder: ScreenRecorder) {
        self.recorder = recorder

        // Recreate popover if menu bar is active
        if isMenuBarMode {
            setupPopover()
        }
    }

    deinit {
        // Cleanup timer in deinit - timer is safe to invalidate from any context
        blinkingTimer?.invalidate()
        blinkingTimer = nil
        print("🔄 MenuBarController deallocated")
    }
}
