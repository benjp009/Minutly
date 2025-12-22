import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var onboardingState = OnboardingState()
    @EnvironmentObject var screenRecorder: ScreenRecorder

    var body: some View {
        // Simple wrapper - each page manages its own layout
        pageContent
            .environmentObject(onboardingState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Page Content
    @ViewBuilder
    private var pageContent: some View {
        switch onboardingState.currentPage {
        case 1:
            OnboardingTranscriptionSetupView()
        case 2:
            OnboardingSummarizationSetupView()
        case 3:
            OnboardingPermissionsView()
        default:
            Text("Unknown page")
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
