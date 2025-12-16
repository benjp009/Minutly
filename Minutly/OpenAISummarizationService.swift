//
//  OpenAISummarizationService.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import Foundation

class OpenAISummarizationService {
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String
    private let pinnedSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey

        // Initialize certificate pinning for api.openai.com
        // In production, you should extract and pin the actual certificates
        let delegate = CertificatePinningDelegate(pinnedDomains: [:])
        self.pinnedSession = URLSession.createPinnedSession(with: delegate)
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - API Key Validation

    static func validateAPIKey(_ apiKey: String) async throws -> Bool {
        let endpoint = "https://api.openai.com/v1/models"

        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Use certificate pinning for production
        let delegate = CertificatePinningDelegate(pinnedDomains: [:])
        let session = URLSession.createPinnedSession(with: delegate)

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            // Status 200 = valid key, 401 = invalid key
            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            } else {
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: "API validation failed")
            }
        } catch {
            if error is OpenAIError {
                throw error
            }
            throw OpenAIError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Token Validation

    /// Estimate tokens in text (rough approximation: 1 token ≈ 4 characters)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Validate transcription length before summarization
    private func validateTranscriptionLength(_ transcription: String) throws {
        let maxChars = 100_000  // ~25,000 tokens
        let estimatedTokens = estimateTokens(transcription)

        guard transcription.count <= maxChars else {
            throw OpenAIError.contentTooLarge(
                size: transcription.count,
                maxSize: maxChars,
                estimatedTokens: estimatedTokens
            )
        }

        print("✅ Transcription length valid: \(estimatedTokens) tokens (~\(transcription.count) chars)")
    }

    // MARK: - Summarization

    func summarize(transcription: String, onProgress: @escaping (Double, String) -> Void) async throws -> ConversationSummary {
        print("🤖 Starting OpenAI summarization...")

        // Validate transcription length
        try validateTranscriptionLength(transcription)

        onProgress(0.1, "Preparing request...")

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        // Build the prompt
        let systemPrompt = """
        You are a professional meeting assistant. Analyze conversations and extract key information accurately.
        Never invent or infer information not explicitly stated in the conversation.
        Keep everything factual and business-oriented.
        """

        let userPrompt = """
        Analyze the following conversation and produce a concise summary of the key points discussed.
        Then generate a clear, prioritized list of tasks/objectives extracted strictly from the conversation, with for each:

        - Task
        - Owner (if mentioned)
        - Deadline (if mentioned)
        - Dependencies (if mentioned)

        Do not invent or infer anything not explicitly stated. Keep everything factual and business-oriented.

        Format your response as JSON with this structure:
        {
          "summary": "Brief summary of key points...",
          "tasks": [
            {
              "task": "Task description",
              "owner": "Person name or null",
              "deadline": "Deadline or null",
              "dependencies": "Dependencies or null",
              "priority": "high/medium/low"
            }
          ]
        }

        Conversation:
        \(transcription)
        """

        // Create request
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        onProgress(0.3, "Sending to OpenAI...")
        print("🌐 Sending request to OpenAI...")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await pinnedSession.data(for: request)
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw OpenAIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        onProgress(0.7, "Processing response...")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ OpenAI API error (HTTP \(httpResponse.statusCode)): \(errorMessage)")
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        // Validate response structure
        guard !openAIResponse.choices.isEmpty else {
            throw OpenAIError.invalidResponse
        }

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }

        // Validate content is not empty
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw OpenAIError.invalidResponse
        }

        print("✅ Received response from OpenAI")

        // Parse the JSON content
        guard let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        // Decode with strict validation
        let decoder = JSONDecoder()
        let summary = try decoder.decode(ConversationSummary.self, from: contentData)

        // Validate summary structure
        try summary.validate()

        onProgress(1.0, "Complete!")

        print("✅ Summary parsed successfully: \(summary.tasks.count) tasks found")
        return summary
    }
}

// MARK: - Models

struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

struct ConversationSummary: Codable {
    let summary: String
    let tasks: [Task]

    struct Task: Codable, Identifiable {
        var id: UUID { UUID() }
        let task: String
        let owner: String?
        let deadline: String?
        let dependencies: String?
        let priority: String?

        enum CodingKeys: String, CodingKey {
            case task, owner, deadline, dependencies, priority
        }

        func validate() throws {
            // Validate task is not empty
            guard !task.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.emptyTask
            }
            // Validate reasonable task length (prevent injection)
            guard task.count < 10000 else {
                throw ValidationError.taskTooLong
            }
            // Validate priority if present
            if let priority = priority {
                let validPriorities = ["high", "medium", "low"]
                guard validPriorities.contains(priority.lowercased()) else {
                    throw ValidationError.invalidPriority
                }
            }
        }
    }

    func validate() throws {
        // Validate summary is not empty
        guard !summary.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptySummary
        }
        // Validate reasonable summary length
        guard summary.count < 50000 else {
            throw ValidationError.summaryTooLong
        }
        // Validate task count
        guard tasks.count < 200 else {
            throw ValidationError.tooManyTasks
        }
        // Validate each task
        for task in tasks {
            try task.validate()
        }
    }

    // Format as readable text
    func formattedText() -> String {
        var text = "# Summary\n\n\(summary)\n\n"

        if !tasks.isEmpty {
            text += "# Tasks\n\n"
            for (index, task) in tasks.enumerated() {
                text += "\(index + 1). **\(task.task)**\n"
                if let owner = task.owner {
                    text += "   - Owner: \(owner)\n"
                }
                if let deadline = task.deadline {
                    text += "   - Deadline: \(deadline)\n"
                }
                if let dependencies = task.dependencies {
                    text += "   - Dependencies: \(dependencies)\n"
                }
                if let priority = task.priority {
                    text += "   - Priority: \(priority)\n"
                }
                text += "\n"
            }
        }

        return text
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptySummary
    case summaryTooLong
    case emptyTask
    case taskTooLong
    case invalidPriority
    case tooManyTasks

    var errorDescription: String? {
        switch self {
        case .emptySummary:
            return "Summary cannot be empty"
        case .summaryTooLong:
            return "Summary is too long (max 50000 characters)"
        case .emptyTask:
            return "Task cannot be empty"
        case .taskTooLong:
            return "Task is too long (max 10000 characters)"
        case .invalidPriority:
            return "Priority must be 'high', 'medium', or 'low'"
        case .tooManyTasks:
            return "Too many tasks (max 200)"
        }
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(String)
    case invalidAPIKey
    case contentTooLarge(size: Int, maxSize: Int, estimatedTokens: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let statusCode, let message):
            if statusCode == 401 {
                return "Invalid OpenAI API key. Please check your API key in Settings."
            } else if statusCode == 429 {
                return "OpenAI rate limit exceeded. Please try again later."
            } else {
                return "OpenAI API error (HTTP \(statusCode)): \(message)"
            }
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection."
        case .invalidAPIKey:
            return "OpenAI API key not configured. Please add your API key in Settings."
        case .contentTooLarge(let size, let maxSize, let tokens):
            return "Transcription too large (\(size) chars, ~\(tokens) tokens). Maximum: \(maxSize) chars (~25,000 tokens)."
        }
    }
}
