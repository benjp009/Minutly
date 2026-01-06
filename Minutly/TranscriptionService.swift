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
    private let llamaService = LocalLlamaSummarizationService.shared
    private let encryptionService = EncryptionService.shared
    private let auditLogger = AuditLogger.shared

    init() {
        // Initialize recognizer based on language preference
        recognizer = Self.createRecognizer()
        print("✅ Apple Speech Recognition initialized (local, free)")
    }


    // Summarize transcription with local Llama
    func summarize(
        transcription: String,
        summaryType: String? = nil,
        customPrompt: String? = nil,
        customInstructions: String? = nil
    ) async throws -> ConversationSummary {
        return try await llamaService.summarize(
            transcription: transcription,
            summaryType: summaryType,
            customPrompt: customPrompt,
            customInstructions: customInstructions
        ) { progressValue, status in
            DispatchQueue.main.async {
                self.progress = progressValue
                self.statusMessage = status
            }
        }
    }

    // Get contextual strings based on language to improve recognition accuracy
    private func getContextualStrings(for languageCode: String?) -> [String] {
        guard let code = languageCode else { return [] }

        switch code {
        case "fr":
            return ["réunion", "projet", "discussion", "équipe", "client", "objectif", "action", "priorité"]
        case "en":
            return ["meeting", "project", "discussion", "team", "client", "objective", "action", "priority"]
        case "es":
            return ["reunión", "proyecto", "discusión", "equipo", "cliente", "objetivo", "acción", "prioridad"]
        case "de":
            return ["Besprechung", "Projekt", "Diskussion", "Team", "Kunde", "Ziel", "Aktion", "Priorität"]
        case "it":
            return ["riunione", "progetto", "discussione", "team", "cliente", "obiettivo", "azione", "priorità"]
        case "pt":
            return ["reunião", "projeto", "discussão", "equipe", "cliente", "objetivo", "ação", "prioridade"]
        default:
            return []
        }
    }

    // Create recognizer based on language preference (uses first language in list)
    private static func createRecognizer() -> SFSpeechRecognizer? {
        let languagesString = UserDefaults.standard.string(forKey: "transcriptionLanguages") ?? "en"
        let languageCodes = languagesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let languageCode = languageCodes.first ?? "en"

        return createRecognizerForLanguage(languageCode)
    }

    // Create recognizer for specific language code
    private static func createRecognizerForLanguage(_ languageCode: String) -> SFSpeechRecognizer? {
        let localeIdentifier: String
        switch languageCode {
        case "en":
            localeIdentifier = "en-US"
        case "fr":
            localeIdentifier = "fr-FR"
        case "es":
            localeIdentifier = "es-ES"
        case "de":
            localeIdentifier = "de-DE"
        case "it":
            localeIdentifier = "it-IT"
        case "pt":
            localeIdentifier = "pt-BR"
        case "zh":
            localeIdentifier = "zh-CN"
        case "ja":
            localeIdentifier = "ja-JP"
        case "ko":
            localeIdentifier = "ko-KR"
        case "ar":
            localeIdentifier = "ar-SA"
        case "ru":
            localeIdentifier = "ru-RU"
        case "hi":
            localeIdentifier = "hi-IN"
        case "nl":
            localeIdentifier = "nl-NL"
        case "sv":
            localeIdentifier = "sv-SE"
        case "no":
            localeIdentifier = "no-NO"
        case "da":
            localeIdentifier = "da-DK"
        case "fi":
            localeIdentifier = "fi-FI"
        case "pl":
            localeIdentifier = "pl-PL"
        case "tr":
            localeIdentifier = "tr-TR"
        case "he":
            localeIdentifier = "he-IL"
        default:
            localeIdentifier = Locale.current.identifier
        }

        if let specificRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
            print("✅ Using \(localeIdentifier) speech recognizer for language: \(languageCode)")
            return specificRecognizer
        } else {
            print("⚠️ \(localeIdentifier) not available, using default locale")
            return SFSpeechRecognizer()
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

    // Main transcribe method - uses Apple Speech Recognition only
    func transcribe(audioURL: URL, languageCode: String? = nil) async throws -> String {
        // Decrypt the audio file if it's encrypted
        let actualAudioURL: URL
        if audioURL.pathExtension.lowercased() == "enc" {
            print("🔓 Decrypting audio file for transcription...")
            do {
                let decryptedData = try encryptionService.decryptAudioFile(at: audioURL)
                // Create a temporary decrypted file
                let tempDir = FileManager.default.temporaryDirectory
                let decryptedFileName = audioURL.deletingPathExtension().lastPathComponent + "_decrypted.wav"
                let decryptedURL = tempDir.appendingPathComponent(decryptedFileName)
                try decryptedData.write(to: decryptedURL)
                actualAudioURL = decryptedURL
                print("✅ Audio file decrypted for transcription")
            } catch {
                print("❌ Failed to decrypt audio file: \(error.localizedDescription)")
                throw TranscriptionError.encryptionError(error.localizedDescription)
            }
        } else {
            actualAudioURL = audioURL
        }

        do {
            // Always use Apple Speech Recognition (free, local, no API key needed)
            let result = try await transcribeWithApple(audioURL: actualAudioURL, languageCode: languageCode)

            // Clean up temporary decrypted file
            if actualAudioURL != audioURL {
                try? FileManager.default.removeItem(at: actualAudioURL)
            }

            return result
        } catch {
            // Clean up temporary decrypted file on error
            if actualAudioURL != audioURL {
                try? FileManager.default.removeItem(at: actualAudioURL)
            }
            throw error
        }
    }


    // Transcribe with Apple Speech
    private func transcribeWithApple(audioURL: URL, languageCode: String? = nil) async throws -> String {
        print("🎙️ Starting transcription for: \(audioURL.lastPathComponent)")

        // CRITICAL: Recreate recognizer to respect current language settings
        // Language may have changed since app launch
        recognizer = Self.createRecognizer()
        print("🔄 Refreshed speech recognizer with current language settings")

        // Override language if specified by user
        if let languageCode = languageCode {
            recognizer = Self.createRecognizerForLanguage(languageCode)
            print("🌍 Using user-selected language: \(languageCode)")
        }

        // Check authorization
        print("🔐 Requesting speech recognition authorization...")
        await MainActor.run {
            self.statusMessage = "🔐 Checking permissions..."
        }
        let authorized = await requestAuthorization()
        guard authorized else {
            print("❌ Speech recognition not authorized")
            throw TranscriptionError.notAuthorized
        }
        print("✅ Authorization granted")
        await MainActor.run {
            self.statusMessage = "✅ Permission granted"
        }

        // Check if recognizer is available
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available - check internet connection")
            throw TranscriptionError.recognizerUnavailable
        }
        print("✅ Speech recognizer available for \(recognizer.locale.identifier)")

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

            await MainActor.run {
                self.statusMessage = "📂 Loading audio file..."
            }

            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true

            // CRITICAL: Use cloud-based recognition for best accuracy
            // On-device recognition has very poor quality and limited language support
            request.requiresOnDeviceRecognition = false

            // Add language-appropriate context strings to improve recognition
            let languageCode: String?
            if #available(macOS 13, *) {
                languageCode = recognizer.locale.language.languageCode?.identifier
            } else {
                languageCode = recognizer.locale.languageCode
            }
            let contextStrings = getContextualStrings(for: languageCode)
            if !contextStrings.isEmpty {
                request.contextualStrings = contextStrings
                print("📝 Added \(contextStrings.count) contextual hints for \(recognizer.locale.identifier)")
            }

            // Task hint for dictation (better for conversations)
            if #available(macOS 13.0, *) {
                request.taskHint = .dictation
            }

            print("📝 Recognition request created with \(recognizer.locale.identifier) locale")
            print("ℹ️  Using cloud-based recognition for best accuracy (requires internet)")
            print("ℹ️  Note: Speaker separation (diarization) not available in Apple Speech Recognition")

            // Get audio duration for better progress tracking
            let audioAsset = AVURLAsset(url: audioURL)
            let duration = try await audioAsset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            print("🎵 Audio duration: \(Int(durationSeconds)) seconds")

            await MainActor.run {
                self.statusMessage = "🎙️ Starting Apple Speech recognition..."
            }

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
                                self.statusMessage = "✅ Transcription complete!"
                                print("✅ Transcription complete: \(wordCount) words")
                            } else {
                                // Better progress calculation based on audio duration
                                // Estimate ~2 words per second for speech
                                let estimatedTotalWords = max(durationSeconds * 2, Double(wordCount))
                                self.progress = min(0.95, Double(wordCount) / estimatedTotalWords)
                                self.statusMessage = "🔄 Transcribing... \(wordCount) words recognized"
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

    // Save transcription to file (encrypted)
    func saveTranscription(_ text: String, for audioURL: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }

        // Create transcription filename based on audio filename
        let audioName = audioURL.deletingPathExtension().lastPathComponent
        let transcriptionFileName = "\(audioName)_transcription.txt"
        let transcriptionURL = documentsURL.appendingPathComponent(transcriptionFileName)

        // Write transcription to file (plaintext - contains extracted text, not sensitive audio)
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
    case encryptionError(String)

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
        case .encryptionError(let message):
            return "Failed to decrypt audio file: \(message)"
        }
    }
}
