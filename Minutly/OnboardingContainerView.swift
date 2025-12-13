import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var onboardingState = OnboardingState()
    @EnvironmentObject var screenRecorder: ScreenRecorder

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator at top
                progressIndicator
                    .padding(.top, 30)
                    .padding(.bottom, 26)

                // Current page content
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // Navigation buttons at bottom
                navigationButtons
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 60)
        }
        .environmentObject(onboardingState)
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 14) {
            Text("Configure your app ")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { pageNum in
                    VStack(spacing: 0) {
                        // Number text
                        Text("\(pageNum)")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(pageNum == onboardingState.currentPage ? .black : .gray)

                        // Progress bar
                        if pageNum < 7 {
                            HStack(spacing: 0) {
                                if pageNum < onboardingState.currentPage {
                                    // Completed - black line
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 8)
                                } else if pageNum == onboardingState.currentPage {
                                    // Current - gradient from black to gray
                                    LinearGradient(
                                        gradient: Gradient(colors: [.black, Color(hex: 0xd9d9d9)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(height: 8)
                                } else {
                                    // Not yet - gray line
                                    Rectangle()
                                        .fill(Color(hex: 0xd9d9d9))
                                        .frame(height: 8)
                                }
                            }
                            .padding(.top, 9)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Page Content
    @ViewBuilder
    private var pageContent: some View {
        switch onboardingState.currentPage {
        case 1:
            OnboardingTranscriptionSetupView()
        case 2:
            OnboardingTranscriptionConfirmView()
        case 3:
            OnboardingSummarizationSetupView()
        case 4:
            OnboardingSummarizationConfirmView()
        case 5:
            OnboardingPermissionsView()
        case 6:
            OnboardingRecordingConfirmView()
        case 7:
            OnboardingNotificationLaunchView()
        default:
            Text("Unknown page")
        }
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            // Back button (only show on page 2+)
            if onboardingState.currentPage > 1 {
                Button(action: { onboardingState.previousPage() }) {
                    Text("Back")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 302, height: 50)
                        .background(Color.black)
                        .cornerRadius(16)
                }
                .padding(.trailing, 40)
            }

            Spacer()

            VStack(spacing: 8) {
                // Skip button
                Button(action: { onboardingState.skipPage() }) {
                    VStack(spacing: 4) {
                        Text("Skip")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Try our software with a limited free hosted AI model and limited results ")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 302, height: 50)
                    .background(Color.black)
                    .cornerRadius(16)
                }

                // Next button
                Button(action: {
                    if onboardingState.currentPage == 7 {
                        onboardingState.completeOnboarding()
                    } else {
                        onboardingState.nextPage()
                    }
                }) {
                    Text(onboardingState.currentPage == 7 ? "Launch" : "Next")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 302, height: 50)
                        .background(Color(hex: 0xd9d9d9))
                        .cornerRadius(16)
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(ScreenRecorder())
}
