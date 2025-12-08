//
//  MeetingConfirmationManager.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation
import EventKit

// MARK: - Meeting Consent Record

struct MeetingConsentRecord: Codable {
    let eventID: String
    let eventTitle: String
    let eventDate: Date
    let userConfirmed: Bool
    let confirmationTime: Date
    let confirmationMethod: String  // "manual", "auto"

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case eventTitle = "event_title"
        case eventDate = "event_date"
        case userConfirmed = "user_confirmed"
        case confirmationTime = "confirmation_time"
        case confirmationMethod = "confirmation_method"
    }
}

// MARK: - Meeting Confirmation Manager

class MeetingConfirmationManager {
    static let shared = MeetingConfirmationManager()

    private let fileManager = FileManager.default
    private let consentDirectory: URL
    private var consentRecords: [String: MeetingConsentRecord] = [:]

    init() {
        let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.consentDirectory = appSupportPath.appendingPathComponent("com.minutly/meeting_consents")

        // Create consent directory if it doesn't exist
        try? fileManager.createDirectory(at: consentDirectory, withIntermediateDirectories: true)

        // Load existing consent records
        loadAllConsents()
    }

    // MARK: - Consent Management

    /// Record user confirmation for a meeting
    func recordMeetingConfirmation(
        eventID: String,
        eventTitle: String,
        eventDate: Date,
        userConfirmed: Bool,
        method: String = "manual"
    ) throws {
        let record = MeetingConsentRecord(
            eventID: eventID,
            eventTitle: eventTitle,
            eventDate: eventDate,
            userConfirmed: userConfirmed,
            confirmationTime: Date(),
            confirmationMethod: method
        )

        consentRecords[eventID] = record

        try saveConsentRecord(record)

        if userConfirmed {
            print("✅ User confirmed recording for: \(eventTitle)")
        } else {
            print("⛔ User declined recording for: \(eventTitle)")
        }
    }

    /// Check if user has confirmed recording for a meeting
    func hasConfirmedMeeting(_ eventID: String) -> Bool {
        if let record = consentRecords[eventID] {
            // Check if confirmation is still valid (not older than 24 hours)
            let timeElapsed = Date().timeIntervalSince(record.confirmationTime)
            let hoursElapsed = timeElapsed / 3600
            return record.userConfirmed && hoursElapsed < 24
        }
        return false
    }

    /// Get consent record for a meeting
    func getConsentRecord(_ eventID: String) -> MeetingConsentRecord? {
        return consentRecords[eventID]
    }

    // MARK: - File Operations

    private func consentFileURL(for eventID: String) -> URL {
        return consentDirectory.appendingPathComponent("\(eventID).json")
    }

    private func saveConsentRecord(_ record: MeetingConsentRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        let fileURL = consentFileURL(for: record.eventID)

        try data.write(to: fileURL)
    }

    private func loadAllConsents() {
        do {
            let consentFiles = try fileManager.contentsOfDirectory(at: consentDirectory, includingPropertiesForKeys: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for fileURL in consentFiles where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let record = try decoder.decode(MeetingConsentRecord.self, from: data)
                    consentRecords[record.eventID] = record
                } catch {
                    print("⚠️ Failed to load consent record: \(error.localizedDescription)")
                }
            }
        } catch {
            print("⚠️ Error loading consent records: \(error.localizedDescription)")
        }
    }

    /// Delete old consent records (older than 30 days)
    func cleanupOldRecords() throws {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        var recordsToDelete: [String] = []

        for (eventID, record) in consentRecords {
            if record.confirmationTime < thirtyDaysAgo {
                recordsToDelete.append(eventID)
            }
        }

        for eventID in recordsToDelete {
            consentRecords.removeValue(forKey: eventID)
            let fileURL = consentFileURL(for: eventID)
            try? fileManager.removeItem(at: fileURL)
        }

        print("✅ Cleaned up \(recordsToDelete.count) old consent records")
    }

    /// Get audit trail of all confirmations
    func getAuditTrail() -> [MeetingConsentRecord] {
        return consentRecords.values
            .sorted { $0.confirmationTime > $1.confirmationTime }
    }
}

// MARK: - Calendar Event Extension

extension EKEvent {
    /// Generate a consistent ID for this event
    var consistentID: String {
        // Use event UID if available, otherwise create from title and date
        if !eventIdentifier.isEmpty {
            return eventIdentifier
        }

        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: startDate)
        return "\(title ?? "event")-\(dateString)".lowercased()
    }
}
