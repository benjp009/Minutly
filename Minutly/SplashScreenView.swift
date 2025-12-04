//
//  SplashScreenView.swift
//  Minutly
//
//  Created by Claude Code on 04/12/2025.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            // White background to match HTML design
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Minutly Logo
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)

                Spacer()
                    .frame(height: 40)

                // Welcome to Minutly - Main heading (50px)
                Text("Welcome to Minutly")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimating)

                // Tagline (30px)
                Text("Where your meetings become your superpower")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimating)

                Spacer()
            }
            .opacity(fadeOut ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.5), value: fadeOut)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
}
