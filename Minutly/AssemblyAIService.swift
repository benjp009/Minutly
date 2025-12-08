//
//  AssemblyAIService.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import Foundation

class AssemblyAIService {
    private let baseURL = "https://api.assemblyai.com/v2"
    private var apiKey: String
    private let pinnedSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey

        // Initialize certificate pinning for api.assemblyai.com
        // In production, you should extract and pin the actual certificates
        let delegate = CertificatePinningDelegate(pinnedDomains: [:])
        self.pinnedSession = URLSession.createPinnedSession(with: delegate)
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, languageCode: String = "fr", onProgress: @escaping (Double, String) -> Void) async throws -> AssemblyAITranscript {
        print("🎙️ Starting AssemblyAI transcription for: \(audioURL.lastPathComponent)")

        // Step 1: Upload audio file
        onProgress(0.1, "Uploading audio file...")
        let uploadURL = try await uploadAudio(audioURL: audioURL)
        print("✅ Audio uploaded to: \(uploadURL)")

        // Step 2: Submit transcription request
        onProgress(0.2, "Submitting transcription request...")
        let transcriptID = try await submitTranscription(audioURL: uploadURL, languageCode: languageCode)
        print("✅ Transcript ID: \(transcriptID)")

        // Step 3: Poll for completion
        onProgress(0.3, "Processing transcription...")
        let transcript = try await pollForCompletion(transcriptID: transcriptID, onProgress: onProgress)
        print("✅ Transcription complete!")

        return transcript
    }

    // MARK: - Upload Audio

    private func uploadAudio(audioURL: URL) async throws -> String {
        let uploadEndpoint = "\(baseURL)/upload"
        guard let url = URL(string: uploadEndpoint) else {
            throw AssemblyAIError.invalidURL
        }

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)
        print("📦 Audio file size: \(audioData.count / 1024) KB")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 60 // 60 seconds timeout

        print("🌐 Uploading to: \(uploadEndpoint)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await pinnedSession.data(for: request)
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw AssemblyAIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssemblyAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Upload failed: \(errorMessage)")
            throw AssemblyAIError.uploadFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        struct UploadResponse: Codable {
            let upload_url: String
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.upload_url
    }

    // MARK: - Submit Transcription

    private func submitTranscription(audioURL: String, languageCode: String) async throws -> String {
        let transcriptEndpoint = "\(baseURL)/transcript"
        guard let url = URL(string: transcriptEndpoint) else {
            throw AssemblyAIError.invalidURL
        }

        struct TranscriptRequest: Codable {
            let audio_url: String
            let language_code: String
            let speaker_labels: Bool
            let punctuate: Bool
            let format_text: Bool
        }

        let requestBody = TranscriptRequest(
            audio_url: audioURL,
            language_code: languageCode,
            speaker_labels: true,  // Enable speaker diarization
            punctuate: true,
            format_text: true
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await pinnedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssemblyAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Transcription submission failed: \(errorMessage)")
            throw AssemblyAIError.transcriptionFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        struct TranscriptResponse: Codable {
            let id: String
        }

        let transcriptResponse = try JSONDecoder().decode(TranscriptResponse.self, from: data)
        return transcriptResponse.id
    }

    // MARK: - Poll for Completion

    private func pollForCompletion(transcriptID: String, onProgress: @escaping (Double, String) -> Void) async throws -> AssemblyAITranscript {
        let pollEndpoint = "\(baseURL)/transcript/\(transcriptID)"
        guard let url = URL(string: pollEndpoint) else {
            throw AssemblyAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")

        var attempts = 0
        let maxAttempts = 300 // 5 minutes max (300 * 1 second)

        while attempts < maxAttempts {
            let (data, response) = try await pinnedSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AssemblyAIError.invalidResponse
            }

            let transcript = try JSONDecoder().decode(AssemblyAITranscript.self, from: data)

            // Validate transcript structure
            try transcript.validate()

            switch transcript.status {
            case "completed":
                onProgress(1.0, "Transcription complete!")
                return transcript

            case "error":
                throw AssemblyAIError.transcriptionFailed(statusCode: 0, message: transcript.error ?? "Unknown error")

            case "processing", "queued":
                // Update progress (30% to 90% during processing)
                let processingProgress = 0.3 + (Double(attempts) / Double(maxAttempts)) * 0.6
                onProgress(processingProgress, "Processing... (\(attempts)s)")
                print("📊 Status: \(transcript.status) - Progress: \(Int(processingProgress * 100))%")

                // Wait 1 second before next poll
                try await Task.sleep(nanoseconds: 1_000_000_000)
                attempts += 1

            default:
                print("⚠️ Unknown status: \(transcript.status)")
                try await Task.sleep(nanoseconds: 1_000_000_000)
                attempts += 1
            }
        }

        throw AssemblyAIError.timeout
    }
}

// MARK: - Models

struct AssemblyAITranscript: Codable {
    let id: String
    let status: String
    let text: String?
    let error: String?
    let utterances: [Utterance]?
    let words: [Word]?

    struct Utterance: Codable {
        let speaker: String
        let text: String
        let start: Int
        let end: Int
        let confidence: Double

        func validate() throws {
            guard !speaker.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw AssemblyAIError.invalidTranscript(reason: "Speaker name is empty")
            }
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw AssemblyAIError.invalidTranscript(reason: "Utterance text is empty")
            }
            guard text.count < 10000 else {
                throw AssemblyAIError.invalidTranscript(reason: "Utterance text is too long")
            }
            guard start >= 0 && end >= start else {
                throw AssemblyAIError.invalidTranscript(reason: "Invalid time boundaries")
            }
            guard confidence >= 0.0 && confidence <= 1.0 else {
                throw AssemblyAIError.invalidTranscript(reason: "Invalid confidence value")
            }
        }
    }

    struct Word: Codable {
        let text: String
        let start: Int
        let end: Int
        let confidence: Double
        let speaker: String?
    }

    // Format transcript with speaker labels
    func formattedTranscript() -> String {
        guard let utterances = utterances, !utterances.isEmpty else {
            return text ?? ""
        }

        var formatted = ""
        for utterance in utterances {
            formatted += "Speaker \(utterance.speaker): \(utterance.text)\n\n"
        }
        return formatted
    }

    // Validate transcript structure
    func validate() throws {
        // Validate ID is not empty
        guard !id.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AssemblyAIError.invalidTranscript(reason: "Transcript ID is empty")
        }

        // Validate status is valid
        let validStatuses = ["queued", "processing", "completed", "error"]
        guard validStatuses.contains(status) else {
            throw AssemblyAIError.invalidTranscript(reason: "Invalid status: \(status)")
        }

        // If completed, validate text exists
        if status == "completed" {
            guard let text = text, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw AssemblyAIError.invalidTranscript(reason: "Completed transcription has no text")
            }
            guard text.count < 500000 else {
                throw AssemblyAIError.invalidTranscript(reason: "Transcript text is too long")
            }
        }

        // Validate utterances if present
        if let utterances = utterances {
            guard utterances.count < 10000 else {
                throw AssemblyAIError.invalidTranscript(reason: "Too many utterances")
            }
            for utterance in utterances {
                try utterance.validate()
            }
        }

        // Validate words if present
        if let words = words {
            guard words.count < 100000 else {
                throw AssemblyAIError.invalidTranscript(reason: "Too many words")
            }
        }
    }
}

// MARK: - Errors

enum AssemblyAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidTranscript(reason: String)
    case uploadFailed(statusCode: Int, message: String)
    case transcriptionFailed(statusCode: Int, message: String)
    case timeout
    case invalidAPIKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from AssemblyAI"
        case .invalidTranscript(let reason):
            return "Invalid transcript: \(reason)"
        case .uploadFailed(let statusCode, let message):
            return "Upload failed (HTTP \(statusCode)): \(message)"
        case .transcriptionFailed(let statusCode, let message):
            return "Transcription failed (HTTP \(statusCode)): \(message)"
        case .timeout:
            return "Transcription timed out after 5 minutes"
        case .invalidAPIKey:
            return "Invalid API key. Please check your AssemblyAI API key in settings."
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection and ensure the app has network access."
        }
    }
}
