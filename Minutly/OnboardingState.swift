import Foundation
import SwiftUI
import Combine

class OnboardingState: ObservableObject {
    @AppStorage("onboardingCompleted") var onboardingCompleted = false
    @AppStorage("currentOnboardingPage") var currentPage = 1
    @AppStorage("transcriptionAPIConfigured") var transcriptionAPIConfigured = false
    @AppStorage("summarizationAPIConfigured") var summarizationAPIConfigured = false

    @Published var transcriptionAPIKey: String = ""
    @Published var summarizationAPIKey: String = ""

    // Validation/confirmation states
    @Published var isValidatingTranscriptionAPI = false
    @Published var transcriptionAPIValidationError: String?
    @Published var transcriptionAPIValidated = false

    @Published var isValidatingSummarizationAPI = false
    @Published var summarizationAPIValidationError: String?
    @Published var summarizationAPIValidated = false

    @Published var isPerformingMicTest = false
    @Published var micTestError: String?
    @Published var micTestSuccessful = false

    init() {
        // Load API keys from Keychain if they exist
        do {
            if let savedTranscriptionKey = try KeychainService.shared.retrieveAPIKey(for: "assemblyai") {
                self.transcriptionAPIKey = savedTranscriptionKey
            }
            if let savedSummarizationKey = try KeychainService.shared.retrieveAPIKey(for: "openai") {
                self.summarizationAPIKey = savedSummarizationKey
            }
        } catch {
            print("⚠️ Error loading API keys from Keychain: \(error)")
        }
    }

    func nextPage() {
        if currentPage < 3 {
            currentPage += 1
            resetPageState()
        }
    }

    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            resetPageState()
        }
    }

    func skipPage() {
        nextPage()
    }

    func completeOnboarding() {
        onboardingCompleted = true
    }

    private func resetPageState() {
        transcriptionAPIValidationError = nil
        transcriptionAPIValidated = false
        isValidatingTranscriptionAPI = false

        summarizationAPIValidationError = nil
        summarizationAPIValidated = false
        isValidatingSummarizationAPI = false

        micTestError = nil
        micTestSuccessful = false
        isPerformingMicTest = false
    }

    // MARK: - API Key Management

    func saveTranscriptionAPIKey(_ key: String) {
        transcriptionAPIKey = key
        do {
            try KeychainService.shared.saveAPIKey(key, for: "assemblyai")
            transcriptionAPIConfigured = true
        } catch {
            print("⚠️ Error saving transcription API key: \(error)")
        }
    }

    func saveSummarizationAPIKey(_ key: String) {
        summarizationAPIKey = key
        do {
            try KeychainService.shared.saveAPIKey(key, for: "openai")
            summarizationAPIConfigured = true
        } catch {
            print("⚠️ Error saving summarization API key: \(error)")
        }
    }

    func clearTranscriptionAPIKey() {
        transcriptionAPIKey = ""
        do {
            try KeychainService.shared.deleteAPIKey(for: "assemblyai")
            transcriptionAPIConfigured = false
            transcriptionAPIValidated = false
        } catch {
            print("⚠️ Error clearing transcription API key: \(error)")
        }
    }

    func clearSummarizationAPIKey() {
        summarizationAPIKey = ""
        do {
            try KeychainService.shared.deleteAPIKey(for: "openai")
            summarizationAPIConfigured = false
            summarizationAPIValidated = false
        } catch {
            print("⚠️ Error clearing summarization API key: \(error)")
        }
    }
}
