import SwiftUI
import AVFoundation
import UserNotifications

struct OnboardingPermissionsView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var screenRecorder: ScreenRecorder
    @State private var screenRecordingGranted = false
    @State private var notificationGranted = false

    private var isLaunchEnabled: Bool {
        screenRecordingGranted && notificationGranted
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

                        // Progress indicator - All steps completed
                        ZStack(alignment: .center) {
                            // Background progress lines layer - all black
                            HStack(spacing: 0) {
                                // Line 1 - Black
                                Rectangle()
                                    .fill(.black)
                                    .frame(height: 8)

                                // Line 2 - Black
                                Rectangle()
                                    .fill(.black)
                                    .frame(height: 8)
                            }

                            // Circles layer on top - all black
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

                                // Step 2 - Black (completed)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("2")
                                            .font(Font.custom("Arial", size: 28).weight(.bold))
                                            .foregroundColor(.white)
                                    )

                                Spacer()

                                // Step 3 - Black (current)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("3")
                                            .font(Font.custom("Arial", size: 28).weight(.bold))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.5, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))

                    // Content area
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Give permissions")
                            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                            .foregroundColor(.black)

                        Text("We need you to give permissions to your computer to use the app")
                            .font(Font.custom("Arial", size: min(28, geometry.size.height * 0.044)))
                            .foregroundColor(.black)

                        // Screen recording permission
                        HStack {
                            Text("Allow Minutly to record the content of your screen and audio")
                                .font(Font.custom("Arial", size: min(20, geometry.size.height * 0.032)))
                                .foregroundColor(.black)

                            Spacer()

                            Button(action: requestScreenRecordingPermission) {
                                Text("Allow")
                                    .font(Font.custom("Arial", size: min(20, geometry.size.height * 0.032)).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 150, height: 40)
                            .background(screenRecordingGranted ? .black : Color(red: 0.85, green: 0.85, blue: 0.85))
                            .cornerRadius(8)
                        }
                        .padding(.top, 10)

                        // Notification permission
                        HStack {
                            Text("Allow Minutly to send you notifications to remind you when a meeting starts")
                                .font(Font.custom("Arial", size: min(20, geometry.size.height * 0.032)))
                                .foregroundColor(.black)

                            Spacer()

                            Button(action: requestNotificationPermission) {
                                Text("Allow")
                                    .font(Font.custom("Arial", size: min(20, geometry.size.height * 0.032)).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 150, height: 40)
                            .background(notificationGranted ? .black : Color(red: 0.85, green: 0.85, blue: 0.85))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))

                    Spacer()
                        .frame(minHeight: 20)

                    // Navigation buttons
                    HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
                        // Previous button
                        Button(action: { onboardingState.previousPage() }) {
                            Text("Previous")
                                .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .frame(width: min(302, geometry.size.width * 0.25), height: 50)
                        .background(.black)
                        .cornerRadius(16)

                        // Launch button - Green when enabled, Grey when disabled
                        Button(action: {
                            onboardingState.completeOnboarding()
                        }) {
                            Text("Launch")
                                .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .frame(width: min(302, geometry.size.width * 0.25), height: 50)
                        .background(isLaunchEnabled ? Color.green : Color(red: 0.85, green: 0.85, blue: 0.85))
                        .cornerRadius(16)
                        .disabled(!isLaunchEnabled)
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, max(20, geometry.size.height * 0.03))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check screen recording permission (approximate check)
        // Note: There's no direct API to check screen recording permission on macOS
        // We'll assume it's granted if user has used the app before

        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    private func requestScreenRecordingPermission() {
        // Request screen recording permission by attempting to start recording
        // This will trigger the system permission dialog if not already granted
        Task {
            // Trigger permission request - on macOS, we need to attempt to capture to trigger the dialog
            // The system will automatically show the permission prompt
            await screenRecorder.startRecording(meetingTitle: nil)

            // Wait a moment and then stop
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await screenRecorder.stopRecording()

            // Mark as granted (assume user granted it)
            await MainActor.run {
                screenRecordingGranted = true
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                notificationGranted = granted
                if let error = error {
                    print("❌ Error requesting notification permission: \(error)")
                }
            }
        }
    }
}

#Preview {
    OnboardingPermissionsView()
        .environmentObject(OnboardingState())
        .environmentObject(ScreenRecorder())
}
