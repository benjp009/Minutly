import SwiftUI
import AVFoundation

struct OnboardingPermissionsView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var screenRecorder: ScreenRecorder
    @State private var microphonePermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 6) {
                Text("Microphone Permission")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("To record audio from your meetings, we need access to your microphone.")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)

                    Text("Microphone access allows us to record your meeting audio")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: 0xf5f5f5))
                .cornerRadius(16)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Permission status
            if microphonePermissionStatus == .authorized {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))

                    Text("Microphone permission granted!")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.green)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: 0xe8f5e9))
                .cornerRadius(16)
            } else if microphonePermissionStatus == .denied {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))

                    Text("Microphone permission denied. Please enable in System Settings.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.red)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: 0xffebee))
                .cornerRadius(16)
            }

            Button(action: requestMicrophonePermission) {
                if isRequestingPermission {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Requesting...")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(microphonePermissionStatus == .authorized ? "Permission Granted" : "Grant Permission")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(16)
            .disabled(isRequestingPermission || microphonePermissionStatus == .authorized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            checkMicrophonePermission()
        }
    }

    private func checkMicrophonePermission() {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionStatus = status
        #endif
    }

    private func requestMicrophonePermission() {
        isRequestingPermission = true

        #if os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                isRequestingPermission = false
                checkMicrophonePermission()
            }
        }
        #endif
    }
}

#Preview {
    OnboardingPermissionsView()
        .environmentObject(OnboardingState())
        .environmentObject(ScreenRecorder())
}
