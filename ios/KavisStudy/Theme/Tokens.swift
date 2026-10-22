import SwiftUI

// Colors copied from web/src/theme/tokens.css (which comes from design/DeskApp.dc.html).
// Every token has a light and a dark value and follows the system / chosen appearance.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color that switches with light / dark mode.
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    static func pair(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(light: Color(hex: light), dark: Color(hex: dark))
    }
}

enum KColor {
    // Surfaces
    static let bg = Color.pair(0xF4EFE6, 0x15120F)
    static let side = Color.pair(0xEDE3D2, 0x1A1612)
    static let card = Color.pair(0xFFFCF6, 0x211C18)
    static let sub = Color.pair(0xF1EBE0, 0x2B2520)
    static let line = Color.pair(0xE6DDCF, 0x3A322B)
    static let paper = Color.pair(0xFBF6EC, 0x211C18)
    static let seg = Color.pair(0xE8DEC9, 0x2B2520)
    static let pill = Color.pair(0xFFFCF6, 0x463C33)
    static let chrome = Color.pair(0xE8DFD0, 0x2B2520)

    // Text
    static let text = Color.pair(0x2A2420, 0xEFE8DC)
    static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
    static let text3 = Color.pair(0x8C8073, 0x9A8F82)
    static let ink = Color.pair(0x2A2420, 0xEFE8DC)
    static let inv = Color.pair(0x2A2420, 0xEFE8DC)
    static let onInv = Color.pair(0xFFFCF6, 0x15120F)

    // Brand: bordo and amber
    static let pri = Color(hex: 0x9C2F3A)
    static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
    static let priSoft = Color.pair(0xF5E3E2, 0x3A2027)
    static let amb = Color(hex: 0xF2B33D)
    static let ambSoft = Color.pair(0xFBEBC8, 0x3A2E18)
    static let ambText = Color.pair(0x7A5208, 0xF2C66D)
    static let ambLine = Color.pair(0xE8C77E, 0x6B5426)
    static let compBorder = Color.pair(0xF2D9A8, 0x4A3A1C)
    /// Primary button background / foreground.
    static let pb = Color.pair(0x9C2F3A, 0xF2B33D)
    static let pf = Color.pair(0xFFF6E6, 0x241C14)

    // Status
    static let good = Color.pair(0x2E7D4F, 0x8FBF7A)
    static let goodSoft = Color.pair(0xE3F1E7, 0x22301F)
    static let vio = Color.pair(0x4A3F9A, 0xB9B4F0)
    static let vioSoft = Color.pair(0xE8E6F6, 0x2C2A3A)
    static let bad = Color.pair(0xC0352B, 0xF27A70)
    static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
    static let badLine = Color.pair(0xF0C9C5, 0x5A2A2A)
    static let badButton = Color.pair(0xC0352B, 0xB23A47)
    static let tealSoft = Color.pair(0xDFF0F1, 0x1C2A2C)
    static let tealText = Color.pair(0x1F6E75, 0x8CCFD6)

    // Reading page
    static let tag = Color.pair(0xF5E3E2, 0x3A2224)
    static let tagText = Color.pair(0x9C2F3A, 0xF09AA3)
    static let term = Color.pair(0x9C2F3A, 0xE8925A)
    static let termBg = Color(light: Color(hex: 0xF2B33D, opacity: 0.28), dark: Color(hex: 0xF2B33D, opacity: 0.16))
}

/// Gradients from the design (CSS angles: 135deg = top-leading to bottom-trailing, 0deg = bottom to top).
enum KGradient {
    static let hero = LinearGradient(
        colors: [Color.pair(0xFBE9BD, 0x4A3A1C), Color.pair(0xF5C76A, 0x6B4A1A)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Light: 0% F5C76A, 32% F8D68C, 62% FBE9BD, 100% F4EFE6. Dark: 0% 4A3A1C, 45% 2B2117, 100% 15120F
    // (the dark middle values below sit on that same line at 32% and 62%).
    static let login = LinearGradient(
        stops: [
            .init(color: Color.pair(0xF5C76A, 0x4A3A1C), location: 0),
            .init(color: Color.pair(0xF8D68C, 0x342818), location: 0.32),
            .init(color: Color.pair(0xFBE9BD, 0x241C15), location: 0.62),
            .init(color: Color.pair(0xF4EFE6, 0x15120F), location: 1),
        ],
        startPoint: .bottom, endPoint: .top
    )

    static let landing = LinearGradient(
        colors: [Color.pair(0xF4EFE6, 0x15120F), Color.pair(0xFBE9BD, 0x2B2117)],
        startPoint: .top, endPoint: .bottom
    )
}

/// Text on top of the hero gradient.
extension KColor {
    static let onHero = Color.pair(0x2A2420, 0xFBEFD6)
    static let heroButton = Color.pair(0xFFFCF6, 0xFBEFD6)
}

enum KRadius {
    /// Cards use 22–30 (CLAUDE.md).
    static let card: CGFloat = 24
    static let big: CGFloat = 30
    static let small: CGFloat = 16
}
