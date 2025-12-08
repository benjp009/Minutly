//
//  RecordingMetadata.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation

// MARK: - Data Sensitivity Levels

enum DataSensitivity: String, Codable {
    case publicData = "public"           // Safe to upload to cloud
    case confidential = "confidential"   // Requires explicit consent per upload
    case restricted = "restricted"       // Should not be uploaded to cloud

    var displayName: String {
        switch self {
        case .publicData:
            return "Public - Safe for cloud"
        case .confidential:
            return "Confidential - Requires consent"
        case .restricted:
            return "Restricted - Keep local only"
        }
    }

    var description: String {
        switch self {
        case .publicData:
            return "This recording can be safely uploaded to cloud services for transcription."
        case .confidential:
            return "This recording contains sensitive information and requires explicit consent before cloud upload."
        case .restricted:
            return "This recording should not be uploaded to any cloud services."
        }
    }
}

// MARK: - Upload Consent Record

struct UploadConsent: Codable {
    let recordingID: String
    let provider: String  // "assemblyai", "openai"
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

    func isValid() -> Bool {
        if let expiresAt = expiresAt {
            return Date() < expiresAt
        }
        return true
    }
}

// MARK: - Recording Metadata

struct RecordingMetadata: Codable {
    let id: String
    let createdAt: Date
    let title: String
    let duration: TimeInterval
    let sensitivity: DataSensitivity
    var uploadConsents: [UploadConsent]
    let meetingTitle: String?
    let tags: [String]

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

    init(
        id: String,
        title: String,
        duration: TimeInterval,
        sensitivity: DataSensitivity = .confidential,
        meetingTitle: String? = nil
    ) {
        self.id = id
        self.createdAt = Date()
        self.title = title
        self.duration = duration
        self.sensitivity = sensitivity
        self.uploadConsents = []
        self.meetingTitle = meetingTitle
        self.tags = []
    }

    // Check if user has consented to upload to a specific provider
    func hasConsentFor(_ provider: String) -> Bool {
        return uploadConsents.contains { consent in
            consent.provider == provider &&
            consent.userConsented &&
            consent.isValid()
        }
    }

    // Determine if upload to cloud is allowed
    var allowsCloudUpload: Bool {
        return sensitivity != .restricted
    }

    // Determine if consent is required before upload
    var requiresUploadConsent: Bool {
        return sensitivity == .confidential || sensitivity == .publicData
    }

    // Add consent record
    mutating func addConsent(_ consent: UploadConsent) {
        // Remove any existing consent for this provider
        uploadConsents.removeAll { $0.provider == consent.provider }
        uploadConsents.append(consent)
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

    // Load metadata for a recording
    func loadMetadata(for recordingURL: URL) throws -> RecordingMetadata? {
        let metadataURL = metadataURLFor(recordingURL)

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(RecordingMetadata.self, from: data)
    }

    // Create or update metadata
    func createOrUpdateMetadata(
        for recordingURL: URL,
        title: String,
        duration: TimeInterval,
        sensitivity: DataSensitivity = .confidential,
        meetingTitle: String? = nil
    ) throws -> RecordingMetadata {
        let id = idFromURL(recordingURL)

        // Try to load existing metadata
        if var existing = try loadMetadata(for: recordingURL) {
            // Reset consents on update by creating new metadata with empty consents
            existing = RecordingMetadata(
                id: existing.id,
                title: existing.title,
                duration: existing.duration,
                sensitivity: existing.sensitivity,
                meetingTitle: existing.meetingTitle
            )
            try saveMetadata(existing, for: recordingURL)
            return existing
        }

        // Create new metadata
        let metadata = RecordingMetadata(
            id: id,
            title: title,
            duration: duration,
            sensitivity: sensitivity,
            meetingTitle: meetingTitle
        )

        try saveMetadata(metadata, for: recordingURL)
        return metadata
    }

    // Add upload consent
    func addUploadConsent(
        for recordingURL: URL,
        provider: String,
        userConsented: Bool,
        reason: String? = nil,
        expiresAt: Date? = nil
    ) throws {
        guard var metadata = try loadMetadata(for: recordingURL) else {
            throw MetadataError.recordingNotFound
        }

        let consent = UploadConsent(
            recordingID: metadata.id,
            provider: provider,
            timestamp: Date(),
            userConsented: userConsented,
            consentReason: reason,
            expiresAt: expiresAt
        )

        metadata.addConsent(consent)
        try saveMetadata(metadata, for: recordingURL)

        if userConsented {
            print("✅ Added upload consent for \(provider)")
        } else {
            print("⛔ User denied upload consent for \(provider)")
        }
    }

    // Check if upload is allowed
    func canUpload(for recordingURL: URL, to provider: String) throws -> Bool {
        guard let metadata = try loadMetadata(for: recordingURL) else {
            throw MetadataError.recordingNotFound
        }

        // Check if cloud upload is allowed for this sensitivity level
        guard metadata.allowsCloudUpload else {
            print("⛔ Upload blocked: Recording has restricted sensitivity")
            return false
        }

        // Check if consent is required
        if metadata.requiresUploadConsent {
            let hasConsent = metadata.hasConsentFor(provider)
            if !hasConsent {
                print("⛔ Upload blocked: No valid consent for \(provider)")
            }
            return hasConsent
        }

        return true
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
            if let metadata = try? decoder.decode(RecordingMetadata.self, from: data) {
                allMetadata.append(metadata)
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
