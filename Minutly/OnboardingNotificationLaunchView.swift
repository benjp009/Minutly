import SwiftUI
import UserNotifications

struct OnboardingNotificationLaunchView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 6) {
                Text("Notifications")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Enable notifications to get alerts about your recording status and important updates.")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)

                    Text("Notifications help you stay informed about your recordings")
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
            if notificationPermissionStatus == .authorized {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))

                    Text("Notifications enabled!")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.green)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: 0xe8f5e9))
                .cornerRadius(16)
            } else if notificationPermissionStatus == .denied {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))

                    Text("Notifications disabled. You can enable them in System Settings.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.orange)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: 0xfff3e0))
                .cornerRadius(16)
            }

            VStack(spacing: 12) {
                Button(action: requestNotificationPermission) {
                    if isRequestingPermission {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Requesting...")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Text(notificationPermissionStatus == .authorized ? "Enabled" : "Enable Notifications")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(16)
                .disabled(isRequestingPermission || notificationPermissionStatus == .authorized)

                Text("You can change this anytime in System Settings")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            checkNotificationPermission()
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        isRequestingPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                checkNotificationPermission()
            }
        }
    }
}

#Preview {
    OnboardingNotificationLaunchView()
        .environmentObject(OnboardingState())
}
