//
//  AuditLogger.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation

// MARK: - Audit Event Types

enum AuditEventType: Codable {
    case recordingStarted(title: String, duration: TimeInterval?)
    case recordingStopped(duration: TimeInterval)
    case recordingEncrypted(title: String, duration: TimeInterval)
    case recordingDeleted(title: String)
    case transcriptionRequested(provider: String, duration: TimeInterval)
    case transcriptionCompleted(provider: String, wordCount: Int)
    case transcriptionFailed(provider: String, error: String)
    case summaryRequested(provider: String)
    case summaryCompleted(taskCount: Int)
    case summaryFailed(error: String)
    case uploadConsentGiven(provider: String, reason: String?)
    case uploadConsentDenied(provider: String)
    case cloudUploadStarted(provider: String, recordingID: String)
    case cloudUploadCompleted(provider: String, recordingID: String)
    case cloudUploadFailed(provider: String, error: String)
    case dataDeleteRequested(provider: String, recordingID: String)
    case dataDeleteCompleted(provider: String, recordingID: String)
    case dataDeleteFailed(provider: String, error: String)
    case apiKeyConfigured(provider: String)
    case apiKeyRemoved(provider: String)
    case meetingConfirmed(title: String, timestamp: Date)
    case meetingDeclined(title: String)
    case calendarPermissionGranted
    case calendarPermissionDenied
    case calendarPermissionRevoked
    case notificationPermissionGranted
    case notificationPermissionDenied
    case settingsChanged(setting: String, oldValue: String, newValue: String)
    case appLaunched(version: String)
    case appTerminated
    case errorOccurred(component: String, error: String)
    case securityWarning(warning: String)

