import SwiftUI

struct OnboardingRecordingConfirmView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var screenRecorder: ScreenRecorder
    @State private var isTestingMic = false
    @State private var testResult: MicTestResult?

    enum MicTestResult {
        case success
        case error(String)
    }

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 6) {
                Text("Test Recording")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Let's test your microphone to ensure it works properly for recording.")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                if let result = testResult {
                    switch result {
                    case .success:
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))

                            Text("Microphone test successful! Ready to record.")
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

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Microphone test failed")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.red)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xffebee))
                        .cornerRadius(16)
                        .padding(.top, 10)
                    }
                } else {
                    Text("Click 'Test Microphone' to verify your microphone works")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button(action: testMicrophone) {
                if isTestingMic {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Testing...")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("Test Microphone")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(16)
            .disabled(isTestingMic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func testMicrophone() {
        isTestingMic = true
        testResult = nil

        Task {
            let success = await screenRecorder.testMicrophoneRecording()

            await MainActor.run {
                isTestingMic = false
                if success {
                    testResult = .success
                    onboardingState.micTestSuccessful = true
                } else {
                    testResult = .error("Microphone test failed. Please check your system audio settings.")
                }
            }
        }
    }
}

#Preview {
    OnboardingRecordingConfirmView()
        .environmentObject(OnboardingState())
        .environmentObject(ScreenRecorder())
}
