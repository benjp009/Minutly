//
//  SplashScreenView.swift
//  Minutly
//
//  Created by Claude Code on 04/12/2025.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Theme.surfacePrimary
                .ignoresSafeArea()

            // Subtle accent glow behind the wordmark
            Circle()
                .fill(Theme.accentPrimary)
                .frame(width: 360, height: 360)
                .blur(radius: 140)
                .opacity(isAnimating ? 0.35 : 0.0)
                .animation(.easeOut(duration: 0.9), value: isAnimating)

            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: 14) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.accentPrimary)

                    Text("Minutly")
                        .font(Theme.heading(72, weight: .bold))
                        .foregroundStyle(Theme.foregroundPrimary)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.92)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isAnimating)

                Text("Your meetings, captured and understood.")
                    .font(Theme.body(20))
                    .foregroundStyle(Theme.foregroundSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimating)
            }
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    SplashScreenView()
        .frame(width: 1000, height: 650)
}
