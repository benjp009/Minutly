//
//  MeetingAppDetector.swift
//  Minutly
//
//  Detects when a call actually starts, by watching which apps open the microphone.
//

import Foundation
import Combine
import CoreAudio
import UserNotifications

/// Watches the microphone to detect when a real call starts.
///
/// A calendar event says a meeting was *scheduled*. The microphone says a call actually
/// *started* — including the ad-hoc ones nobody put on a calendar. macOS 14.4+ exposes
/// per-process audio state through CoreAudio process objects, which names the app rather
/// than guessing from window titles.
@MainActor
final class MeetingAppDetector: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Bundle ID prefixes treated as "a call is happening", mapped to display names.
    /// Browsers count — a browser opening the mic is a Meet/Whereby/Teams-web call in practice.
    // ponytail: flat list, no window-title inspection. A false positive costs one Ignore click.
    private static let conferencingApps: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams": "Microsoft Teams",
        "com.google.Chrome": "Google Chrome",
        "com.apple.Safari": "Safari",
        "com.apple.WebKit.GPU": "Safari",   // Safari captures the mic in its GPU process
        "com.microsoft.edge": "Microsoft Edge",
        "com.brave.Browser": "Brave",
        "org.mozilla.firefox": "Firefox",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.hnc.Discord": "Discord",
        "Cisco-Systems.Spark": "Webex",
        "com.apple.avconferenced": "FaceTime",
    ]

    /// Conferencing apps capture the mic from helper processes — `com.google.Chrome.helper`,
    /// `com.microsoft.teams2.helper` — so match on prefix, longest first so the name is right.
    private static func displayName(forBundleID bundleID: String) -> String? {
        conferencingApps
            .filter { bundleID.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
    }

    @Published private(set) var isMonitoring = false

    private let recorder: ScreenRecorder
    private var timer: Timer?
    /// Conferencing apps currently holding the mic — used for rising-edge detection.
    /// Keyed by display name, so Chrome and its helper processes count as one meeting.
    private var activeApps: Set<String> = []
    /// Apps the user declined; cleared once they release the mic, so the next call asks again.
    private var declinedApps: Set<String> = []

    init(recorder: ScreenRecorder) {
        self.recorder = recorder
        super.init()

        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategory()

        Task {
            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            } catch {
                print("⚠️ Notification permission denied: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Monitoring

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activeApps = []
        declinedApps = []

        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.poll() }
        }
        print("✅ Meeting detection started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        activeApps = []
        print("🛑 Meeting detection stopped")
    }

    private func poll() {
        let current = Set(appsUsingMicrophone().compactMap { Self.displayName(forBundleID: $0) })

        #if DEBUG
        if current != activeApps {
            print("🎙️ Mic held by: \(current.isEmpty ? "nobody" : current.sorted().joined(separator: ", "))")
        }
        #endif

        // Apps that just let go of the mic get a clean slate for their next call.
        declinedApps.subtract(activeApps.subtracting(current))

        let started = current.subtracting(activeApps)
        activeApps = current

        // The call app holds the mic for the whole meeting, and our own recorder opens it too.
        // Only the rising edge is a new meeting, and never while we're already capturing.
        guard !recorder.isRecording, !recorder.isPreBuffering else { return }

        for appName in started.sorted() where !declinedApps.contains(appName) {
            notifyMeetingStarted(appName: appName)
        }
    }

    // MARK: - CoreAudio

    /// Bundle IDs of every process currently capturing microphone input.
    private func appsUsingMicrophone() -> [String] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }

        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else {
            return []
        }

        return processes.compactMap { isRunningInput($0) ? bundleID(of: $0) : nil }
    }

    private func isRunningInput(_ process: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr else {
            return false
        }
        return running == 1
    }

    private func bundleID(of process: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr,
              let value else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    // MARK: - Notification

    private func registerNotificationCategory() {
        let startAction = UNNotificationAction(
            identifier: "START_RECORDING",
            title: "Start Recording",
            options: [.foreground]
        )

        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE_MEETING",
            title: "Ignore",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "MEETING_DETECTED",
            actions: [startAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func notifyMeetingStarted(appName: String) {
        print("📞 Meeting detected in \(appName)")

        let content = UNMutableNotificationContent()
        content.title = "Meeting started"
        content.body = "\(appName) just started using your microphone."
        content.subtitle = "Record this meeting?"
        content.sound = .default
        content.categoryIdentifier = "MEETING_DETECTED"
        content.userInfo = ["appName": appName]

        let request = UNNotificationRequest(
            identifier: "meeting-\(appName)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to send meeting notification: \(error.localizedDescription)")
            }
        }
    }

    private func recordConsent(appName: String, confirmed: Bool) {
        do {
            try MeetingConfirmationManager.shared.recordMeetingConfirmation(
                eventID: "\(appName)-\(Int(Date().timeIntervalSince1970))",
                eventTitle: "\(appName) Meeting",
                eventDate: Date(),
                userConfirmed: confirmed
            )
        } catch {
            print("⚠️ Failed to record meeting consent: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even when Minutly is frontmost.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let appName = info["appName"] as? String ?? "Meeting"
        let action = response.actionIdentifier

        Task { @MainActor in
            switch action {
            case "START_RECORDING":
                self.recordConsent(appName: appName, confirmed: true)
                await self.recorder.startRecording(meetingTitle: "\(appName) Meeting")

            case "IGNORE_MEETING", UNNotificationDismissActionIdentifier:
                self.recordConsent(appName: appName, confirmed: false)
                self.declinedApps.insert(appName)

            default:
                // Clicking the banner body only opens the app — never starts recording by accident.
                break
            }
            completionHandler()
        }
    }
}
