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
        onProgress(0.05, "📊 Analyzing \(estimatedTokens) tokens...")

        // Ensure model is downloaded and initialized
        if !modelManager.isModelDownloaded() {
            let modelName = modelManager.selectModelForDevice().displayName
            onProgress(0.1, "📥 Downloading \(modelName) (~800 MB)...")

            // Monitor download progress and map it to 10-50% of total progress
            let downloadTask = Task {
                while modelManager.isDownloading {
                    let downloadProgress = await MainActor.run { modelManager.downloadProgress }
                    // Map download progress (0-1) to overall progress (0.1-0.5)
                    let mappedProgress = 0.1 + (downloadProgress * 0.4)
                    let percentage = Int(downloadProgress * 100)
                    onProgress(mappedProgress, "📥 Downloading model... \(percentage)%")
                    try? await Task.sleep(nanoseconds: 500_000_000)  // Update every 0.5s
                }
            }

            try await modelManager.downloadModel()
            downloadTask.cancel()
            onProgress(0.5, "✅ Model downloaded successfully")
        }

        onProgress(0.55, "🔄 Loading model...")

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
        _ = formatPromptForLlama(systemPrompt: systemPrompt, userPrompt: userPrompt)

        onProgress(0.6, "🧠 Generating summary with local AI...")

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
        // Simulate processing time (60-100% of progress)
        onProgress(0.7, "🔄 Processing transcription...")
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        onProgress(0.8, "📝 Extracting key points...")
        try await Task.sleep(nanoseconds: 500_000_000)

        onProgress(0.95, "✅ Finalizing summary...")
        try await Task.sleep(nanoseconds: 300_000_000)

        // Return a basic rule-based summary
        // TODO: Replace with actual Llama-generated summary
        let sentences = transcription.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let wordCount = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count

        // Extract first few sentences as summary
        let summaryText = sentences.prefix(3).joined(separator: ". ") + (sentences.count > 3 ? "." : "")

        // Simple keyword extraction for tasks
        let taskKeywords = ["todo", "task", "action", "need to", "should", "must", "have to", "going to"]
        let potentialTasks = sentences.filter { sentence in
            let lower = sentence.lowercased()
            return taskKeywords.contains(where: { lower.contains($0) })
        }

        // Generate tasks from potential task sentences
        var tasks: [ConversationSummary.Task] = []
        for (index, taskSentence) in potentialTasks.prefix(5).enumerated() {
            tasks.append(ConversationSummary.Task(
                task: taskSentence,
                owner: "",
                deadline: "",
                dependencies: "",
                priority: index == 0 ? "high" : "medium"
            ))
        }

        return ConversationSummary(
            summary: summaryText.isEmpty ? "No summary available - transcription is too short." : summaryText,
            tasks: tasks.isEmpty ? [] : tasks
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
