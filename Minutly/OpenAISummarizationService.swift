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

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Summarization

    func summarize(transcription: String, onProgress: @escaping (Double, String) -> Void) async throws -> ConversationSummary {
        print("🤖 Starting OpenAI summarization...")
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
            (data, response) = try await URLSession.shared.data(for: request)
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

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }

        print("✅ Received response from OpenAI")

        // Parse the JSON content
        guard let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let summary = try JSONDecoder().decode(ConversationSummary.self, from: contentData)
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

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(String)
    case invalidAPIKey

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
        }
    }
}
