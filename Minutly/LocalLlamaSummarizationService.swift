//
//  LocalLlamaSummarizationService.swift
//  Minutly
//
//  Created by Claude Code on 04/01/2025.
//  Local AI summarization using Llama models (replaces OpenAI GPT-3.5)
//

import Foundation

class LocalLlamaSummarizationService {
    static let shared = LocalLlamaSummarizationService()

    // TODO: Will integrate with llama.swift package when added
    // private var llamaContext: LlamaContext?

    private let modelManager = LlamaModelManager.shared

    private init() {}

    // MARK: - Summarization

    /// Summarize transcription using local Llama model
    func summarize(
        transcription: String,
        summaryType: String? = nil,
        customPrompt: String? = nil,
        customInstructions: String? = nil,
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> ConversationSummary {
        print("🤖 Starting local Llama summarization...")

        // Validate transcription length
        try validateTranscriptionLength(transcription)

        let estimatedTokens = estimateTokens(transcription)
        onProgress(0.1, "📊 Analyzing \(estimatedTokens) tokens...")

        // Ensure model is downloaded and initialized
        if !modelManager.isModelDownloaded() {
            onProgress(0.2, "📥 Downloading AI model...")
            try await modelManager.downloadModel()
        }

        onProgress(0.3, "🔄 Loading model...")

        // TODO: Initialize Llama context when llama.swift is integrated
        // try await initializeLlamaContext()

        // Build prompts using existing template system (same as OpenAI)
        let systemPrompt = SummaryPromptTemplates.systemPrompt
        let type = summaryType ?? UserDefaults.standard.string(forKey: "summaryType") ?? "keypoints_tasks"
        let custom = customPrompt ?? UserDefaults.standard.string(forKey: "customSummaryPrompt") ?? ""
        let instructions = customInstructions ?? UserDefaults.standard.string(forKey: "customSummaryInstructions") ?? ""

        let userPromptTemplate = SummaryPromptTemplates.userPrompt(
            for: type,
            customPrompt: custom.isEmpty ? nil : custom,
            customInstructions: instructions.isEmpty ? nil : instructions
        )

        // Replace placeholder with actual transcription
        let userPrompt = userPromptTemplate.replacingOccurrences(of: "{{TRANSCRIPTION}}", with: transcription)

        print("✅ Using summary type: \(type)")

        // Format prompt for Llama instruction format
        let llamaPrompt = formatPromptForLlama(systemPrompt: systemPrompt, userPrompt: userPrompt)

        onProgress(0.4, "🧠 Generating summary with local AI...")

        // TODO: Generate completion with llama.swift
        // For now, return a placeholder that shows the structure works
        // This will be replaced with actual Llama inference once llama.swift package is added

        let summary = try await generateSummaryPlaceholder(
            transcription: transcription,
            onProgress: onProgress
        )

        onProgress(1.0, "✅ Summary generated!")
        return summary
    }

    // MARK: - Prompt Formatting

    /// Format prompts for Llama instruction format
    private func formatPromptForLlama(systemPrompt: String, userPrompt: String) -> String {
        // Llama 3.2 instruction format
        return """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        \(systemPrompt)<|eot_id|>
        <|start_header_id|>user<|end_header_id|>
        \(userPrompt)<|eot_id|>
        <|start_header_id|>assistant<|end_header_id|>
        """
    }

    // MARK: - Token Estimation

    /// Estimate tokens in text (rough approximation: 1 token ≈ 4 characters)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Validate transcription length before summarization
    private func validateTranscriptionLength(_ transcription: String) throws {
        // Use different limits based on device (Intel vs Apple Silicon)
        let maxTokens = modelManager.isIntelMac ? 2048 : 4096
        let maxChars = maxTokens * 4  // ~8,192 for Intel, ~16,384 for Apple Silicon

        let estimatedTokens = estimateTokens(transcription)

        guard transcription.count <= maxChars else {
            throw SummarizationError.contentTooLarge(
                size: transcription.count,
                maxSize: maxChars,
                estimatedTokens: estimatedTokens
            )
        }

        print("✅ Transcription length valid: \(estimatedTokens) tokens (~\(transcription.count) chars)")
    }

    // MARK: - Placeholder Implementation

    /// Temporary placeholder that returns a basic summary structure
    /// This will be replaced with actual Llama inference once llama.swift is integrated
    private func generateSummaryPlaceholder(
        transcription: String,
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> ConversationSummary {
        // Simulate processing time
        onProgress(0.5, "🔄 Processing...")
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        onProgress(0.7, "📝 Extracting insights...")
        try await Task.sleep(nanoseconds: 500_000_000)

        onProgress(0.9, "✅ Finalizing...")
        try await Task.sleep(nanoseconds: 300_000_000)

        // Return a basic placeholder summary
        // TODO: Replace with actual Llama-generated summary
        let wordCount = transcription.components(separatedBy: .whitespacesAndNewlines).count

        return ConversationSummary(
            summary: """
            📝 Local AI Summary (Placeholder)

            This is a placeholder summary generated while Llama integration is in progress.

            Transcription length: \(wordCount) words
            Device: \(modelManager.isIntelMac ? "Intel Mac" : "Apple Silicon")
            Model: \(modelManager.currentModel?.displayName ?? "Not loaded")

            Once llama.swift package is integrated, this will be replaced with actual AI-generated summaries using the local Llama model.
            """,
            tasks: [
                ConversationSummary.Task(
                    task: "Complete llama.swift integration",
                    owner: "Development team",
                    deadline: "Week 1",
                    dependencies: "Package dependency added",
                    priority: "high"
                ),
                ConversationSummary.Task(
                    task: "Test local AI summarization",
                    owner: "QA team",
                    deadline: "Week 2",
                    dependencies: "Llama integration complete",
                    priority: "high"
                )
            ]
        )
    }

    // MARK: - Chunking Strategy (for long transcriptions)

    /// Split long transcriptions into chunks
    private func splitTranscription(_ transcription: String, maxTokens: Int) -> [String] {
        let maxChars = maxTokens * 4
        var chunks: [String] = []

        // Simple word-boundary aware splitting
        let words = transcription.components(separatedBy: .whitespacesAndNewlines)
        var currentChunk = ""

        for word in words {
            if (currentChunk.count + word.count + 1) > maxChars {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = word
            } else {
                currentChunk += (currentChunk.isEmpty ? "" : " ") + word
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    /// Merge summaries from multiple chunks
    private func mergeSummaries(_ summaries: [ConversationSummary]) -> ConversationSummary {
        let mergedSummary = summaries.map { $0.summary }.joined(separator: "\n\n")
        let mergedTasks = summaries.flatMap { $0.tasks }

        return ConversationSummary(summary: mergedSummary, tasks: mergedTasks)
    }
}

// MARK: - Errors

enum SummarizationError: LocalizedError {
    case modelNotDownloaded
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case contentTooLarge(size: Int, maxSize: Int, estimatedTokens: Int)
    case deviceInsufficientResources
    case modelNeedsRedownload
    case deviceTooSlow

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "AI model not downloaded. Please download the model first to enable summarization."
        case .modelLoadFailed(let message):
            return "Failed to load AI model: \(message)"
        case .inferenceFailed(let message):
            return "AI inference failed: \(message)"
        case .contentTooLarge(let size, let maxSize, let tokens):
            return "Transcription too large (\(size) chars, ~\(tokens) tokens). Maximum: \(maxSize) chars."
        case .deviceInsufficientResources:
            return "Insufficient device resources. Try closing other apps or use a smaller model."
        case .modelNeedsRedownload:
            return "Model file is corrupted. Please re-download the model."
        case .deviceTooSlow:
            return "Summarization is taking too long on this device. Consider upgrading to a newer Mac."
        }
    }
}
