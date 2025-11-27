//
//  CalendarMonitorService.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import Foundation
import EventKit
import UserNotifications
import Combine

@MainActor
class CalendarMonitorService: ObservableObject {
    @Published var upcomingMeeting: EKEvent?
    @Published var isMonitoring = false

    private let eventStore = EKEventStore()
    private var monitorTimer: Timer?
    private var notifiedMeetings: Set<String> = []

    // Callback when meeting is about to start
    var onMeetingDetected: ((EKEvent) -> Void)?

    init() {
        requestNotificationPermission()
    }

    // MARK: - Permissions

    func requestCalendarPermission() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                print(granted ? "✅ Calendar permission granted" : "❌ Calendar permission denied")
                return granted
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            print("❌ Calendar permission error: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        } catch {
            print("❌ Calendar permission error: \(error.localizedDescription)")
            return false
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
        }
    }

    // MARK: - Monitoring

    func startMonitoring() async {
        print("🔍 Starting calendar monitoring...")

        // Request permission first
        let hasPermission = await requestCalendarPermission()
        guard hasPermission else {
            print("❌ Cannot monitor calendar without permission")
            return
        }

        isMonitoring = true

        // Check immediately
        await checkForUpcomingMeetings()

        // Then check every 30 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpcomingMeetings()
            }
        }

        print("✅ Calendar monitoring started")
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        print("🛑 Calendar monitoring stopped")
    }

    private func checkForUpcomingMeetings() async {
        let now = Date()
        let lookAheadMinutes = 5.0 // Look 5 minutes ahead
        let endDate = now.addingTimeInterval(lookAheadMinutes * 60)

        // Create predicate for events in the next 5 minutes
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Filter for meetings (events with attendees or video call URLs)
        let meetings = events.filter { event in
            // Consider it a meeting if it has:
            // 1. Other attendees, OR
            // 2. A URL (likely a video call), OR
            // 3. Contains meeting keywords in title
            let hasAttendees = (event.attendees?.count ?? 0) > 1
            let hasURL = event.url != nil
            let titleLower = event.title?.lowercased() ?? ""
            let hasMeetingKeywords = titleLower.contains("meeting") ||
                                     titleLower.contains("call") ||
                                     titleLower.contains("réunion") ||
                                     titleLower.contains("rendez-vous") ||
                                     titleLower.contains("zoom") ||
                                     titleLower.contains("teams") ||
                                     titleLower.contains("meet")

            return hasAttendees || hasURL || hasMeetingKeywords
        }

        // Find the soonest meeting
        if let nextMeeting = meetings.sorted(by: { $0.startDate < $1.startDate }).first {
            let timeUntilMeeting = nextMeeting.startDate.timeIntervalSince(now)

            // If meeting starts in less than 2 minutes and we haven't notified yet
            if timeUntilMeeting <= 120 && timeUntilMeeting > -60 { // Within 2 minutes before to 1 minute after start
                guard let meetingID = nextMeeting.eventIdentifier else { return }

                if !notifiedMeetings.contains(meetingID) {
                    notifiedMeetings.insert(meetingID)
                    let meetingTitle = nextMeeting.title ?? "Untitled"
                    print("📅 Meeting detected: \(meetingTitle) at \(String(describing: nextMeeting.startDate))")

                    upcomingMeeting = nextMeeting

                    // Send notification
                    await sendMeetingNotification(meeting: nextMeeting)

                    // Trigger callback
                    onMeetingDetected?(nextMeeting)
                }
            }
        }

        // Clean up old notified meetings (older than 1 hour)
        let oneHourAgo = now.addingTimeInterval(-3600)
        for eventID in notifiedMeetings {
            if let event = eventStore.event(withIdentifier: eventID),
               event.startDate < oneHourAgo {
                notifiedMeetings.remove(eventID)
            }
        }
    }

    // MARK: - Notifications

    private func sendMeetingNotification(meeting: EKEvent) async {
        let content = UNMutableNotificationContent()
        content.title = "Meeting Starting Soon"
        content.body = meeting.title ?? "Untitled Meeting"
        content.subtitle = "Would you like to start recording?"
        content.sound = .default
        content.categoryIdentifier = "MEETING_DETECTED"

        // Add user info
        content.userInfo = [
            "meetingTitle": meeting.title ?? "Untitled",
            "meetingID": meeting.eventIdentifier ?? ""
        ]

        // Show immediately
        let request = UNNotificationRequest(
            identifier: meeting.eventIdentifier ?? UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notification sent for meeting: \(meeting.title ?? "Untitled")")
        } catch {
            print("❌ Failed to send notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Actions

    func setupNotificationActions() {
        // Define actions
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

        // Define category
        let category = UNNotificationCategory(
            identifier: "MEETING_DETECTED",
            actions: [startAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )

        // Register category
        UNUserNotificationCenter.current().setNotificationCategories([category])
        print("✅ Notification actions registered")
    }
}
