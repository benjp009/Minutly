//
//  SummaryPromptTemplates.swift
//  Minutly
//
//  Created by Claude Code on 31/12/2024.
//  Summary prompt templates for different meeting types
//

import Foundation

struct SummaryPromptTemplates {

    // MARK: - System Prompt (shared across all types)
    static let systemPrompt = """
    You are a professional meeting assistant. Analyze conversations and extract key information accurately.
    Never invent or infer information not explicitly stated in the conversation.
    Keep everything factual and business-oriented.
    Always write the summary and all task fields in the same language as the conversation.
    JSON keys stay in English; the "priority" value stays one of high/medium/low.
    """
    // ponytail: language is inferred by the model from the transcript, not plumbed
    // through from `transcriptionLanguages`. Pass the code explicitly if a user ever
    // wants a summary in a different language than the recording.

    // MARK: - User Prompts by Type

    static func userPrompt(for type: String, customPrompt: String? = nil, customInstructions: String? = nil) -> String {
        switch type {
        case "keypoints_tasks":
            return keypointsTasks
        case "executive":
            return executiveSummary
        case "technical":
            return technicalMeeting
        case "sales":
            return salesCall
        case "custom":
            // Check if advanced mode with full prompt
            if let prompt = customPrompt, !prompt.isEmpty {
                return prompt  // Use advanced JSON prompt
            }
            // Otherwise use simple instructions
            if let instructions = customInstructions, !instructions.isEmpty {
                return customPromptFromInstructions(instructions)
            }
            // Fallback to default
            return keypointsTasks
        default:
            return keypointsTasks
        }
    }

    // MARK: - Custom Instruction Wrapping

    /// Wraps user's plain-language instructions in a proper prompt template
    static func customPromptFromInstructions(_ instructions: String) -> String {
        return """
        Analyze the following conversation and create a summary based on these custom instructions:

        \(instructions)

        Extract relevant information and tasks mentioned in the conversation that align with the instructions above.

        Format your response as JSON with this structure:
        {
          "summary": "Summary based on the custom instructions above...",
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

        Only include information explicitly stated in the conversation.

        Conversation:
        {{TRANSCRIPTION}}
        """
    }

    // MARK: - Template: Key Points + Tasks (Current Default)
    private static let keypointsTasks = """
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
    {{TRANSCRIPTION}}
    """

    // MARK: - Template: Executive Summary
    private static let executiveSummary = """
    Analyze the following conversation and create an executive-level summary suitable for leadership.
    Focus on strategic decisions, outcomes, and business impact. Extract high-level action items.

    Format your response as JSON with this structure:
    {
      "summary": "Executive summary covering: key decisions made, business outcomes, strategic direction, and major risks or blockers identified...",
      "tasks": [
        {
          "task": "High-level action item",
          "owner": "Person name or null",
          "deadline": "Deadline or null",
          "dependencies": "Dependencies or null",
          "priority": "high/medium/low"
        }
      ]
    }

    Only include information explicitly stated. Do not make assumptions.

    Conversation:
    {{TRANSCRIPTION}}
    """

    // MARK: - Template: Technical Meeting Notes
    private static let technicalMeeting = """
    Analyze the following technical conversation and create detailed engineering notes.
    Focus on: technical decisions, implementation details, architecture discussions, code/system changes, technical blockers.

    Format your response as JSON with this structure:
    {
      "summary": "Technical summary covering: technologies discussed, architectural decisions, implementation approach, technical challenges identified...",
      "tasks": [
        {
          "task": "Technical task or implementation item",
          "owner": "Person name or null",
          "deadline": "Deadline or null",
          "dependencies": "Technical dependencies or null",
          "priority": "high/medium/low"
        }
      ]
    }

    Only include information explicitly stated. Do not invent technical details.

    Conversation:
    {{TRANSCRIPTION}}
    """

    // MARK: - Template: Sales Call Summary
    private static let salesCall = """
    Analyze the following sales conversation and create a sales call summary.
    Focus on: customer needs, pain points, objections raised, pricing discussed, next steps, deal status.

    Format your response as JSON with this structure:
    {
      "summary": "Sales call summary covering: customer needs/pain points, product interest areas, budget/pricing discussed, objections raised, decision timeline, competitive mentions...",
      "tasks": [
        {
          "task": "Follow-up action item",
          "owner": "Person name or null",
          "deadline": "Deadline or null",
          "dependencies": "Dependencies or null",
          "priority": "high/medium/low"
        }
      ]
    }

    Only include information explicitly stated. Do not invent customer needs or commitments.

    Conversation:
    {{TRANSCRIPTION}}
    """
}
