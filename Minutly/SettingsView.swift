//
//  SettingsView.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("assemblyAI_APIKey") private var assemblyAIKey: String = ""
    @AppStorage("openAI_APIKey") private var openAIKey: String = ""
    @AppStorage("transcriptionProvider") private var transcriptionProvider: String = "apple"
    @State private var showAPIKeyInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            Divider()

            Form {
            Section {
                Text("Transcription Settings")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Section(header: Text("Provider")) {
                Picker("Transcription Service", selection: $transcriptionProvider) {
                    Text("Apple Speech (Free, No Speaker ID)").tag("apple")
                    Text("AssemblyAI (Paid, Speaker ID)").tag("assemblyai")
                }
                .pickerStyle(.radioGroup)

                if transcriptionProvider == "apple" {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Free & Offline")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("Uses Apple's built-in speech recognition. Works offline, supports French, but cannot identify different speakers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundStyle(.purple)
                            Text("Cloud-based - Requires API Key")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("AssemblyAI provides speaker diarization (identifies who is speaking), supports 99+ languages, and offers superior accuracy. Costs ~$0.25-0.37 per hour of audio.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            if transcriptionProvider == "assemblyai" {
                Section(header: Text("AssemblyAI API Key")) {
                    SecureField("Enter your API key", text: $assemblyAIKey)
                        .textFieldStyle(.roundedBorder)

                    if assemblyAIKey.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.orange)
                                Text("API Key Required")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Text("To use AssemblyAI, you need an API key:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("1. Go to assemblyai.com")
                                Text("2. Sign up for a free account")
                                Text("3. Get $50 in free credits (~200 hours)")
                                Text("4. Copy your API key from the dashboard")
                                Text("5. Paste it above")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Button(action: {
                                NSWorkspace.shared.open(URL(string: "https://www.assemblyai.com/")!)
                            }) {
                                Label("Get API Key", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key Configured")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            Section(header: Text("OpenAI API Key (for Summarization)")) {
                SecureField("Enter your OpenAI API key", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)

                if openAIKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("AI Summarization Optional")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Text("To enable AI-powered meeting summaries and task extraction:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Go to platform.openai.com")
                            Text("2. Sign up and add credits (~$5 = 500+ summaries)")
                            Text("3. Create an API key")
                            Text("4. Paste it above")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
                        }) {
                            Label("Get OpenAI API Key", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("AI Summarization Enabled")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Text("GPT-3.5 • ~$0.001-0.002 per summary")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("Features Comparison")) {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(feature: "Cost", apple: "Free", assemblyAI: "$0.25-0.37/hour")
                    FeatureRow(feature: "Speaker Identification", apple: "No", assemblyAI: "Yes")
                    FeatureRow(feature: "French Support", apple: "Yes", assemblyAI: "Yes (99+ languages)")
                    FeatureRow(feature: "Offline", apple: "Yes", assemblyAI: "No (requires internet)")
                    FeatureRow(feature: "Accuracy", apple: "Good", assemblyAI: "Excellent")
                }
            }
        }
        .formStyle(.grouped)

        }
        .frame(width: 600, height: 600)
    }
}

struct FeatureRow: View {
    let feature: String
    let apple: String
    let assemblyAI: String

    var body: some View {
        HStack {
            Text(feature)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 150, alignment: .leading)

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(apple)
                    .font(.caption)
            }
            .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("AssemblyAI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(assemblyAI)
                    .font(.caption)
            }
            .frame(width: 150, alignment: .leading)
        }
    }
}

#Preview {
    SettingsView()
}
