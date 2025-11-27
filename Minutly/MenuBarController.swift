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
    @Published var isMenuBarMode = false
    @Published var selectedRecordingURL: URL?

    var recorder: ScreenRecorder?

    func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Minutly")
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        isMenuBarMode = true
        print("✅ Menu bar icon created")
    }

    func removeMenuBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        isMenuBarMode = false
        print("🗑️ Menu bar icon removed")
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        showMenu()
    }

    private func showMenu() {
        let isRecording = recorder?.isRecording ?? false
        let isPreBuffering = recorder?.isPreBuffering ?? false
        let recordings = recorder?.recordings ?? []
        let menu = NSMenu()

        // Open App
        let openAppItem = NSMenuItem(title: "Open Minutly", action: #selector(handleOpenApp), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        // Recording controls
        let startItem = NSMenuItem(title: "Start Recording", action: #selector(handleStartRecording), keyEquivalent: "")
        startItem.target = self
        startItem.isEnabled = !isRecording && !isPreBuffering
        menu.addItem(startItem)

        let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(handleStopRecording), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = isRecording || isPreBuffering
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        // Latest recording shortcut
        if let latestRecording = recordings.first {
            let fileName = latestRecording.deletingPathExtension().lastPathComponent
            let lastItem = NSMenuItem(title: "Last Recording: \(fileName)", action: #selector(handleRecordingSelected(_:)), keyEquivalent: "")
            lastItem.target = self
            lastItem.representedObject = latestRecording
            menu.addItem(lastItem)
        } else {
            let placeholder = NSMenuItem(title: "No recordings yet", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
            menu.addItem(placeholder)
        }

        // Additional recordings list (excluding the latest already shown)
        if recordings.count > 1 {
            menu.addItem(NSMenuItem.separator())
            let recordingsHeader = NSMenuItem(title: "Other Recordings", action: nil, keyEquivalent: "")
            recordingsHeader.isEnabled = false
            menu.addItem(recordingsHeader)

            for recording in recordings.dropFirst().prefix(9) {
                let fileName = recording.deletingPathExtension().lastPathComponent
                let item = NSMenuItem(title: fileName, action: #selector(handleRecordingSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = recording
                menu.addItem(item)
            }

            if recordings.count > 10 {
                let remaining = recordings.count - 10
                let moreItem = NSMenuItem(title: "... and \(remaining) more", action: #selector(handleOpenApp), keyEquivalent: "")
                moreItem.target = self
                menu.addItem(moreItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Turn Off Minutly", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at status item
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func handleStartRecording() {
        guard let recorder = recorder else { return }
        Task { @MainActor in
            await recorder.startRecording()
        }
    }

    @objc private func handleStopRecording() {
        guard let recorder = recorder else { return }
        Task { @MainActor in
            if recorder.isRecording {
                await recorder.stopRecording()
            } else if recorder.isPreBuffering {
                await recorder.cancelPreBuffer()
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

    func setRecorder(_ recorder: ScreenRecorder) {
        self.recorder = recorder
    }
}
