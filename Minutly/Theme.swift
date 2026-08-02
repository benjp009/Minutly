//
//  Theme.swift
//  Minutly
//
//  Design tokens mirrored from the Penpot source. Colors auto-adapt to the
//  system appearance so the app feels native in both light and dark mode.
//

import SwiftUI
import AppKit

enum Theme {

    // MARK: Surfaces

    static let surfacePrimary = dynamic(dark: 0x0A0A0A, light: 0xFFFFFF)
    static let surfaceSecondary = dynamic(dark: 0x1A1A1A, light: 0xF4F4F5)
    static let surfaceTertiary = dynamic(dark: 0x262626, light: 0xE4E4E7)
    static let surfaceInverse = dynamic(dark: 0xFFFFFF, light: 0x0A0A0A)

    // MARK: Foreground

    static let foregroundPrimary = dynamic(dark: 0xFFFFFF, light: 0x09090B)
    static let foregroundSecondary = dynamic(dark: 0xA1A1AA, light: 0x52525B)
    static let foregroundMuted = dynamic(dark: 0x71717A, light: 0x71717A)
    static let foregroundInverse = dynamic(dark: 0x0A0A0A, light: 0xFFFFFF)

    // MARK: Accent (purple)

    static let accentPrimary = dynamic(dark: 0xA855F7, light: 0x9333EA)
    static let accentSubtle = dynamic(dark: 0xA855F7, light: 0xA855F7, alphaDark: 0.10, alphaLight: 0.10)

    // MARK: Borders

    static let borderPrimary = dynamic(dark: 0x2A2A2A, light: 0xE4E4E7)
    static let borderSubtle = dynamic(dark: 0x1F1F1F, light: 0xF4F4F5)

    // MARK: Semantic

    static let success = dynamic(dark: 0x22C55E, light: 0x16A34A)
    static let successSubtle = dynamic(dark: 0x22C55E, light: 0x22C55E, alphaDark: 0.10, alphaLight: 0.10)
    static let warning = dynamic(dark: 0xF59E0B, light: 0xD97706)
    static let danger = dynamic(dark: 0xEF4444, light: 0xDC2626)

    // MARK: Typography

    /// The design specifies "Inter"; we use the system font on macOS so the
    /// app inherits Apple's metrics and remains accessible without bundling
    /// fonts. Switch to `Font.custom("Inter", size:)` if Inter is later
    /// added to the bundle.
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Radii / spacing

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 9999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Helpers

    private static func dynamic(dark: UInt32, light: UInt32,
                                alphaDark: CGFloat = 1.0,
                                alphaLight: CGFloat = 1.0) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) == .darkAqua
                || appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) == .vibrantDark
            return isDark
                ? nsColor(hex: dark, alpha: alphaDark)
                : nsColor(hex: light, alpha: alphaLight)
        })
    }

    private static func nsColor(hex: UInt32, alpha: CGFloat) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
