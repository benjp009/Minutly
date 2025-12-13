import SwiftUI

struct OnboardingTranscriptionConfirmView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var isTestingAPI = false
    @State private var testResult: APITestResult?

    enum APITestResult {
        case success
        case error(String)
    }

    var body: some View {
        VStack(spacing: 26) {
            // Content section
            VStack(spacing: 6) {
                // Transcription heading
                Text("Transcription")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Description
                Text("Let's verify your AssemblyAI API key works correctly. ")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                // Status message
                if let result = testResult {
                    switch result {
                    case .success:
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))

                            Text("Your AssemblyAI API key is valid!")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.green)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xe8f5e9))
                        .cornerRadius(16)
                        .padding(.top, 10)

                    case .error(let errorMessage):
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 20))

                            Text(errorMessage)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.red)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xffebee))
                        .cornerRadius(16)
                        .padding(.top, 10)
                    }
                } else if !onboardingState.transcriptionAPIKey.isEmpty {
                    Text("Click 'Test API' to verify your key")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Test API button
            if !onboardingState.transcriptionAPIKey.isEmpty {
                Button(action: testAPIKey) {
                    if isTestingAPI {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Testing...")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Text("Test API")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(16)
                .disabled(isTestingAPI)
            } else {
                Text("No API key configured")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func testAPIKey() {
        isTestingAPI = true
        testResult = nil

        Task {
            do {
                // Try to validate the API key
                let isValid = try await AssemblyAIService.validateAPIKey(onboardingState.transcriptionAPIKey)

                await MainActor.run {
                    isTestingAPI = false
                    if isValid {
                        testResult = .success
                        onboardingState.transcriptionAPIValidated = true
                    } else {
                        testResult = .error("API key validation failed")
                    }
                }
            } catch {
                await MainActor.run {
                    isTestingAPI = false
                    testResult = .error(error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    OnboardingTranscriptionConfirmView()
        .environmentObject(OnboardingState())
}
