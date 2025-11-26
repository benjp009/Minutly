//
//  SummaryView.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI

struct SummaryView: View {
    let summary: ConversationSummary
    let onExport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.blue)
                        Text("Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    Text(summary.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                }

                // Tasks Section
                if !summary.tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checklist")
                                .foregroundStyle(.purple)
                            Text("Tasks (\(summary.tasks.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        ForEach(Array(summary.tasks.enumerated()), id: \.element.id) { index, task in
                            TaskRowView(task: task, number: index + 1)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct TaskRowView: View {
    let task: ConversationSummary.Task
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task title with number
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 25, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.task)
                        .font(.system(size: 14, weight: .semibold))
                        .textSelection(.enabled)

                    // Task details
                    VStack(alignment: .leading, spacing: 4) {
                        if let priority = task.priority {
                            HStack(spacing: 4) {
                                Image(systemName: priorityIcon(priority))
                                    .font(.caption2)
                                    .foregroundStyle(priorityColor(priority))
                                Text("Priority: \(priority.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(priorityColor(priority))
                            }
                        }

                        if let owner = task.owner {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("Owner: \(owner)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let deadline = task.deadline {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("Deadline: \(deadline)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let dependencies = task.dependencies {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                                Text("Dependencies: \(dependencies)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor(task.priority ?? "medium").opacity(0.3), lineWidth: 1)
        )
    }

    private func priorityIcon(_ priority: String) -> String {
        switch priority.lowercased() {
        case "high": return "exclamationmark.3"
        case "low": return "arrow.down"
        default: return "minus"
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "low": return .green
        default: return .orange
        }
    }
}

#Preview {
    SummaryView(
        summary: ConversationSummary(
            summary: "Discussion about the Q4 product launch strategy and timeline. Team agreed to focus on mobile-first approach with key features identified.",
            tasks: [
                ConversationSummary.Task(
                    task: "Complete mobile app wireframes",
                    owner: "Sarah",
                    deadline: "Next Friday",
                    dependencies: "Waiting for design system approval",
                    priority: "high"
                ),
                ConversationSummary.Task(
                    task: "Set up CI/CD pipeline",
                    owner: "Mike",
                    deadline: "End of month",
                    dependencies: nil,
                    priority: "medium"
                )
            ]
        ),
        onExport: {}
    )
}