    enum CodingKeys: String, CodingKey {
        case type, title, duration, provider, wordCount, taskCount, reason, recordingID, setting, oldValue, newValue, version, error, component, warning
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .recordingStarted(let title, let duration):
            try container.encode("recordingStarted", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(duration, forKey: .duration)

        case .recordingStopped(let duration):
            try container.encode("recordingStopped", forKey: .type)
            try container.encode(duration, forKey: .duration)

        case .recordingEncrypted(let title, let duration):
            try container.encode("recordingEncrypted", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(duration, forKey: .duration)

        case .recordingDeleted(let title):
            try container.encode("recordingDeleted", forKey: .type)
            try container.encode(title, forKey: .title)

        case .transcriptionRequested(let provider, let duration):
            try container.encode("transcriptionRequested", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(duration, forKey: .duration)

        case .transcriptionCompleted(let provider, let wordCount):
            try container.encode("transcriptionCompleted", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(wordCount, forKey: .wordCount)

        case .transcriptionFailed(let provider, let error):
            try container.encode("transcriptionFailed", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(error, forKey: .error)

        case .summaryRequested(let provider):
            try container.encode("summaryRequested", forKey: .type)
            try container.encode(provider, forKey: .provider)

        case .summaryCompleted(let taskCount):
            try container.encode("summaryCompleted", forKey: .type)
            try container.encode(taskCount, forKey: .taskCount)

        case .summaryFailed(let error):
            try container.encode("summaryFailed", forKey: .type)
            try container.encode(error, forKey: .error)

        case .uploadConsentGiven(let provider, let reason):
            try container.encode("uploadConsentGiven", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encodeIfPresent(reason, forKey: .reason)

        case .uploadConsentDenied(let provider):
            try container.encode("uploadConsentDenied", forKey: .type)
            try container.encode(provider, forKey: .provider)

        case .cloudUploadStarted(let provider, let recordingID):
            try container.encode("cloudUploadStarted", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(recordingID, forKey: .recordingID)

        case .cloudUploadCompleted(let provider, let recordingID):
            try container.encode("cloudUploadCompleted", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(recordingID, forKey: .recordingID)

        case .cloudUploadFailed(let provider, let error):
            try container.encode("cloudUploadFailed", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(error, forKey: .error)

        case .dataDeleteRequested(let provider, let recordingID):
            try container.encode("dataDeleteRequested", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(recordingID, forKey: .recordingID)

        case .dataDeleteCompleted(let provider, let recordingID):
            try container.encode("dataDeleteCompleted", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(recordingID, forKey: .recordingID)

        case .dataDeleteFailed(let provider, let error):
            try container.encode("dataDeleteFailed", forKey: .type)
            try container.encode(provider, forKey: .provider)
            try container.encode(error, forKey: .error)

        case .apiKeyConfigured(let provider):
            try container.encode("apiKeyConfigured", forKey: .type)
            try container.encode(provider, forKey: .provider)

        case .apiKeyRemoved(let provider):
            try container.encode("apiKeyRemoved", forKey: .type)
            try container.encode(provider, forKey: .provider)

        case .meetingConfirmed(let title, let timestamp):
            try container.encode("meetingConfirmed", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(timestamp, forKey: .duration)

        case .meetingDeclined(let title):
            try container.encode("meetingDeclined", forKey: .type)
            try container.encode(title, forKey: .title)

        case .calendarPermissionGranted:
            try container.encode("calendarPermissionGranted", forKey: .type)

        case .calendarPermissionDenied:
            try container.encode("calendarPermissionDenied", forKey: .type)

        case .calendarPermissionRevoked:
            try container.encode("calendarPermissionRevoked", forKey: .type)

        case .notificationPermissionGranted:
            try container.encode("notificationPermissionGranted", forKey: .type)

        case .notificationPermissionDenied:
            try container.encode("notificationPermissionDenied", forKey: .type)

        case .settingsChanged(let setting, let oldValue, let newValue):
            try container.encode("settingsChanged", forKey: .type)
            try container.encode(setting, forKey: .setting)
            try container.encode(oldValue, forKey: .oldValue)
            try container.encode(newValue, forKey: .newValue)

        case .appLaunched(let version):
            try container.encode("appLaunched", forKey: .type)
            try container.encode(version, forKey: .version)

        case .appTerminated:
            try container.encode("appTerminated", forKey: .type)

        case .errorOccurred(let component, let error):
            try container.encode("errorOccurred", forKey: .type)
            try container.encode(component, forKey: .component)
            try container.encode(error, forKey: .error)

        case .securityWarning(let warning):
            try container.encode("securityWarning", forKey: .type)
            try container.encode(warning, forKey: .warning)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "recordingStarted":
            let title = try container.decode(String.self, forKey: .title)
            let duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            self = .recordingStarted(title: title, duration: duration)

        case "recordingStopped":
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .recordingStopped(duration: duration)

        case "recordingEncrypted":
            let title = try container.decode(String.self, forKey: .title)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .recordingEncrypted(title: title, duration: duration)

        case "recordingDeleted":
            let title = try container.decode(String.self, forKey: .title)
            self = .recordingDeleted(title: title)

        case "transcriptionRequested":
            let provider = try container.decode(String.self, forKey: .provider)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .transcriptionRequested(provider: provider, duration: duration)

        case "transcriptionCompleted":
            let provider = try container.decode(String.self, forKey: .provider)
            let wordCount = try container.decode(Int.self, forKey: .wordCount)
            self = .transcriptionCompleted(provider: provider, wordCount: wordCount)

        case "transcriptionFailed":
            let provider = try container.decode(String.self, forKey: .provider)
            let error = try container.decode(String.self, forKey: .error)
            self = .transcriptionFailed(provider: provider, error: error)

        case "summaryRequested":
            let provider = try container.decode(String.self, forKey: .provider)
            self = .summaryRequested(provider: provider)

        case "summaryCompleted":
            let taskCount = try container.decode(Int.self, forKey: .taskCount)
            self = .summaryCompleted(taskCount: taskCount)

        case "summaryFailed":
            let error = try container.decode(String.self, forKey: .error)
            self = .summaryFailed(error: error)

        case "uploadConsentGiven":
            let provider = try container.decode(String.self, forKey: .provider)
            let reason = try container.decodeIfPresent(String.self, forKey: .reason)
            self = .uploadConsentGiven(provider: provider, reason: reason)

        case "uploadConsentDenied":
            let provider = try container.decode(String.self, forKey: .provider)
            self = .uploadConsentDenied(provider: provider)

        case "cloudUploadStarted":
            let provider = try container.decode(String.self, forKey: .provider)
            let recordingID = try container.decode(String.self, forKey: .recordingID)
            self = .cloudUploadStarted(provider: provider, recordingID: recordingID)

        case "cloudUploadCompleted":
            let provider = try container.decode(String.self, forKey: .provider)
            let recordingID = try container.decode(String.self, forKey: .recordingID)
            self = .cloudUploadCompleted(provider: provider, recordingID: recordingID)

        case "cloudUploadFailed":
            let provider = try container.decode(String.self, forKey: .provider)
            let error = try container.decode(String.self, forKey: .error)
            self = .cloudUploadFailed(provider: provider, error: error)

        case "dataDeleteRequested":
            let provider = try container.decode(String.self, forKey: .provider)
            let recordingID = try container.decode(String.self, forKey: .recordingID)
            self = .dataDeleteRequested(provider: provider, recordingID: recordingID)

        case "dataDeleteCompleted":
            let provider = try container.decode(String.self, forKey: .provider)
            let recordingID = try container.decode(String.self, forKey: .recordingID)
            self = .dataDeleteCompleted(provider: provider, recordingID: recordingID)

        case "dataDeleteFailed":
            let provider = try container.decode(String.self, forKey: .provider)
            let error = try container.decode(String.self, forKey: .error)
            self = .dataDeleteFailed(provider: provider, error: error)

        case "apiKeyConfigured":
            let provider = try container.decode(String.self, forKey: .provider)
            self = .apiKeyConfigured(provider: provider)

        case "apiKeyRemoved":
            let provider = try container.decode(String.self, forKey: .provider)
            self = .apiKeyRemoved(provider: provider)

        case "meetingConfirmed":
            let title = try container.decode(String.self, forKey: .title)
            let timestamp = try container.decode(Date.self, forKey: .duration)
            self = .meetingConfirmed(title: title, timestamp: timestamp)

        case "meetingDeclined":
            let title = try container.decode(String.self, forKey: .title)
            self = .meetingDeclined(title: title)

        case "calendarPermissionGranted":
            self = .calendarPermissionGranted

        case "calendarPermissionDenied":
            self = .calendarPermissionDenied

        case "calendarPermissionRevoked":
            self = .calendarPermissionRevoked

        case "notificationPermissionGranted":
            self = .notificationPermissionGranted

        case "notificationPermissionDenied":
            self = .notificationPermissionDenied

        case "settingsChanged":
            let setting = try container.decode(String.self, forKey: .setting)
            let oldValue = try container.decode(String.self, forKey: .oldValue)
            let newValue = try container.decode(String.self, forKey: .newValue)
            self = .settingsChanged(setting: setting, oldValue: oldValue, newValue: newValue)

        case "appLaunched":
            let version = try container.decode(String.self, forKey: .version)
            self = .appLaunched(version: version)

        case "appTerminated":
            self = .appTerminated

        case "errorOccurred":
            let component = try container.decode(String.self, forKey: .component)
            let error = try container.decode(String.self, forKey: .error)
            self = .errorOccurred(component: component, error: error)

        case "securityWarning":
            let warning = try container.decode(String.self, forKey: .warning)
            self = .securityWarning(warning: warning)

        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type")
        }
    }
}

// MARK: - Audit Log Entry

struct AuditLogEntry: Codable {
    let id: String
    let timestamp: Date
    let event: AuditEventType
    let userID: String?  // Usually nil for single-user app
    let source: String   // "ui", "system", "api"
    let ipAddress: String?  // For cloud-based audit trails

    enum CodingKeys: String, CodingKey {
        case id, timestamp, event, source
        case userID = "user_id"
        case ipAddress = "ip_address"
    }
}

// MARK: - Audit Logger

class AuditLogger {
    static let shared = AuditLogger()

    private let fileManager = FileManager.default
    private let auditDirectory: URL
    private var logs: [AuditLogEntry] = []
    private let queue = DispatchQueue(label: "com.minutly.auditlogger", attributes: .concurrent)

    init() {
        let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.auditDirectory = appSupportPath.appendingPathComponent("com.minutly/audit_logs")

        // Create audit directory if it doesn't exist
        try? fileManager.createDirectory(at: auditDirectory, withIntermediateDirectories: true)

        // Load existing audit logs
        loadAuditLogs()
    }

    // MARK: - Logging

    /// Log an audit event
    func log(
        event: AuditEventType,
        source: String = "ui",
        userID: String? = nil
    ) {
        queue.async(flags: .barrier) { [weak self] in
            let entry = AuditLogEntry(
                id: UUID().uuidString,
                timestamp: Date(),
                event: event,
                userID: userID,
                source: source,
                ipAddress: nil
            )

            self?.logs.append(entry)
            self?.persistLog(entry)

            // Log to console in debug builds
            #if DEBUG
            print("📋 [AUDIT] \(entry.timestamp.formatted()): \(event)")
            #endif
        }
    }

    // MARK: - Querying

    /// Get all audit logs
    func getAllLogs() -> [AuditLogEntry] {
        return queue.sync {
            return logs
        }
    }

    /// Get logs within a date range
    func getLogs(from startDate: Date, to endDate: Date) -> [AuditLogEntry] {
        return queue.sync {
            return logs.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
        }
    }

    /// Get logs for a specific event type
    func getLogs(forEventType eventType: String) -> [AuditLogEntry] {
        return queue.sync {
            return logs.filter { entry in
                // Extract event type from the enum
                let mirror = Mirror(reflecting: entry.event)
                return mirror.description.contains(eventType)
            }
        }
    }

    /// Get recent logs
    func getRecentLogs(count: Int = 100) -> [AuditLogEntry] {
        return queue.sync {
            return Array(logs.suffix(count))
        }
    }

    // MARK: - Export & Cleanup

    /// Export audit trail as JSON
    func exportAuditTrail() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        return queue.sync {
            try! encoder.encode(logs)
        }
    }

    /// Export audit trail to file
    func exportAuditTrailToFile(at url: URL) throws {
        let data = try exportAuditTrail()
        try data.write(to: url)
    }

    /// Delete old audit logs (older than specified days)
    func deleteOldLogs(olderThanDays: Int = 90) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.logs = self.logs.filter { $0.timestamp >= cutoffDate }

            // Delete old log files
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.auditDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    let fileData = try Data(contentsOf: file)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601

                    if let entries = try? decoder.decode([AuditLogEntry].self, from: fileData) {
                        let hasRecentEntry = entries.contains { $0.timestamp >= cutoffDate }
                        if !hasRecentEntry {
                            try self.fileManager.removeItem(at: file)
                        }
                    }
                }
            } catch {
                print("⚠️ Error cleaning up old logs: \(error.localizedDescription)")
            }
        }
    }

    /// Clear all audit logs
    func clearAllLogs() throws {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.logs.removeAll()

            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.auditDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
                print("🗑️ Cleared all audit logs")
            } catch {
                print("⚠️ Error clearing audit logs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func persistLog(_ entry: AuditLogEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(entry) else { return }

        let fileName = "\(entry.timestamp.timeIntervalSince1970).json"
        let fileURL = auditDirectory.appendingPathComponent(fileName)

        try? data.write(to: fileURL)
    }

    private func loadAuditLogs() {
        do {
            let files = try fileManager.contentsOfDirectory(at: auditDirectory, includingPropertiesForKeys: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let data = try? Data(contentsOf: file),
                   let entry = try? decoder.decode(AuditLogEntry.self, from: data) {
                    logs.append(entry)
                }
            }

            print("✅ Loaded \(logs.count) audit log entries")
        } catch {
            print("⚠️ Error loading audit logs: \(error.localizedDescription)")
        }
    }
}
