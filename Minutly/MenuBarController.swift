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

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
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

        // Position the popover so the sidebar (281px wide) aligns with the left edge
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Adjust the popover window position to align sidebar to the left of the button
        if let popoverWindow = popover.contentViewController?.view.window {
            var frame = popoverWindow.frame
            // Move window left so that the sidebar (first 281px) aligns with button
            frame.origin.x = buttonFrame.minX - 281
            popoverWindow.setFrame(frame, display: true)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // Open App
        let openAppItem = NSMenuItem(title: "Open Minutly", action: #selector(handleOpenApp), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        // Recordings section
        if let recordings = recorder?.recordings, !recordings.isEmpty {
            let recordingsHeader = NSMenuItem(title: "Recordings", action: nil, keyEquivalent: "")
            recordingsHeader.isEnabled = false
            menu.addItem(recordingsHeader)

            for recording in recordings.prefix(10) {
                let fileName = recording.deletingPathExtension().lastPathComponent
                let item = NSMenuItem(title: fileName, action: #selector(handleRecordingSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = recording
                menu.addItem(item)
            }

            if recordings.count > 10 {
                let moreItem = NSMenuItem(title: "... and \(recordings.count - 10) more", action: #selector(handleOpenApp), keyEquivalent: "")
                moreItem.target = self
                menu.addItem(moreItem)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Quit
        let quitItem = NSMenuItem(title: "Quit Minutly", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at status item
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
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
}
