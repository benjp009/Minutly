//
//  ContentView.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI
import AVFoundation
import EventKit
import AppKit

struct ContentView: View {
    @EnvironmentObject var recorder: ScreenRecorder
    @StateObject private var calendarMonitor = CalendarMonitorService()
    @State private var showSettings = false
    @State private var showMeetingAlert = false
    @State private var detectedMeeting: String = ""
    @State private var selectedRecordingURL: URL?
    @State private var showWelcome = true
    @AppStorage("enableMeetingDetection") private var enableMeetingDetection = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainContent
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(Color.white)
        .onAppear {
            recorder.fetchRecordings()

            calendarMonitor.onMeetingDetected = { meeting in
                Task { @MainActor in
                    let meetingTitle = meeting.title ?? "Untitled Meeting"
                    detectedMeeting = meetingTitle
                    showMeetingAlert = true
                    await recorder.startPreBuffering(meetingTitle: meetingTitle)
                }
            }

            calendarMonitor.setupNotificationActions()

            if enableMeetingDetection {
                Task {
                    await calendarMonitor.startMonitoring()
                }
            }
        }
        .onDisappear {
            calendarMonitor.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecording)) { notification in
            if let url = notification.object as? URL {
                selectedRecordingURL = url
                showWelcome = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
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
            SettingsView()
        }
        .alert("Meeting Starting", isPresented: $showMeetingAlert) {
            Button("Start Recording") {
                Task {
                    await recorder.confirmRecordingFromPreBuffer()
                }
            }
            Button("Ignore", role: .cancel) {
                Task {
                    await recorder.cancelPreBuffer()
                }
            }
        } message: {
            Text("\(detectedMeeting)\n\nThe last 30 seconds will be included in the recording.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Minutly")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(recorder.isRecording ? "Recording..." : "Ready to record")
                    .font(.headline)
                    .foregroundStyle(recorder.isRecording ? .red : .secondary)
                if recorder.isRecording {
                    Text("System audio capture active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if recorder.isPreBuffering {
                    Text("Pre-buffering last 30 seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: startOrStopRecording) {
                Label(
                    recorder.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: recorder.isRecording ? "stop.circle.fill" : "circle.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(recorder.isRecording ? Color.red : Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recordings")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                if recorder.recordings.isEmpty {
                    Text("No recordings yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(recorder.recordings, id: \.self) { url in
                                Button {
                                    selectedRecordingURL = url
                                    showWelcome = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cleanName(from: url))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text(url.formattedCreationDate)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedRecordingURL == url ? Color.accentColor.opacity(0.15) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: sidebarWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var mainContent: some View {
        ZStack {
            Color.white
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
                    .font(.headline)
                    .foregroundStyle(.secondary)
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

    private var sidebarWidth: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        return max(220, screenWidth * 0.25)
    }
}

private struct WelcomeView: View {
    let startAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "record.waveform")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Welcome to Minutly")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Capture your meetings, transcribe conversations, and generate summaries from one dashboard.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 480)
            }

            Button(action: startAction) {
                Label("Start Recording", systemImage: "circle.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }
}

private struct RecordingDetailView: View {
    let url: URL
    @ObservedObject var recorder: ScreenRecorder
    let transcriptionService: TranscriptionService
    var onDelete: () -> Void

    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    @State private var currentTime: TimeInterval = 0
    @State private var playerDelegate: PlayerDelegate?
    @State private var isEditingName = false
    @State private var editedName = ""

    @State private var selectedTab: DetailTab = .transcript
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
        .background(Color.white)
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
                    ProgressView(value: transcriptionProgress)
                    Text("Transcribing... Please wait.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                    Button("Copy") {
                        copySummaryToClipboard(summary)
                    }
                    Button("Export") {
                        exportSummary()
                    }
                }
                SummaryView(summary: summary, onExport: exportSummary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if isSummarizing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playerDelegate = PlayerDelegate(onFinish: stopPlayback)
            audioPlayer?.delegate = playerDelegate
            audioPlayer?.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                currentTime = audioPlayer?.currentTime ?? 0
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        playerDelegate = nil
        isPlaying = false
        currentTime = 0
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
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.allowedContentTypes = [.wav]

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                } catch {
                    print("Failed to save file: \(error)")
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
