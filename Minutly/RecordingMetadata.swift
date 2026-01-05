//
//  RecordingMetadata.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//  Simplified for local-only version (no cloud uploads)
//

import Foundation

// MARK: - Recording Metadata

struct RecordingMetadata: Codable {
    let id: String
    let createdAt: Date
    let title: String
    let duration: TimeInterval
    let meetingTitle: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case duration
        case meetingTitle = "meeting_title"
        case tags
    }

    init(
        id: String,
        title: String,
        duration: TimeInterval,
        meetingTitle: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = Date()
        self.title = title
        self.duration = duration
        self.meetingTitle = meetingTitle
        self.tags = tags
    }
}

// MARK: - Legacy Metadata (for migration from cloud version)

private struct LegacyRecordingMetadata: Codable {
    let id: String
    let createdAt: Date
    let title: String
    let duration: TimeInterval
    let sensitivity: String?  // Old field - no longer used
    let uploadConsents: [LegacyUploadConsent]?  // Old field - no longer used
    let meetingTitle: String?
    let tags: [String]?

    struct LegacyUploadConsent: Codable {
        let recordingID: String
        let provider: String
        let timestamp: Date
        let userConsented: Bool
        let consentReason: String?
        let expiresAt: Date?

        enum CodingKeys: String, CodingKey {
            case recordingID = "recording_id"
            case provider
            case timestamp
            case userConsented = "user_consented"
            case consentReason = "consent_reason"
            case expiresAt = "expires_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case duration
        case sensitivity
        case uploadConsents = "upload_consents"
        case meetingTitle = "meeting_title"
        case tags
    }
}

// MARK: - Recording Metadata Manager

class RecordingMetadataManager {
    static let shared = RecordingMetadataManager()

    private let fileManager = FileManager.default
    private let metadataDirectory: URL

    init() {
        let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.metadataDirectory = appSupportPath.appendingPathComponent("com.minutly/metadata")

        // Create metadata directory if it doesn't exist
        try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    }

    // Generate ID from recording URL
    private func idFromURL(_ url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }

    // Get metadata file URL
    private func metadataURLFor(_ recordingURL: URL) -> URL {
        let id = idFromURL(recordingURL)
        return metadataDirectory.appendingPathComponent("\(id).json")
    }

    // Save metadata for a recording
    func saveMetadata(_ metadata: RecordingMetadata, for recordingURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        let metadataURL = metadataURLFor(recordingURL)

        try data.write(to: metadataURL)
        print("✅ Saved metadata for recording: \(metadata.id)")
    }

    // Load metadata for a recording (with automatic migration from legacy format)
    func loadMetadata(for recordingURL: URL) throws -> RecordingMetadata? {
        let metadataURL = metadataURLFor(recordingURL)

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try new format first
        if let metadata = try? decoder.decode(RecordingMetadata.self, from: data) {
            return metadata
        }

        // Fallback to legacy format and migrate
        if let legacy = try? decoder.decode(LegacyRecordingMetadata.self, from: data) {
            let migrated = migrateFromLegacy(legacy)

            // Save migrated version immediately
            try saveMetadata(migrated, for: recordingURL)

            print("✅ Migrated metadata for: \(recordingURL.lastPathComponent)")
            if let sensitivity = legacy.sensitivity {
                print("   Dropped sensitivity field: \(sensitivity)")
            }
            if let consents = legacy.uploadConsents, !consents.isEmpty {
                print("   Dropped \(consents.count) cloud upload consent(s)")
            }

            return migrated
        }

        return nil
    }

    // Migrate from legacy format to new format
    private func migrateFromLegacy(_ legacy: LegacyRecordingMetadata) -> RecordingMetadata {
        return RecordingMetadata(
            id: legacy.id,
            title: legacy.title,
            duration: legacy.duration,
            meetingTitle: legacy.meetingTitle,
            tags: legacy.tags ?? []
        )
        // Note: sensitivity and uploadConsents are intentionally dropped
    }

    // Create or update metadata
    func createOrUpdateMetadata(
        for recordingURL: URL,
        title: String,
        duration: TimeInterval,
        meetingTitle: String? = nil
    ) throws -> RecordingMetadata {
        let id = idFromURL(recordingURL)

        // Try to load existing metadata
        if let existing = try loadMetadata(for: recordingURL) {
            return existing
        }

        // Create new metadata
        let metadata = RecordingMetadata(
            id: id,
            title: title,
            duration: duration,
            meetingTitle: meetingTitle
        )

        try saveMetadata(metadata, for: recordingURL)
        return metadata
    }

    // Delete metadata
    func deleteMetadata(for recordingURL: URL) throws {
        let metadataURL = metadataURLFor(recordingURL)
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
            print("✅ Deleted metadata for recording")
        }
    }

    // List all metadata files
    func getAllMetadata() throws -> [RecordingMetadata] {
        let metadataFiles = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)

        var allMetadata: [RecordingMetadata] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for fileURL in metadataFiles where fileURL.pathExtension == "json" {
            let data = try Data(contentsOf: fileURL)

            // Try new format
            if let metadata = try? decoder.decode(RecordingMetadata.self, from: data) {
                allMetadata.append(metadata)
                continue
            }

            // Try legacy format and migrate
            if let legacy = try? decoder.decode(LegacyRecordingMetadata.self, from: data) {
                let migrated = migrateFromLegacy(legacy)
                allMetadata.append(migrated)

                // Save migrated version
                // Reconstruct recording URL from ID
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                if let docURL = documentsURL {
                    let recordingURL = docURL.appendingPathComponent("\(legacy.id).enc")
                    try? saveMetadata(migrated, for: recordingURL)
                }
            }
        }

        return allMetadata
    }
}

// MARK: - Errors

enum MetadataError: LocalizedError {
    case recordingNotFound
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "Recording metadata not found"
        case .saveFailed:
            return "Failed to save recording metadata"
        case .loadFailed:
            return "Failed to load recording metadata"
        }
    }
}
