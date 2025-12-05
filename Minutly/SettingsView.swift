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
    @AppStorage("enableMeetingDetection") private var enableMeetingDetection = false
    @AppStorage("enableMenuBarMode") private var enableMenuBarMode = false
    @State private var showRestartAlert = false
    @State private var selectedSection: SettingsSection = .general

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case meetingDetection = "Meeting Detection"
        case transcription = "Transcription"
        case api = "API"

        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainContent
        }
        .frame(width: 800, height: 600)
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK") {}
        } message: {
            Text("Please restart Minutly for the menu bar mode change to take effect.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                Text("Settings")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.top, 12)

            ForEach(SettingsSection.allCases) { section in
                SettingsMenuItem(
                    title: sectionTitle(section),
                    isSelected: selectedSection == section,
                    action: { selectedSection = section }
                )
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .frame(width: 220, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sectionTitle(_ section: SettingsSection) -> String {
        switch section {
        case .meetingDetection:
            return "Meeting Detection"
        case .general:
            return "General"
        case .transcription:
            return "Transcription"
        case .api:
            return "API"
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedSection {
                case .general:
                    generalSection
                case .meetingDetection:
                    meetingDetectionSection
                case .transcription:
                    transcriptionSection
                case .api:
                    apiSection
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
            .padding(.trailing, 24)
            .padding(.leading, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2)
                .fontWeight(.bold)

            Toggle("Show in Menu Bar only", isOn: $enableMenuBarMode)
                .onChange(of: enableMenuBarMode) { _, _ in
                    showRestartAlert = true
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(.purple)
                    Text("Menu Bar Mode")
                        .font(.headline)
                }

                Text("""
                • App runs in the background from menu bar
                • Ideal for automatic meeting detection
                • Click menu bar icon to access recordings quickly
                • Requires restart to take effect
                """)
                .font(.caption)
                .foregroundStyle(.secondary)

                if enableMenuBarMode {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Please restart the app to enable menu bar mode")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meetingDetectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Detection")
                .font(.title2)
                .fontWeight(.bold)

            Toggle("Auto-detect meetings from Calendar", isOn: $enableMeetingDetection)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    Text("How it works")
                        .font(.headline)
                }

                Text("""
                • Monitors macOS Calendar for upcoming meetings
                • Notifies you 2 minutes before a meeting starts
                • Starts a 30-second pre-buffer when confirmed
                • Keeps the last 30 seconds before recording
                """)
                .font(.caption)
                .foregroundStyle(.secondary)

                if enableMeetingDetection {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Meeting detection enabled")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription")
                .font(.title2)
                .fontWeight(.bold)

            Picker("Provider", selection: $transcriptionProvider) {
                Text("Apple Speech (Free, No Speaker ID)").tag("apple")
                Text("AssemblyAI (Paid, Speaker ID)").tag("assemblyai")
                Text("OpenAI Whisper (Paid, High Accuracy)").tag("openai")
            }
            .pickerStyle(.radioGroup)

            switch transcriptionProvider {
            case "assemblyai":
                infoBlock(
                    icon: "network",
                    color: .purple,
                    title: "AssemblyAI Cloud",
                    description: "Supports 99+ languages, offers speaker diarization, and has higher accuracy. Requires an AssemblyAI API key."
                )
            case "openai":
                infoBlock(
                    icon: "sparkles",
                    color: .orange,
                    title: "OpenAI Whisper",
                    description: "Uses OpenAI's Whisper model for transcription. Requires an OpenAI API key and offers excellent accuracy with per-minute billing."
                )
            default:
                infoBlock(
                    icon: "info.circle.fill",
                    color: .blue,
                    title: "Free & Offline",
                    description: "Uses Apple's built-in speech recognition. Works offline, supports French, but cannot identify multiple speakers."
                )
            }

            if transcriptionProvider == "openai" && (openAIKey.isEmpty) {
                infoBlock(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "OpenAI Key Required",
                    description: "Add your OpenAI API key in the API tab to enable Whisper transcription."
                )
            }
            if transcriptionProvider == "assemblyai" && assemblyAIKey.isEmpty {
                infoBlock(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "AssemblyAI Key Required",
                    description: "Add your AssemblyAI key in the API tab to enable this provider."
                )
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoBlock(icon: String, color: Color, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("API Settings")
                .font(.title2)
                .fontWeight(.bold)

            assemblySection
            Divider()
            openAISection
            Divider()
            comparisonSection
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assemblySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AssemblyAI API Key")
                .font(.headline)

            SecureField("Enter your API key", text: $assemblyAIKey)
                .textFieldStyle(.roundedBorder)

            if assemblyAIKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    infoBlock(
                        icon: "key.fill",
                        color: .orange,
                        title: "API Key Required",
                        description: "To use AssemblyAI, sign up on assemblyai.com, get $50 in credits (~200 hours), and paste your key above."
                    )
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://www.assemblyai.com/")!)
                    }) {
                        Label("Get API Key", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
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

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OpenAI API Key")
                .font(.headline)

            SecureField("Enter your OpenAI API key", text: $openAIKey)
                .textFieldStyle(.roundedBorder)

            if openAIKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    infoBlock(
                        icon: "sparkles",
                        color: .orange,
                        title: "AI Summarization Optional",
                        description: "Enable GPT summaries by creating an API key on platform.openai.com and adding credits (~$5 = 500+ summaries)."
                    )
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
                    }) {
                        Label("Get OpenAI API Key", systemImage: "arrow.up.right.square")
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
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features Comparison")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(feature: "Cost", apple: "Free", assemblyAI: "$0.25-0.37/hour")
                FeatureRow(feature: "Speaker Identification", apple: "No", assemblyAI: "Yes")
                FeatureRow(feature: "French Support", apple: "Yes", assemblyAI: "Yes (99+ languages)")
                FeatureRow(feature: "Offline", apple: "Yes", assemblyAI: "No (requires internet)")
                FeatureRow(feature: "Accuracy", apple: "Good", assemblyAI: "Excellent")
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
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

struct SettingsMenuItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.gray.opacity(0.15)
        } else {
            return Color.clear
        }
    }
}

#Preview {
    SettingsView()
}
