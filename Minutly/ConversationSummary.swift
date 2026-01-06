//
//  ConversationSummary.swift
//  Minutly
//
//  Created by Claude Code on 04/01/2025.
//  Data model for AI-generated conversation summaries
//

import Foundation

struct ConversationSummary: Codable, Identifiable {
    let id: String
    let summary: String
    let tasks: [Task]

    init(id: String = UUID().uuidString, summary: String, tasks: [Task] = []) {
        self.id = id
        self.summary = summary
        self.tasks = tasks
    }

    struct Task: Codable, Identifiable {
        let id: String
        let task: String
        let owner: String?
        let deadline: String?
        let dependencies: String?
        let priority: String?

        init(
            id: String = UUID().uuidString,
            task: String,
            owner: String? = nil,
            deadline: String? = nil,
            dependencies: String? = nil,
            priority: String? = nil
        ) {
            self.id = id
            self.task = task
            self.owner = owner
            self.deadline = deadline
            self.dependencies = dependencies
            self.priority = priority
        }
    }
}
