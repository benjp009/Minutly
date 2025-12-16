import SwiftUI

struct OnboardingTranscriptionSetupView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var apiKeyInput: String = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 26) {
                // Top whitespace
                Spacer()
                    .frame(height: 30)

                // Page title
                Text("Onboarding")
                    .font(Font.custom("Arial", size: 40).weight(.bold))
                    .foregroundColor(.black)

                // Progress header and indicators - centered and 50% width
                VStack(spacing: 20) {
                    Text("Configure your app ")
                        .font(Font.custom("Arial", size: 50).weight(.bold))
                        .foregroundColor(.black)

                    // Progress indicator
                    HStack(alignment: .center, spacing: 0) {
                        // Step 1
                        VStack(spacing: 8) {
                            Circle()
                                .fill(.black)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text("1")
                                        .font(Font.custom("Arial", size: 28).weight(.bold))
                                        .foregroundColor(.white)
                                )

                            Text("Step 1")
                                .font(Font.custom("Arial", size: 12))
                                .foregroundColor(.black)
                        }

                        // Progress line 1 - Gradient from black to gray
                        VStack(alignment: .center) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.black, Color(red: 0.85, green: 0.85, blue: 0.85)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)

                        // Step 2
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text("2")
                                        .font(Font.custom("Arial", size: 28).weight(.bold))
                                        .foregroundColor(.black)
                                )

                            Text("Step 2")
                                .font(Font.custom("Arial", size: 12))
                                .foregroundColor(.black)
                        }

                        // Progress line 2 - Gray
                        VStack(alignment: .center) {
                            Rectangle()
                                .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)

                        // Step 3
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text("3")
                                        .font(Font.custom("Arial", size: 28).weight(.bold))
                                        .foregroundColor(.black)
                                )

                            Text("Step 3")
                                .font(Font.custom("Arial", size: 12))
                                .foregroundColor(.black)
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.5, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

                // Content area
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcription")
                        .font(Font.custom("Arial", size: 30).weight(.bold))
                        .foregroundColor(.black)

                    Text("For the best experience, we suggest you to add an API from AssemblyAI. ")
                        .font(Font.custom("Arial", size: 28))
                        .foregroundColor(.black)

                    Text("Step 1 : Create a new secret key here → API Keys")
                        .font(Font.custom("Arial", size: 25).weight(.bold))
                        .foregroundColor(.black)

                    Text("Step 2 : Paste your API key safely here ")
                        .font(Font.custom("Arial", size: 25).weight(.bold))
                        .foregroundColor(.black)

                    // API Key input field
                    TextField("Paste your AssemblyAI API key here", text: $apiKeyInput)
                        .font(Font.custom("Arial", size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                        .cornerRadius(16)
                }

                Spacer()

                // Navigation buttons
                Group {
                    HStack(alignment: .top, spacing: 400) {
                        // Skip button with description
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(spacing: 0) {
                                Button(action: { onboardingState.skipPage() }) {
                                    Text("Skip")
                                        .font(Font.custom("Arial", size: 30).weight(.bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 302, height: 50)
                                .background(.black)
                                .cornerRadius(16)
                            }

                            Text("Try our software with a limited free hosted AI model and limited results ")
                                .font(Font.custom("Arial", size: 12))
                                .foregroundColor(.black)
                                .padding(.top, 8)
                        }

                        // Next button
                        VStack(spacing: 0) {
                            Button(action: {
                                // Save API key when clicking Next
                                let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
                                if !trimmedKey.isEmpty {
                                    onboardingState.saveTranscriptionAPIKey(trimmedKey)
                                }
                                onboardingState.nextPage()
                            }) {
                                Text("Next")
                                    .font(Font.custom("Arial", size: 30).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 302, height: 50)
                            .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .cornerRadius(16)
                        }
                    }
                    .padding(EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0))
                    .frame(height: 107)
                }
                }
                .padding(EdgeInsets(top: 30, leading: 60, bottom: 30, trailing: 60))
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
        }
    }
}

#Preview {
    OnboardingTranscriptionSetupView()
        .environmentObject(OnboardingState())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
