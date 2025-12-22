import SwiftUI

struct OnboardingSummarizationSetupView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var apiKeyInput: String = ""

    // Computed property to check if Next button should be enabled
    private var isNextEnabled: Bool {
        !apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Top whitespace
                    Spacer()
                        .frame(height: max(20, geometry.size.height * 0.03))

                    // Progress header and indicators - centered and 50% width
                    VStack(spacing: 16) {
                        Text("Configure your app ")
                            .font(Font.custom("Arial", size: min(50, geometry.size.height * 0.08)).weight(.bold))
                            .foregroundColor(.black)

                        // Progress indicator
                        ZStack(alignment: .center) {
                            // Background progress lines layer
                            HStack(spacing: 0) {
                                // Line 1 - Black
                                Rectangle()
                                    .fill(.black)
                                    .frame(height: 8)

                                // Line 2 - Gradient from black to gray
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

                            // Circles layer on top
                            HStack(spacing: 0) {
                                // Step 1 - Black (completed)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("1")
                                            .font(Font.custom("Arial", size: 28).weight(.bold))
                                            .foregroundColor(.white)
                                    )

                                Spacer()

                                // Step 2 - Black (current)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("2")
                                            .font(Font.custom("Arial", size: 28).weight(.bold))
                                            .foregroundColor(.white)
                                    )

                                Spacer()

                                // Step 3 - Gray (inactive)
                                Circle()
                                    .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("3")
                                            .font(Font.custom("Arial", size: 28).weight(.bold))
                                            .foregroundColor(.black)
                                    )
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.5, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))

                    // Content area
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summarization")
                            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                            .foregroundColor(.black)

                        Text("For the best experience, we suggest you to add an API from OpenAI. ")
                            .font(Font.custom("Arial", size: min(28, geometry.size.height * 0.044)))
                            .foregroundColor(.black)

                        HStack(spacing: 4) {
                            Text("Step 1 : Create a new secret key here → ")
                                .font(Font.custom("Arial", size: min(25, geometry.size.height * 0.04)).weight(.bold))
                                .foregroundColor(.black)

                            Button(action: {
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Text("API Keys")
                                    .font(Font.custom("Arial", size: min(25, geometry.size.height * 0.04)).weight(.bold))
                                    .foregroundColor(.black)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Step 2 : Paste your API key safely here ")
                            .font(Font.custom("Arial", size: min(25, geometry.size.height * 0.04)).weight(.bold))
                            .foregroundColor(.black)

                        // API Key input field - masked
                        SecureField("Paste your OpenAI API key here", text: $apiKeyInput)
                            .font(Font.custom("Arial", size: 16))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .cornerRadius(16)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))

                    // Navigation buttons
                    HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
                        // Skip button
                        Button(action: { onboardingState.skipPage() }) {
                            Text("Skip")
                                .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .frame(width: min(302, geometry.size.width * 0.25), height: 50)
                        .background(.black)
                        .cornerRadius(16)

                        // Next button - Black when enabled, Grey when disabled
                        Button(action: {
                            // Save API key when clicking Next
                            let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
                            if !trimmedKey.isEmpty {
                                onboardingState.saveSummarizationAPIKey(trimmedKey)
                                onboardingState.nextPage()
                            }
                        }) {
                            Text("Next")
                                .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .frame(width: min(302, geometry.size.width * 0.25), height: 50)
                        .background(isNextEnabled ? Color.black : Color(red: 0.85, green: 0.85, blue: 0.85))
                        .cornerRadius(16)
                        .disabled(!isNextEnabled)
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
        }
    }
}

#Preview {
    OnboardingSummarizationSetupView()
        .environmentObject(OnboardingState())
}

