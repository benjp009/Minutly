//
//  RecordingRow.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct RecordingRow: View {
    let url: URL
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let transcriptionService: TranscriptionService

    @State private var isPlaying = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    @State private var currentTime: TimeInterval = 0
    @State private var showTranscription = false
    @State private var transcriptionText: String?
    @State private var isTranscribing = false
    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionError: String?
    @State private var playerDelegate: PlayerDelegate?
    @State private var showSummary = false
    @State private var summary: ConversationSummary?
    @State private var isSummarizing = false
    @State private var summaryError: String?
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Name or Edit Field
                if isEditingName {
                    TextField("Recording Name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            finishEditing()
                        }
                    
                    Button(action: finishEditing) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(cleanName(from: url))
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    Button(action: {
                        editedName = cleanName(from: url)
                        isEditingName = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Play/Pause Button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                // Transcription Button
                Button(action: toggleTranscription) {
                    if isTranscribing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: transcriptionService.transcriptionExists(for: url) ? "doc.text.fill" : "doc.text")
                            .foregroundStyle(transcriptionService.transcriptionExists(for: url) ? .purple : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTranscribing)
                .help("Transcribe audio")

                // Summary Button
                Button(action: toggleSummary) {
                    if isSummarizing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: summary != nil ? "sparkles" : "sparkles")
                            .foregroundStyle(summary != nil ? .orange : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSummarizing || transcriptionText == nil)
                .help("Generate AI summary")

                // Download Button
                Button(action: downloadRecording) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            
            if isPlaying {
                WaveformView(
                    url: url,
                    currentTime: currentTime,
                    duration: audioPlayer?.duration ?? 0
                )
                .frame(height: 40)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Transcription view
            if showTranscription {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Transcription")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Action buttons for transcription
                        if transcriptionText != nil {
                            // Delete transcription button
                            Button(action: deleteTranscription) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete transcription and transcribe again")

                            // Export transcription button
                            Button(action: exportTranscription) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Export transcription")
                        }
                    }

                    if let text = transcriptionText {
                        ScrollView {
                            Text(text)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 150)
                        .padding(8)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(6)
                    } else if isTranscribing {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                Text("Transcribing... \(Int(transcriptionProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !transcriptionService.statusMessage.isEmpty {
                                Text(transcriptionService.statusMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: transcriptionProgress)
                                .progressViewStyle(.linear)
                        }
                        .padding(8)
                    } else if let error = transcriptionError {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Transcription Failed")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }

                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button("Retry") {
                                Task {
                                    await generateTranscription()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Summary view
            if showSummary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Summary")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Export summary button
                        if summary != nil {
                            Button(action: exportSummary) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Export summary")
                        }
                    }

                    if let summary = summary {
                        SummaryView(summary: summary, onExport: exportSummary)
                            .frame(maxHeight: 400)
                    } else if isSummarizing {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                Text("Generating summary...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !transcriptionService.statusMessage.isEmpty {
                                Text(transcriptionService.statusMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: transcriptionService.progress)
                                .progressViewStyle(.linear)
                        }
                        .padding(8)
                    } else if let error = summaryError {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Summary Failed")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }

                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button("Retry") {
                                Task {
                                    await generateSummary()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onDisappear {
            stopPlayback()
        }
        .onAppear {
            // Load existing transcription if available
            transcriptionText = transcriptionService.loadTranscription(for: url)
        }
    }
    
    private func finishEditing() {
        if !editedName.isEmpty {
            onRename(editedName)
        }
        isEditingName = false
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

            // Keep a strong reference to the delegate
            playerDelegate = PlayerDelegate(onFinish: {
                stopPlayback()
            })
            audioPlayer?.delegate = playerDelegate

            audioPlayer?.play()
            isPlaying = true
            currentTime = 0

            // Start timer to update current time
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
                if let player = audioPlayer {
                    currentTime = player.currentTime
                }
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
    
    private func cleanName(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    private func downloadRecording() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.allowedContentTypes = [.wav]

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Copy file to selected location
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
        }
    }

    private func toggleTranscription() {
        withAnimation {
            showTranscription.toggle()
        }

        // If opening and no transcription exists, generate one
        if showTranscription && transcriptionText == nil && !isTranscribing {
            Task {
                await generateTranscription()
            }
        }
    }

    private func generateTranscription() async {
        // Ensure we're on main thread
        await MainActor.run {
            isTranscribing = true
            transcriptionProgress = 0.0
            transcriptionError = nil
        }

        do {
            print("🎬 Starting transcription for: \(url.lastPathComponent)")

            // Start a timer to update progress from the service
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
                Task { @MainActor in
                    self.transcriptionProgress = self.transcriptionService.progress
                }
            }

            let text = try await transcriptionService.transcribe(audioURL: url)

            // Stop the timer
            await MainActor.run {
                timer.invalidate()
            }

            print("✅ Transcription completed successfully")

            await MainActor.run {
                transcriptionText = text
                transcriptionProgress = 1.0
            }

            // Save transcription to file
            _ = try transcriptionService.saveTranscription(text, for: url)
            print("✅ Transcription saved to file")

        } catch {
            print("❌ Transcription error: \(error.localizedDescription)")
            await MainActor.run {
                transcriptionError = error.localizedDescription
            }
        }

        await MainActor.run {
            isTranscribing = false
        }
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

    private func deleteTranscription() {
        // Delete the saved transcription file
        do {
            try transcriptionService.deleteTranscription(for: url)
            print("✅ Transcription deleted for: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete transcription: \(error)")
        }

        // Clear the UI state
        transcriptionText = nil
        transcriptionError = nil
        transcriptionProgress = 0.0

        // Wait a bit before starting new transcription to ensure state is clean
        Task {
            // Small delay to ensure UI is updated
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await generateTranscription()
        }
    }

    private func toggleSummary() {
        withAnimation {
            showSummary.toggle()
        }

        // If opening and no summary exists, generate one
        if showSummary && summary == nil && !isSummarizing {
            Task {
                await generateSummary()
            }
        }
    }

    private func generateSummary() async {
        guard let transcription = transcriptionText, !transcription.isEmpty else {
            summaryError = "No transcription available. Please transcribe the audio first."
            return
        }

        await MainActor.run {
            isSummarizing = true
            summaryError = nil
        }

        do {
            print("🤖 Starting summarization...")
            let result = try await transcriptionService.summarize(transcription: transcription)
            print("✅ Summarization complete: \(result.tasks.count) tasks found")

            await MainActor.run {
                summary = result
            }
        } catch {
            print("❌ Summarization error: \(error.localizedDescription)")
            await MainActor.run {
                summaryError = error.localizedDescription
            }
        }

        await MainActor.run {
            isSummarizing = false
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
                    print("✅ Summary exported to: \(destinationURL.path)")
                } catch {
                    print("Failed to export summary: \(error)")
                }
            }
        }
    }
}

// Helper delegate to handle playback finish
class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
