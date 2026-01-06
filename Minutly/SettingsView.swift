//
//  SettingsView.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI
import EventKit

// Language model
struct Language: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let name: String

    static let allLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "fr", name: "French"),
        Language(code: "es", name: "Spanish"),
        Language(code: "de", name: "German"),
        Language(code: "it", name: "Italian"),
        Language(code: "pt", name: "Portuguese"),
        Language(code: "zh", name: "Chinese (Mandarin)"),
        Language(code: "ja", name: "Japanese"),
        Language(code: "ko", name: "Korean"),
        Language(code: "ar", name: "Arabic"),
        Language(code: "ru", name: "Russian"),
        Language(code: "hi", name: "Hindi"),
        Language(code: "nl", name: "Dutch"),
        Language(code: "sv", name: "Swedish"),
        Language(code: "no", name: "Norwegian"),
        Language(code: "da", name: "Danish"),
        Language(code: "fi", name: "Finnish"),
        Language(code: "pl", name: "Polish"),
        Language(code: "tr", name: "Turkish"),
        Language(code: "he", name: "Hebrew")
    ]
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("transcriptionLanguages") private var transcriptionLanguagesString: String = "en"
    @AppStorage("enableMeetingDetection") private var enableMeetingDetection = false
    @AppStorage("enableMenuBarMode") private var enableMenuBarMode = false
    @State private var showRestartAlert = false
    @State private var selectedSection: SettingsSection
    @State private var languageSearchText = ""
    @State private var selectedLanguages: [Language] = []

    // Summary settings
    @AppStorage("summaryType") private var summaryType: String = "keypoints_tasks"
    @AppStorage("customSummaryPrompt") private var customSummaryPrompt: String = ""
    @AppStorage("customSummaryInstructions") private var customSummaryInstructions: String = ""
    @AppStorage("showAdvancedPromptEditor") private var showAdvancedPromptEditor: Bool = false

    init(initialSection: SettingsSection = .general) {
        _selectedSection = State(initialValue: initialSection)
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case meetingDetection = "Meeting Detection"
        case transcription = "Transcription"
        case summary = "Summary"

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
        .onAppear {
            loadSelectedLanguages()
        }
    }

    private func loadSelectedLanguages() {
        let codes = transcriptionLanguagesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        selectedLanguages = codes.compactMap { code in
            Language.allLanguages.first(where: { $0.code == code })
        }
        // If empty, default to English
        if selectedLanguages.isEmpty {
            selectedLanguages = [Language(code: "en", name: "English")]
            saveSelectedLanguages()
        }
    }

    private func saveSelectedLanguages() {
        transcriptionLanguagesString = selectedLanguages.map { $0.code }.joined(separator: ",")
    }

    private func addLanguage(_ language: Language) {
        guard selectedLanguages.count < 10 else { return }
        guard !selectedLanguages.contains(where: { $0.code == language.code }) else { return }
        selectedLanguages.append(language)
        saveSelectedLanguages()
        languageSearchText = "" // Clear search after adding
    }

    private func removeLanguage(_ language: Language) {
        // Don't allow removing if it's the last language
        guard selectedLanguages.count > 1 else { return }
        selectedLanguages.removeAll(where: { $0.code == language.code })
        saveSelectedLanguages()
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
        case .summary:
            return "Summary"
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
                case .summary:
                    summarySection
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
                .onChange(of: enableMeetingDetection) { _, newValue in
                    if newValue {
                        handleMeetingDetectionToggle()
                    }
                }

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

    // MARK: - Calendar Permission Handling

    private func handleMeetingDetectionToggle() {
        Task {
            let granted = await requestCalendarPermission()
            if !granted {
                await MainActor.run {
                    enableMeetingDetection = false
                    showCalendarPermissionAlert()
                }
            }
        }
    }

    private func requestCalendarPermission() async -> Bool {
        let eventStore = EKEventStore()
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
        } catch {
            return false
        }
    }

    @MainActor
    private func showCalendarPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Calendar Access Required"
        alert.informativeText = "Meeting Detection requires access to your calendar to detect upcoming meetings."
        alert.alertStyle = .warning
        alert.runModal()
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription")
                .font(.title2)
                .fontWeight(.bold)

            infoBlock(
                icon: "info.circle.fill",
                color: .blue,
                title: "Apple Speech Recognition (Free & Offline)",
                description: "Uses Apple's built-in speech recognition. Works offline, completely free, and supports multiple languages. Note: Speaker identification is not available."
            )

            Divider()
                .padding(.vertical, 8)

            languageSelectionSection
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.title2)
                .fontWeight(.bold)

            infoBlock(
                icon: "cpu",
                color: .purple,
                title: "Local AI Summarization (Free & Private)",
                description: "Uses a local Llama model running entirely on your device. No cloud uploads, completely free, and fully private. The model will be downloaded on first use."
            )

            Divider()
                .padding(.vertical, 8)

            // Summary Type Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary Type")
                    .font(.headline)

                Picker("Type", selection: $summaryType) {
                    Text("Key Points + Tasks").tag("keypoints_tasks")
                    Text("Executive Summary").tag("executive")
                    Text("Technical Meeting Notes").tag("technical")
                    Text("Sales Call Summary").tag("sales")
                    Text("Custom Prompt").tag("custom")
                }
                .pickerStyle(.radioGroup)
            }

            // Custom Prompt Section (only shown when "Custom" is selected)
            if summaryType == "custom" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Instructions")
                        .font(.headline)

                    // Simple mode (default)
                    if !showAdvancedPromptEditor {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tell us what you want in your summary:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $customSummaryInstructions)
                                .font(.system(size: 14))
                                .frame(minHeight: 150)
                                .border(Color.gray.opacity(0.3), width: 1)
                                .cornerRadius(4)

                            Text("Example: \"Focus on customer feedback and next steps. Include any pricing discussions and competitive mentions.\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            if customSummaryInstructions.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Custom instructions are empty. Default 'Key Points + Tasks' will be used.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }

                        // Toggle to advanced mode
                        Button(action: { showAdvancedPromptEditor = true }) {
                            HStack {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                Text("Show advanced editor")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding(.top, 8)
                    } else {
                        // Advanced mode
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Advanced Mode: Full control over prompt template")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Text("Write your custom summary prompt below. Use {{TRANSCRIPTION}} where you want the conversation text inserted. The response must be valid JSON matching the format: {\"summary\": \"...\", \"tasks\": [...]}")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $customSummaryPrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 200)
                                .border(Color.gray.opacity(0.3), width: 1)
                                .cornerRadius(4)

                            if customSummaryPrompt.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Custom prompt is empty. Using simple instructions instead.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            // Toggle back to simple mode
                            Button(action: { showAdvancedPromptEditor = false }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                        .font(.caption)
                                    Text("Back to simple mode")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .padding(.top, 8)
                        }
                    }
                }
                .transition(.opacity)
            }

            Divider()
                .padding(.vertical, 8)

            // Summary Type Descriptions
            switch summaryType {
            case "keypoints_tasks":
                infoBlock(
                    icon: "list.bullet.clipboard",
                    color: .blue,
                    title: "Key Points + Tasks",
                    description: "Default format. Extracts main discussion points and actionable tasks with owners, deadlines, and priorities. Ideal for team meetings and project discussions."
                )
            case "executive":
                infoBlock(
                    icon: "briefcase.fill",
                    color: .purple,
                    title: "Executive Summary",
                    description: "High-level overview focused on strategic decisions, business outcomes, and leadership-relevant action items. Best for board meetings and executive reviews."
                )
            case "technical":
                infoBlock(
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: .green,
                    title: "Technical Meeting Notes",
                    description: "Detailed engineering notes covering technical decisions, architecture discussions, implementation details, and code/system changes. Optimized for development team meetings."
                )
            case "sales":
                infoBlock(
                    icon: "cart.fill",
                    color: .orange,
                    title: "Sales Call Summary",
                    description: "Sales-focused summary capturing customer needs, pain points, objections, pricing discussions, and deal progress. Perfect for sales calls and customer meetings."
                )
            case "custom":
                if showAdvancedPromptEditor {
                    infoBlock(
                        icon: "gearshape.fill",
                        color: .gray,
                        title: "Custom Prompt (Advanced)",
                        description: "Using advanced JSON prompt editor. Full control over prompt template with {{TRANSCRIPTION}} placeholder."
                    )
                } else {
                    infoBlock(
                        icon: "gearshape.fill",
                        color: .blue,
                        title: "Custom Instructions",
                        description: "Using simple custom instructions. Write what you want in plain language - we'll handle the technical details automatically."
                    )
                }
            default:
                EmptyView()
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    private var languageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Languages")
                    .font(.headline)
                Spacer()
                Text("\(selectedLanguages.count)/10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Select up to 10 languages in order of preference. The first language will be tried first.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search languages...", text: $languageSearchText)
                    .textFieldStyle(.plain)
                if !languageSearchText.isEmpty {
                    Button(action: { languageSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Selected languages tags
            if !selectedLanguages.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(selectedLanguages.enumerated()), id: \.element.id) { index, language in
                        HStack(spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text(language.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Button(action: { removeLanguage(language) }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .opacity(selectedLanguages.count > 1 ? 1 : 0.3)
                            .disabled(selectedLanguages.count <= 1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                    }
                }
            }

            // Available languages (filtered by search)
            if !languageSearchText.isEmpty || selectedLanguages.count < 10 {
                let availableLanguages = Language.allLanguages.filter { language in
                    !selectedLanguages.contains(where: { $0.code == language.code }) &&
                    (languageSearchText.isEmpty || language.name.lowercased().contains(languageSearchText.lowercased()))
                }

                if !availableLanguages.isEmpty {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(availableLanguages) { language in
                                Button(action: { addLanguage(language) }) {
                                    HStack {
                                        Text(language.name)
                                            .font(.caption)
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(6)
                                .disabled(selectedLanguages.count >= 10)
                                .opacity(selectedLanguages.count >= 10 ? 0.5 : 1)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            if selectedLanguages.count >= 10 {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Maximum 10 languages selected")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
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

// Flow Layout for wrapping tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    SettingsView()
}
