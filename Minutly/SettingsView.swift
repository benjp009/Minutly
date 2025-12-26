//
//  SettingsView.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI

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
    @State private var assemblyAIKey: String = ""
    @State private var openAIKey: String = ""
    @AppStorage("transcriptionProvider") private var transcriptionProvider: String = "apple"
    @AppStorage("transcriptionLanguages") private var transcriptionLanguagesString: String = "en"
    @AppStorage("enableMeetingDetection") private var enableMeetingDetection = false
    @AppStorage("enableMenuBarMode") private var enableMenuBarMode = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showRestartAlert = false
    @State private var showOnboardingResetAlert = false
    @State private var selectedSection: SettingsSection
    @State private var loadingKeys = true
    @State private var languageSearchText = ""
    @State private var selectedLanguages: [Language] = []

    init(initialSection: SettingsSection = .general) {
        _selectedSection = State(initialValue: initialSection)
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
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
        .alert("Restart Onboarding", isPresented: $showOnboardingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart", role: .destructive) {
                // Close settings first
                dismiss()
                // Small delay to let UI update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resetOnboarding()
                }
            }
        } message: {
            Text("This will restart the onboarding process and show you the first onboarding screen.")
        }
        .onAppear {
            loadKeysFromKeychain()
            loadSelectedLanguages()
        }
    }

    private func loadKeysFromKeychain() {
        do {
            if let key = try KeychainService.shared.retrieveAPIKey(for: "assemblyai") {
                assemblyAIKey = key
            }
            if let key = try KeychainService.shared.retrieveAPIKey(for: "openai") {
                openAIKey = key
            }
        } catch {
            print("⚠️ Error loading API keys from Keychain: \(error.localizedDescription)")
        }
        loadingKeys = false
    }

    private func saveKeysToKeychain() {
        do {
            if !assemblyAIKey.isEmpty {
                try KeychainService.shared.saveAPIKey(assemblyAIKey, for: "assemblyai")
            } else {
                // Delete key from Keychain if field is empty
                try KeychainService.shared.deleteAPIKey(for: "assemblyai")
            }
            if !openAIKey.isEmpty {
                try KeychainService.shared.saveAPIKey(openAIKey, for: "openai")
            } else {
                // Delete key from Keychain if field is empty
                try KeychainService.shared.deleteAPIKey(for: "openai")
            }
        } catch {
            print("❌ Error saving API keys to Keychain: \(error.localizedDescription)")
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

    private func resetOnboarding() {
        // Reset onboarding state - this will immediately show the onboarding screen
        onboardingCompleted = false
        UserDefaults.standard.set(1, forKey: "currentOnboardingPage")

        // The onboarding will now show automatically because onboardingCompleted is false
        // No need to close the app - the UI will update immediately
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

            Divider()
                .padding(.vertical, 8)

            // Restart Onboarding Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.blue)
                    Text("Restart Onboarding")
                        .font(.headline)
                }

                Text("Start the onboarding process again to reconfigure your API keys and permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: {
                    showOnboardingResetAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Restart Onboarding")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
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

            Divider()
                .padding(.vertical, 8)

            languageSelectionSection

            Divider()
                .padding(.vertical, 8)

            comparisonSection

            Divider()
                .padding(.vertical, 8)

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

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("API Settings")
                .font(.title2)
                .fontWeight(.bold)

            assemblySection
            Divider()
            openAISection
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
                .onChange(of: assemblyAIKey) { _, _ in
                    saveKeysToKeychain()
                }

            if assemblyAIKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    infoBlock(
                        icon: "key.fill",
                        color: .orange,
                        title: "API Key Required",
                        description: "To use AssemblyAI, sign up on assemblyai.com, get $50 in credits (~200 hours), and paste your key above."
                    )
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://www.assemblyai.com/dashboard/api-keys")!)
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
                .onChange(of: openAIKey) { _, _ in
                    saveKeysToKeychain()
                }

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
                FeatureRow(feature: "Cost", apple: "Free", assemblyAI: "$0.25-0.37/hour", openAI: "$0.006/min (~$0.36/hour)")
                FeatureRow(feature: "Speaker Identification", apple: "No", assemblyAI: "Yes", openAI: "No")
                FeatureRow(feature: "Language Support", apple: "Limited", assemblyAI: "99+ languages", openAI: "99+ languages")
                FeatureRow(feature: "Offline", apple: "Yes", assemblyAI: "No (requires internet)", openAI: "No (requires internet)")
                FeatureRow(feature: "Accuracy", apple: "Good", assemblyAI: "Excellent", openAI: "Excellent")
                FeatureRow(feature: "Processing Speed", apple: "Real-time", assemblyAI: "~25% of audio length", openAI: "Fast")
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
    let openAI: String

    var body: some View {
        HStack(spacing: 8) {
            Text(feature)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(apple)
                    .font(.caption)
            }
            .frame(width: 100, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("AssemblyAI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(assemblyAI)
                    .font(.caption)
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("OpenAI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(openAI)
                    .font(.caption)
            }
            .frame(width: 120, alignment: .leading)
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
