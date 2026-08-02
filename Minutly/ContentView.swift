//
//  ContentView.swift
//  Minutly

//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI
import AVFoundation
import AppKit
import Combine

struct ContentView: View {
    @EnvironmentObject var recorder: ScreenRecorder
    @State private var showSettings = false
    @State private var settingsInitialTab: SettingsView.SettingsSection = .general
    @State private var selectedRecordingURL: URL?
    @State private var showWelcome = true
    @State private var isSidebarCollapsed = false
    @State private var isRecordingsExpanded = true
    @State private var durationCache: [URL: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            mainContent
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(Theme.surfacePrimary)
        .onAppear {
            recorder.fetchRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecording)) { notification in
            if let url = notification.object as? URL {
                selectedRecordingURL = url
                showWelcome = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            settingsInitialTab = .general
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsAPI)) { _ in
            settingsInitialTab = .api
            showSettings = true
        }
        .onChange(of: recorder.recordings) { _, newList in
            guard let selected = selectedRecordingURL else { return }
            if !newList.contains(selected) {
                selectedRecordingURL = nil
                showWelcome = true
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(initialSection: settingsInitialTab)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: logo + collapse toggle
            HStack(spacing: 10) {
                if !isSidebarCollapsed {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.accentPrimary)

                    Text("Minutly")
                        .font(Theme.heading(20, weight: .bold))
                        .foregroundStyle(Theme.foregroundPrimary)

                    Spacer()
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSidebarCollapsed.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.foregroundSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: isSidebarCollapsed ? .infinity : nil)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Recordings section
            if !isSidebarCollapsed {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRecordingsExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.foregroundSecondary)

                        Text("Recordings")
                            .font(Theme.body(12, weight: .semibold))
                            .foregroundStyle(Theme.foregroundSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.foregroundMuted)
                            .rotationEffect(.degrees(isRecordingsExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isRecordingsExpanded {
                    ScrollView {
                        VStack(spacing: 2) {
                            if recorder.recordings.isEmpty {
                                Text("No recordings yet")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.foregroundMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            } else {
                                ForEach(recorder.recordings, id: \.self) { url in
                                    sidebarRecordingRow(url: url)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                }
            } else {
                Spacer()
            }

            Spacer(minLength: 0)

            // Footer: Quick Record CTA + Settings
            VStack(spacing: 12) {
                Button(action: startOrStopRecording) {
                    HStack(spacing: 8) {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "circle.fill")
                            .font(.system(size: 11, weight: .bold))

                        if !isSidebarCollapsed {
                            Text(recorder.isRecording ? "Stop Recording" : "Quick Record")
                                .font(Theme.body(13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(recorder.isRecording ? Theme.danger : Theme.accentPrimary)
                    )
                }
                .buttonStyle(.plain)

                Button { showSettings = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.foregroundSecondary)

                        if !isSidebarCollapsed {
                            Text("Settings")
                                .font(Theme.body(13))
                                .foregroundStyle(Theme.foregroundSecondary)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: isSidebarCollapsed ? .center : .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: isSidebarCollapsed ? 64 : 240)
        .background(Theme.surfaceSecondary)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.borderSubtle)
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func sidebarRecordingRow(url: URL) -> some View {
        let isSelected = selectedRecordingURL == url
        Button {
            selectedRecordingURL = url
            showWelcome = false
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Theme.accentPrimary : Theme.foregroundMuted.opacity(0.6))
                    .frame(width: 6, height: 6)

                Text(cleanName(from: url))
                    .font(Theme.body(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.foregroundPrimary : Theme.foregroundSecondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(formatDuration(for: url))
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.foregroundMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.accentSubtle : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var mainContent: some View {
        ZStack {
            Theme.surfacePrimary
                .ignoresSafeArea()

            if showWelcome {
                WelcomeView(startAction: startOrStopRecording)
                    .transition(.opacity)
            } else if let url = selectedRecordingURL {
                RecordingDetailView(
                    url: url,
                    recorder: recorder,
                    transcriptionService: recorder.transcriptionService,
                    onDelete: {
                        selectedRecordingURL = nil
                        showWelcome = recorder.recordings.isEmpty
                    }
                )
                .transition(.opacity)
            } else if recorder.recordings.isEmpty {
                WelcomeView(startAction: startOrStopRecording)
            } else {
                Text("Select a recording to view details.")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
    }

    private func startOrStopRecording() {
        Task {
            if recorder.isRecording {
                await recorder.stopRecording()
            } else {
                await recorder.startRecording()
            }
        }
    }

    private func cleanName(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func formatDuration(for url: URL) -> String {
        // Check cache first
        if let cached = durationCache[url] {
            return cached
        }

        // Calculate duration in background
        Task {
            let duration = await calculateDuration(for: url)
            await MainActor.run {
                durationCache[url] = duration
            }
        }

        return "00:00:00"
    }

    private func calculateDuration(for url: URL) async -> String {
        do {
            // Decrypt the file to get its duration
            let encryptionService = EncryptionService.shared
            let decryptedData = try encryptionService.decryptFileTemporarily(at: url)

            // Write to temporary file to read duration
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            try decryptedData.write(to: tempURL)
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            let audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            let duration = audioPlayer.duration

            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let seconds = Int(duration) % 60

            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } catch {
            return "00:00:00"
        }
    }
}


// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

private struct WelcomeView: View {
    let startAction: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.accentSubtle)
                    .frame(width: 96, height: 96)

                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Theme.accentPrimary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to Minutly")
                    .font(Theme.heading(40, weight: .bold))
                    .foregroundStyle(Theme.foregroundPrimary)

                Text("Capture your meetings, transcribe conversations, and generate summaries — all from one dashboard.")
                    .font(Theme.body(15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.foregroundSecondary)
                    .frame(maxWidth: 520)
                    .lineSpacing(2)
            }

            Button(action: startAction) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Start Recording")
                        .font(Theme.body(14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Capsule().fill(Theme.accentPrimary))
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Spacing.sm)

            HStack(spacing: 28) {
                trustBadge(icon: "lock.shield", label: "AES-256 Encryption")
                trustBadge(icon: "key", label: "Keychain Storage")
                trustBadge(icon: "eye.slash", label: "No Telemetry")
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .padding(40)
    }

    private func trustBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(Theme.body(12))
        }
        .foregroundStyle(Theme.foregroundMuted)
    }
}

private struct RecordingDetailView: View {
    let url: URL
    @ObservedObject var recorder: ScreenRecorder
    let transcriptionService: TranscriptionService
    var onDelete: () -> Void

    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackCancellable: AnyCancellable?
    @State private var currentTime: TimeInterval = 0
    @State private var playerDelegate: PlayerDelegate?
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var decryptedAudioTempURL: URL?

    @State private var selectedTab: DetailTab = .transcript
    @State private var claudePromptCopied = false
    @State private var transcriptionText: String?
    @State private var isTranscribing = false
    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionError: String?
    @State private var summary: ConversationSummary?
    @State private var isSummarizing = false
    @State private var summaryError: String?

    private enum DetailTab: String, CaseIterable, Identifiable {
        case transcript = "Transcript"
        case summary = "Summary"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            WaveformView(
                url: url,
                currentTime: currentTime,
                duration: audioPlayer?.duration ?? 0
            )
            .frame(height: 160)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            Picker("Details", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .transcript:
                    transcriptView
                case .summary:
                    summaryView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(32)
        .background(Theme.surfacePrimary)
        .onAppear {
            transcriptionText = transcriptionService.loadTranscription(for: url)
            summary = transcriptionService.loadSummary(for: url)
            editedName = cleanName(from: url)
        }
        .onChange(of: url) { _, newURL in
            stopPlayback()
            audioPlayer = nil
            transcriptionText = transcriptionService.loadTranscription(for: newURL)
            summary = transcriptionService.loadSummary(for: newURL)
            summaryError = nil
            transcriptionError = nil
            editedName = cleanName(from: newURL)
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            if isEditingName {
                TextField("Recording Name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        finishEditing()
                    }
                    .frame(maxWidth: 320)
            } else {
                Text(cleanName(from: url))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: togglePlayback) {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button {
                    isEditingName = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button(action: downloadRecording) {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)

                Button(action: revealInFinder) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)

                Button(action: askClaude) {
                    Image(systemName: claudePromptCopied ? "checkmark.circle" : "sparkles")
                        .foregroundColor(claudePromptCopied ? Theme.success : Theme.accentPrimary)
                }
                .buttonStyle(.plain)
                .disabled(!ClaudeMCP.isAvailable)
                .help("Ask Claude about this meeting — copies a prompt and opens Claude. Set up in Settings → MCP.")

                Button(role: .destructive) {
                    recorder.deleteRecording(at: url)
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
        }
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let text = transcriptionText {
                HStack {
                    Text("Transcript")
                        .font(.headline)
                    Spacer()
                    Button("Export") {
                        exportTranscription()
                    }
                    Button("Delete") {
                        deleteTranscription()
                    }
                }

                ScrollView {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
            } else if isTranscribing {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Transcribing... \(Int(transcriptionProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ProgressView(value: transcriptionProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    if !transcriptionService.statusMessage.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(transcriptionService.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No transcript yet.")
                        .font(.headline)
                    if let error = transcriptionError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack(spacing: 12) {
                        Button {
                            Task { await generateTranscription() }
                        } label: {
                            Label("Transcribe Recording", systemImage: "text.quote")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // Every transcription error is fixed in Settings, so always offer the door
                        if let error = transcriptionError {
                            Button(action: {
                                NotificationCenter.default.post(
                                    name: error.contains("API key") ? .openSettingsAPI : .openSettings,
                                    object: nil
                                )
                            }) {
                                Label("Open Settings", systemImage: "gear")
                                    .font(.headline)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = summary {
                HStack {
                    Text("Summary")
                        .font(.headline)
                    Spacer()
                    Button(action: askClaude) {
                        Label(claudePromptCopied ? "Copied — paste in Claude" : "Ask Claude",
                              systemImage: claudePromptCopied ? "checkmark" : "sparkles")
                    }
                    .disabled(!ClaudeMCP.isAvailable)
                    .help("Copies a prompt naming this meeting, then opens Claude. Claude reads the summary and transcript over MCP — set up in Settings → MCP.")
                    Button("Copy") {
                        copySummaryToClipboard(summary)
                    }
                    Button("Export") {
                        exportSummary()
                    }
                    Button("Delete") {
                        deleteSummary()
                    }
                }
                SummaryView(summary: summary, onExport: exportSummary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if isSummarizing {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Generating summary... \(Int(transcriptionService.progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ProgressView(value: transcriptionService.progress)
                        .progressViewStyle(.linear)
                        .tint(.orange)

                    if !transcriptionService.statusMessage.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(transcriptionService.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No summary yet.")
                        .font(.headline)
                    if let error = summaryError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task { await generateSummary() }
                    } label: {
                        Label("Generate AI Summary", systemImage: "sparkles")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        do {
            print("🎵 Starting playback for: \(url.lastPathComponent)")

            // Decrypt the encrypted audio file temporarily
            let encryptionService = EncryptionService.shared
            print("🔓 Decrypting audio file...")
            let decryptedData = try encryptionService.decryptFileTemporarily(at: url)
            print("✅ Decrypted \(decryptedData.count) bytes")

            // Create a temporary file to store the decrypted audio
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            print("💾 Writing decrypted audio to: \(tempURL.path)")
            try decryptedData.write(to: tempURL)
            decryptedAudioTempURL = tempURL

            print("🎧 Creating audio player...")
            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            playerDelegate = PlayerDelegate(onFinish: stopPlayback)
            audioPlayer?.delegate = playerDelegate

            print("▶️ Starting playback...")
            let success = audioPlayer?.play() ?? false
            print("Playback started: \(success)")

            if success {
                isPlaying = true

                // Use Combine timer with automatic cleanup instead of DispatchSourceTimer
                playbackCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        currentTime = audioPlayer?.currentTime ?? 0
                    }
            } else {
                print("❌ Failed to start playback")
            }
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
            print("   Error details: \(error)")
        }
    }

    private func stopPlayback() {
        // Cancel Combine timer subscription
        playbackCancellable?.cancel()
        playbackCancellable = nil

        audioPlayer?.stop()
        audioPlayer = nil
        playerDelegate = nil
        isPlaying = false
        currentTime = 0

        // Clean up temporary decrypted audio file
        if let tempURL = decryptedAudioTempURL {
            try? FileManager.default.removeItem(at: tempURL)
            decryptedAudioTempURL = nil
        }
    }

    private func finishEditing() {
        guard !editedName.isEmpty else {
            isEditingName = false
            return
        }

        recorder.renameRecording(from: url, to: editedName)
        isEditingName = false
    }

    private func downloadRecording() {
        // Ask user if they want to download encrypted or decrypted version
        let alert = NSAlert()
        alert.messageText = "Download Recording"
        alert.informativeText = "Would you like to download the encrypted file (.enc) or a decrypted WAV file?"
        alert.addButton(withTitle: "Decrypted WAV")
        alert.addButton(withTitle: "Encrypted File")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Decrypted WAV
            downloadDecryptedRecording()
        } else if response == .alertSecondButtonReturn {
            // Encrypted file
            downloadEncryptedRecording()
        }
    }

    private func downloadDecryptedRecording() {
        do {
            // Decrypt the file
            let encryptionService = EncryptionService.shared
            let decryptedData = try encryptionService.decryptFileTemporarily(at: url)

            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".wav"
            savePanel.allowedContentTypes = [.wav]

            savePanel.begin { response in
                if response == .OK, let destinationURL = savePanel.url {
                    do {
                        try decryptedData.write(to: destinationURL)
                        print("✅ Decrypted recording saved to: \(destinationURL.path)")
                    } catch {
                        print("❌ Failed to save decrypted file: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Failed to decrypt file: \(error)")
            let errorAlert = NSAlert()
            errorAlert.messageText = "Decryption Failed"
            errorAlert.informativeText = "Could not decrypt the recording: \(error.localizedDescription)"
            errorAlert.runModal()
        }
    }

    private func downloadEncryptedRecording() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.allowedContentTypes = [.data]  // .enc files are encrypted data

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    print("✅ Encrypted recording saved to: \(destinationURL.path)")
                } catch {
                    print("❌ Failed to save file: \(error)")
                }
            }
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func deleteTranscription() {
        try? transcriptionService.deleteTranscription(for: url)
        transcriptionText = nil
    }

    private func deleteSummary() {
        // ponytail: no confirmation alert — the summary is regenerable from the
        // transcript in one click. Add one if regeneration ever costs real money.
        try? transcriptionService.deleteSummary(for: url)
        summary = nil
        summaryError = nil
    }

    private func exportTranscription() {
        guard let text = transcriptionText else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(cleanName(from: url))_transcription.txt"
        savePanel.allowedContentTypes = [.plainText]

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    try text.write(to: destinationURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export transcription: \(error)")
                }
            }
        }
    }

    private func exportSummary() {
        guard let summary = summary else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(cleanName(from: url))_summary.txt"
        savePanel.allowedContentTypes = [.plainText]

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    let text = summary.formattedText()
                    try text.write(to: destinationURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export summary: \(error)")
                }
            }
        }
    }

    private func askClaude() {
        ClaudeMCP.ask(about: url.deletingPathExtension().lastPathComponent)
        claudePromptCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { claudePromptCopied = false }
    }

    private func copySummaryToClipboard(_ summary: ConversationSummary) {
        let text = summary.formattedText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func generateTranscription() async {
        await MainActor.run {
            isTranscribing = true
            transcriptionProgress = 0.0
            transcriptionError = nil
        }

        do {
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    transcriptionProgress = transcriptionService.progress
                }
            }

            let text = try await transcriptionService.transcribe(audioURL: url)

            await MainActor.run {
                progressTimer.invalidate()
                transcriptionText = text
                transcriptionProgress = 1.0
            }

            _ = try transcriptionService.saveTranscription(text, for: url)
        } catch {
            await MainActor.run {
                transcriptionError = error.localizedDescription
            }
        }

        await MainActor.run {
            isTranscribing = false
        }
    }

    private func generateSummary() async {
        guard let transcription = transcriptionText ?? transcriptionService.loadTranscription(for: url) else {
            summaryError = "Transcription required before generating a summary."
            selectedTab = .transcript
            return
        }

        await MainActor.run {
            isSummarizing = true
            summaryError = nil
        }

        do {
            let result = try await transcriptionService.summarize(transcription: transcription)
            await MainActor.run {
                summary = result
            }
            do {
                _ = try transcriptionService.saveSummary(result, for: url)
            } catch {
                print("Failed to save summary: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                summaryError = error.localizedDescription
            }
        }

        await MainActor.run {
            isSummarizing = false
        }
    }

    private func cleanName(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

private extension URL {
    var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}


#Preview {
    ContentView()
        .environmentObject(ScreenRecorder())
}
