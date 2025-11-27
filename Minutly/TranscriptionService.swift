//
//  TranscriptionService.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import Foundation
@preconcurrency import Speech
import AVFoundation

class TranscriptionService {
    var isTranscribing = false
    var progress: Double = 0.0
    var errorMessage: String?
    var statusMessage: String = ""

    private var recognizer: SFSpeechRecognizer?
    private var assemblyAIService: AssemblyAIService?
    private var openAIService: OpenAISummarizationService?
    private var openAITranscriptionService: OpenAITranscriptionService?

    init() {
        // Initialize with French locale
        // Try French (France) first, fallback to user's locale
        if let frenchRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")) {
            recognizer = frenchRecognizer
            print("✅ Using French (France) speech recognizer")
        } else if let frenchCanadaRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-CA")) {
            recognizer = frenchCanadaRecognizer
            print("✅ Using French (Canada) speech recognizer")
        } else {
            recognizer = SFSpeechRecognizer()
            print("⚠️ Using default locale speech recognizer")
        }

        // Initialize AssemblyAI if API key is available
        if let apiKey = UserDefaults.standard.string(forKey: "assemblyAI_APIKey"), !apiKey.isEmpty {
            assemblyAIService = AssemblyAIService(apiKey: apiKey)
            print("✅ AssemblyAI service initialized")
        }

        // Initialize OpenAI if API key is available
        if let apiKey = UserDefaults.standard.string(forKey: "openAI_APIKey"), !apiKey.isEmpty {
            openAIService = OpenAISummarizationService(apiKey: apiKey)
            openAITranscriptionService = OpenAITranscriptionService(apiKey: apiKey)
            print("✅ OpenAI service initialized")
        }
    }

    // Update AssemblyAI API key
    func updateAssemblyAIKey(_ key: String) {
        if !key.isEmpty {
            if assemblyAIService == nil {
                assemblyAIService = AssemblyAIService(apiKey: key)
            } else {
                assemblyAIService?.updateAPIKey(key)
            }
            print("✅ AssemblyAI API key updated")
        }
    }

    // Update OpenAI API key
    func updateOpenAIKey(_ key: String) {
        if !key.isEmpty {
            if openAIService == nil {
                openAIService = OpenAISummarizationService(apiKey: key)
            } else {
                openAIService?.updateAPIKey(key)
            }
            if openAITranscriptionService == nil {
                openAITranscriptionService = OpenAITranscriptionService(apiKey: key)
            } else {
                openAITranscriptionService?.updateAPIKey(key)
            }
            print("✅ OpenAI API key updated")
        }
    }

    // Summarize transcription
    func summarize(transcription: String) async throws -> ConversationSummary {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAI_APIKey"), !apiKey.isEmpty else {
            throw TranscriptionError.openAIKeyMissing
        }

        if openAIService == nil {
            openAIService = OpenAISummarizationService(apiKey: apiKey)
        }

        guard let service = openAIService else {
            throw TranscriptionError.openAIKeyMissing
        }

        return try await service.summarize(transcription: transcription) { progressValue, status in
            DispatchQueue.main.async {
                self.progress = progressValue
                self.statusMessage = status
            }
        }
    }

    // Request speech recognition authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // Main transcribe method - chooses provider based on settings
    func transcribe(audioURL: URL) async throws -> String {
        let provider = UserDefaults.standard.string(forKey: "transcriptionProvider") ?? "apple"

        if provider == "assemblyai" {
            return try await transcribeWithAssemblyAI(audioURL: audioURL)
        } else if provider == "openai" {
            return try await transcribeWithOpenAI(audioURL: audioURL)
        } else {
            return try await transcribeWithApple(audioURL: audioURL)
        }
    }

    // Transcribe with AssemblyAI
    private func transcribeWithAssemblyAI(audioURL: URL) async throws -> String {
        print("🎙️ Using AssemblyAI for transcription")

        // Check if API key is configured
        guard let apiKey = UserDefaults.standard.string(forKey: "assemblyAI_APIKey"), !apiKey.isEmpty else {
            throw TranscriptionError.assemblyAIKeyMissing
        }

        // Ensure service is initialized
        if assemblyAIService == nil {
            assemblyAIService = AssemblyAIService(apiKey: apiKey)
        }

        guard let service = assemblyAIService else {
            throw TranscriptionError.assemblyAIKeyMissing
        }

        isTranscribing = true
        progress = 0.0
        errorMessage = nil

        defer {
            isTranscribing = false
        }

        do {
            let transcript = try await service.transcribe(audioURL: audioURL, languageCode: "fr") { [weak self] progressValue, status in
                DispatchQueue.main.async {
                    self?.progress = progressValue
                    self?.statusMessage = status
                    print("📊 AssemblyAI Progress: \(Int(progressValue * 100))% - \(status)")
                }
            }

            // Return formatted transcript with speaker labels
            return transcript.formattedTranscript()

        } catch {
            print("❌ AssemblyAI transcription failed: \(error.localizedDescription)")
            errorMessage = "AssemblyAI failed: \(error.localizedDescription)"
            throw error
        }
    }

    private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
        print("🎙️ Using OpenAI Whisper for transcription")

        guard let apiKey = UserDefaults.standard.string(forKey: "openAI_APIKey"), !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        if openAITranscriptionService == nil {
            openAITranscriptionService = OpenAITranscriptionService(apiKey: apiKey)
        }

        guard let service = openAITranscriptionService else {
            throw OpenAIError.invalidAPIKey
        }

        isTranscribing = true
        progress = 0.0
        errorMessage = nil

        defer { isTranscribing = false }

        do {
            let transcript = try await service.transcribe(audioURL: audioURL, languageCode: "fr") { [weak self] progressValue, status in
                DispatchQueue.main.async {
                    self?.progress = progressValue
                    self?.statusMessage = status
                    print("📊 OpenAI Progress: \(Int(progressValue * 100))% - \(status)")
                }
            }
            return transcript
        } catch {
            print("❌ OpenAI transcription failed: \(error.localizedDescription)")
            errorMessage = "OpenAI failed: \(error.localizedDescription)"
            throw error
        }
    }

    // Transcribe with Apple Speech
    private func transcribeWithApple(audioURL: URL) async throws -> String {
        print("🎙️ Starting transcription for: \(audioURL.lastPathComponent)")

        // Check authorization
        print("🔐 Requesting speech recognition authorization...")
        let authorized = await requestAuthorization()
        guard authorized else {
            print("❌ Speech recognition not authorized")
            throw TranscriptionError.notAuthorized
        }
        print("✅ Authorization granted")

        // Check if recognizer is available
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            throw TranscriptionError.recognizerUnavailable
        }
        print("✅ Speech recognizer available")

        isTranscribing = true
        progress = 0.0
        errorMessage = nil

        defer {
            isTranscribing = false
            progress = 1.0
        }

        do {
            // Check if audio file exists and is readable
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                print("❌ Audio file not found at: \(audioURL.path)")
                throw TranscriptionError.fileNotFound
            }
            print("✅ Audio file exists")

            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false // Use cloud for better accuracy if available

            // Add context strings to improve recognition for meetings/conversations
            request.contextualStrings = ["réunion", "projet", "discussion", "équipe", "client"]

            // Task hint for dictation (better for conversations)
            if #available(macOS 13.0, *) {
                request.taskHint = .dictation
            }

            print("📝 Recognition request created with French language support")
            print("ℹ️  Note: Apple Speech Framework does not support speaker separation (diarization)")
            print("ℹ️  All speakers will be transcribed as a single continuous text")

            // Get audio duration for better progress tracking
            let audioAsset = AVURLAsset(url: audioURL)
            let duration = try await audioAsset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            print("🎵 Audio duration: \(Int(durationSeconds)) seconds")

            // Perform recognition with timeout
            let transcription = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var finalTranscription = ""
                var hasResumed = false
                var lastUpdateTime = Date()

                // Store task in a class wrapper to make it Sendable
                final class TaskWrapper: @unchecked Sendable {
                    var task: SFSpeechRecognitionTask?
                }
                let taskWrapper = TaskWrapper()

                // Timeout if no updates for 10 seconds and we have partial results
                let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { timer in
                    let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
                    if timeSinceLastUpdate > 10.0 && !finalTranscription.isEmpty && !hasResumed {
                        print("⏱️ Timeout reached - returning partial transcription")
                        timer.invalidate()
                        taskWrapper.task?.finish()
                        hasResumed = true
                        continuation.resume(returning: finalTranscription)
                    }
                }

                print("🎬 Starting recognition task...")
                taskWrapper.task = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        print("❌ Recognition error: \(error.localizedDescription)")
                        timeoutTimer.invalidate()

                        // If we have partial results, return them instead of erroring
                        if !finalTranscription.isEmpty && !hasResumed {
                            print("⚠️ Returning partial transcription due to error")
                            hasResumed = true
                            continuation.resume(returning: finalTranscription)
                        } else if !hasResumed {
                            hasResumed = true
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    if let result = result {
                        finalTranscription = result.bestTranscription.formattedString
                        let wordCount = result.bestTranscription.segments.count
                        lastUpdateTime = Date()

                        // Update progress based on partial results
                        DispatchQueue.main.async {
                            if result.isFinal {
                                self.progress = 1.0
                                print("✅ Transcription complete: \(wordCount) words")
                            } else {
                                // Better progress calculation based on audio duration
                                // Estimate ~2 words per second for speech
                                let estimatedTotalWords = max(durationSeconds * 2, Double(wordCount))
                                self.progress = min(0.95, Double(wordCount) / estimatedTotalWords)
                                print("📊 Progress: \(Int(self.progress * 100))% - \(wordCount) words so far (estimated total: \(Int(estimatedTotalWords)))")
                            }
                        }

                        if result.isFinal {
                            timeoutTimer.invalidate()
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: finalTranscription)
                            }
                        }
                    }
                }
            }

            print("✅ Transcription successful: \(transcription.prefix(100))...")
            return transcription

        } catch {
            print("❌ Transcription failed: \(error.localizedDescription)")
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            throw error
        }
    }

    // Save transcription to file
    func saveTranscription(_ text: String, for audioURL: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }

        // Create transcription filename based on audio filename
        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let transcriptionFileName = "\(audioName)_transcription.txt"
        let transcriptionURL = documentsURL.appendingPathComponent(transcriptionFileName)

        // Write transcription to file
        try text.write(to: transcriptionURL, atomically: true, encoding: .utf8)

        return transcriptionURL
    }

    // Load existing transcription if available
    func loadTranscription(for audioURL: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let transcriptionFileName = "\(audioName)_transcription.txt"
        let transcriptionURL = documentsURL.appendingPathComponent(transcriptionFileName)

        return try? String(contentsOf: transcriptionURL, encoding: .utf8)
    }

    // Check if transcription exists
    func transcriptionExists(for audioURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let transcriptionFileName = "\(audioName)_transcription.txt"
        let transcriptionURL = documentsURL.appendingPathComponent(transcriptionFileName)

        return fileManager.fileExists(atPath: transcriptionURL.path)
    }

    // Delete transcription file
    func deleteTranscription(for audioURL: URL) throws {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let transcriptionFileName = "\(audioName)_transcription.txt"
        let transcriptionURL = documentsURL.appendingPathComponent(transcriptionFileName)

        if fileManager.fileExists(atPath: transcriptionURL.path) {
            try fileManager.removeItem(at: transcriptionURL)
        }
    }

    // MARK: - Summary Persistence

    func saveSummary(_ summary: ConversationSummary, for audioURL: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let summaryFileName = "\(audioName)_summary.json"
        let summaryURL = documentsURL.appendingPathComponent(summaryFileName)

        let data = try JSONEncoder().encode(summary)
        try data.write(to: summaryURL)
        return summaryURL
    }

    func loadSummary(for audioURL: URL) -> ConversationSummary? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let summaryFileName = "\(audioName)_summary.json"
        let summaryURL = documentsURL.appendingPathComponent(summaryFileName)

        guard fileManager.fileExists(atPath: summaryURL.path),
              let data = try? Data(contentsOf: summaryURL) else {
            return nil
        }

        return try? JSONDecoder().decode(ConversationSummary.self, from: data)
    }

    func summaryExists(for audioURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let summaryFileName = "\(audioName)_summary.json"
        let summaryURL = documentsURL.appendingPathComponent(summaryFileName)

        return fileManager.fileExists(atPath: summaryURL.path)
    }

    func deleteSummary(for audioURL: URL) throws {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let summaryFileName = "\(audioName)_summary.json"
        let summaryURL = documentsURL.appendingPathComponent(summaryFileName)

        if fileManager.fileExists(atPath: summaryURL.path) {
            try fileManager.removeItem(at: summaryURL)
        }
    }
}

// MARK: - Errors
enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case saveFailed
    case fileNotFound
    case assemblyAIKeyMissing
    case openAIKeyMissing

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in System Settings > Privacy & Security > Speech Recognition."
        case .recognizerUnavailable:
            return "Speech recognizer is not available. Please check your internet connection and try again."
        case .saveFailed:
            return "Failed to save transcription file."
        case .fileNotFound:
            return "Audio file not found. Please make sure the recording exists."
        case .assemblyAIKeyMissing:
            return "AssemblyAI API key not configured. Please add your API key in Settings."
        case .openAIKeyMissing:
            return "OpenAI API key not configured. Please add your API key in Settings to enable summarization."
        }
    }
}
