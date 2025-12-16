import SwiftUI

struct OnboardingSummarizationSetupView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var apiKeyInput: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 6) {
                Text("Summarization")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("For advanced transcription summaries, add your OpenAI API key.")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                HStack(spacing: 4) {
                    Text("Step 1")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.black)
                    + Text(" : Get your OpenAI API key from ")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(.black)
                    + Text("API Keys")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(.black)
                        .underline()

                    Spacer()
                }

                HStack(spacing: 4) {
                    Text("Step 2")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.black)
                    + Text(" : Paste your API key safely here ")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(.black)

                    Spacer()
                }

                TextField("Paste your OpenAI API key here", text: $apiKeyInput)
                    .font(.system(size: 16, weight: .regular))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0xd9d9d9))
                    .cornerRadius(16)
                    .focused($isInputFocused)
                    .textContentType(.password)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button(action: saveAPIKey) {
                Text("Save API Key")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
        if !trimmedKey.isEmpty {
            onboardingState.saveSummarizationAPIKey(trimmedKey)
        }
    }
}

#Preview {
    OnboardingSummarizationSetupView()
        .environmentObject(OnboardingState())
}
