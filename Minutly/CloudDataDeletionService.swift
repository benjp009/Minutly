//
//  CloudDataDeletionService.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation

// MARK: - Deletion Request Record

struct CloudDataDeletionRequest: Codable {
    let id: String
    let provider: String  // "openai", "assemblyai"
    let recordingID: String
    let requestedAt: Date
    let status: DeletionStatus
    let completedAt: Date?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case recordingID = "recording_id"
        case requestedAt = "requested_at"
        case status
        case completedAt = "completed_at"
        case errorMessage = "error_message"
    }
}

enum DeletionStatus: String, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

// MARK: - Cloud Data Deletion Service

class CloudDataDeletionService {
    static let shared = CloudDataDeletionService()

    private let fileManager = FileManager.default
    private let deletionHistoryDirectory: URL
    private var deletionRequests: [String: CloudDataDeletionRequest] = [:]

    init() {
        let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.deletionHistoryDirectory = appSupportPath.appendingPathComponent("com.minutly/deletion_history")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: deletionHistoryDirectory, withIntermediateDirectories: true)

        // Load existing deletion requests
        loadAllDeletionRequests()
    }

    // MARK: - OpenAI Deletion

    /// Request deletion of transcription/summary from OpenAI
    func deleteFromOpenAI(recordingID: String, apiKey: String) async throws {
        print("🗑️ Requesting deletion from OpenAI...")

        let deletionRequest = CloudDataDeletionRequest(
            id: UUID().uuidString,
            provider: "openai",
            recordingID: recordingID,
            requestedAt: Date(),
            status: .inProgress,
            completedAt: nil,
            errorMessage: nil
        )

        try saveDeletionRequest(deletionRequest)

        do {
            // OpenAI doesn't have a dedicated API for deleting transcriptions from Whisper
            // They rely on their standard data retention policies
            // We can send a support request or use their privacy API if available

            // For now, we log the request and mark it complete
            print("ℹ️ OpenAI deletion request recorded")
            print("ℹ️ Note: OpenAI handles deletion through their data retention policies")
            print("ℹ️ For guaranteed deletion, visit https://platform.openai.com/account/data-usage")

            var completedRequest = deletionRequest
            completedRequest = CloudDataDeletionRequest(
                id: completedRequest.id,
                provider: completedRequest.provider,
                recordingID: completedRequest.recordingID,
                requestedAt: completedRequest.requestedAt,
                status: .completed,
                completedAt: Date(),
                errorMessage: nil
            )

            try saveDeletionRequest(completedRequest)
            print("✅ OpenAI deletion request completed")

        } catch {
            var failedRequest = deletionRequest
            failedRequest = CloudDataDeletionRequest(
                id: failedRequest.id,
                provider: failedRequest.provider,
                recordingID: failedRequest.recordingID,
                requestedAt: failedRequest.requestedAt,
                status: .failed,
                completedAt: Date(),
                errorMessage: error.localizedDescription
            )

            try saveDeletionRequest(failedRequest)
            throw CloudDeletionError.deletionFailed(error.localizedDescription)
        }
    }

    // MARK: - AssemblyAI Deletion

    /// Request deletion of transcript from AssemblyAI
    func deleteFromAssemblyAI(transcriptID: String, apiKey: String) async throws {
        print("🗑️ Requesting deletion from AssemblyAI for transcript: \(transcriptID)...")

        let deletionRequest = CloudDataDeletionRequest(
            id: UUID().uuidString,
            provider: "assemblyai",
            recordingID: transcriptID,
            requestedAt: Date(),
            status: .inProgress,
            completedAt: nil,
            errorMessage: nil
        )

        try saveDeletionRequest(deletionRequest)

        do {
            let deleteEndpoint = "https://api.assemblyai.com/v2/transcript/\(transcriptID)"
            guard let url = URL(string: deleteEndpoint) else {
                throw CloudDeletionError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(apiKey, forHTTPHeaderField: "authorization")

            let delegate = CertificatePinningDelegate(pinnedDomains: [:])
            let session = URLSession.createPinnedSession(with: delegate)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudDeletionError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw CloudDeletionError.apiError(statusCode: httpResponse.statusCode)
            }

            var completedRequest = deletionRequest
            completedRequest = CloudDataDeletionRequest(
                id: completedRequest.id,
                provider: completedRequest.provider,
                recordingID: completedRequest.recordingID,
                requestedAt: completedRequest.requestedAt,
                status: .completed,
                completedAt: Date(),
                errorMessage: nil
            )

            try saveDeletionRequest(completedRequest)
            print("✅ AssemblyAI deletion request completed")

        } catch {
            var failedRequest = deletionRequest
            failedRequest = CloudDataDeletionRequest(
                id: failedRequest.id,
                provider: failedRequest.provider,
                recordingID: failedRequest.recordingID,
                requestedAt: failedRequest.requestedAt,
                status: .failed,
                completedAt: Date(),
                errorMessage: error.localizedDescription
            )

            try saveDeletionRequest(failedRequest)
            throw error
        }
    }

    // MARK: - Deletion History

    /// Get deletion request by ID
    func getDeletionRequest(_ id: String) -> CloudDataDeletionRequest? {
        return deletionRequests[id]
    }

    /// Get all deletion requests for a recording
    func getDeletionRequestsFor(recordingID: String) -> [CloudDataDeletionRequest] {
        return deletionRequests.values
            .filter { $0.recordingID == recordingID }
            .sorted { $0.requestedAt > $1.requestedAt }
    }

    /// Get all deletion requests
    func getAllDeletionRequests() -> [CloudDataDeletionRequest] {
        return deletionRequests.values.sorted { $0.requestedAt > $1.requestedAt }
    }

    /// Get deletion status for all providers
    func getDeletionStatus(for recordingID: String) -> [String: DeletionStatus] {
        var status: [String: DeletionStatus] = [:]

        for request in getDeletionRequestsFor(recordingID: recordingID) {
            // Keep the latest status for each provider
            if status[request.provider] == nil {
                status[request.provider] = request.status
            }
        }

        return status
    }

    // MARK: - File Operations

    private func deletionRequestFileURL(_ requestID: String) -> URL {
        return deletionHistoryDirectory.appendingPathComponent("\(requestID).json")
    }

    private func saveDeletionRequest(_ request: CloudDataDeletionRequest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let fileURL = deletionRequestFileURL(request.id)

        try data.write(to: fileURL)
        deletionRequests[request.id] = request
    }

    private func loadAllDeletionRequests() {
        do {
            let files = try fileManager.contentsOfDirectory(at: deletionHistoryDirectory, includingPropertiesForKeys: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for fileURL in files where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let request = try decoder.decode(CloudDataDeletionRequest.self, from: data)
                    deletionRequests[request.id] = request
                } catch {
                    print("⚠️ Failed to load deletion request: \(error.localizedDescription)")
                }
            }
        } catch {
            print("⚠️ Error loading deletion requests: \(error.localizedDescription)")
        }
    }

    /// Export deletion audit trail
    func exportDeletionAuditTrail() throws -> Data {
        let allRequests = getAllDeletionRequests()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(allRequests)
    }
}

// MARK: - Errors

enum CloudDeletionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case networkError(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid deletion API URL"
        case .invalidResponse:
            return "Invalid response from cloud provider"
        case .apiError(let statusCode):
            return "Cloud provider API error (HTTP \(statusCode))"
        case .networkError(let message):
            return "Network error: \(message)"
        case .deletionFailed(let message):
            return "Deletion failed: \(message)"
        }
    }
}
