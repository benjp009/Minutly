//
//  OpenAITranscriptionService.swift
//  Minutly
//
//  Created by Benjamin Patin on 27/11/2025.
//

import Foundation

class OpenAITranscriptionService {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    func transcribe(
        audioURL: URL,
        languageCode: String? = nil,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> String {
        onProgress?(0.1, "Preparing audio...")

        let audioData = try Data(contentsOf: audioURL)
        onProgress?(0.3, "Uploading to OpenAI...")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            fileName: audioURL.lastPathComponent,
            languageCode: languageCode
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: message)
        }

        struct TranscriptionResponse: Codable {
            let text: String
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        onProgress?(1.0, "Transcription complete!")
        return result.text
    }

    private func buildMultipartBody(
        boundary: String,
        audioData: Data,
        fileName: String,
        languageCode: String?
    ) throws -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model", value: "whisper-1")
        if let languageCode = languageCode {
            appendField(name: "language", value: languageCode)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }
}
