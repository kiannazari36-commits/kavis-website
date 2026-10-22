import SwiftUI

/// Colors and gradients that the phone screens (design/New*.dc.html) use. They are close to `KColor`
/// but a few values differ slightly in the phone design, so the screens follow the phone files.
enum KPhone {
    private static func stops(_ light: [(UInt32, CGFloat)], _ dark: [(UInt32, CGFloat)]) -> [Gradient.Stop] {
        // Both appearances share the same stop positions, so the gradient switches smoothly with the theme.
        zip(light, dark).map { .init(color: Color.pair($0.0, $1.0), location: $0.1) }
    }

    /// Splash: 0deg (bottom to top).
    static let splashBg = LinearGradient(
        stops: stops(
            [(0xF5C76A, 0), (0xF8D68C, 0.32), (0xFBE9BD, 0.62), (0xF4EFE6, 1)],
            [(0x4A3A1C, 0), (0x2E2317, 0.32), (0x1C1712, 0.62), (0x15120F, 1)]
        ),
        startPoint: .bottom, endPoint: .top
    )

    /// Welcome: 0deg, the light end is at 80%.
    static let welcomeBg = LinearGradient(
        stops: stops(
            [(0xF5C76A, 0), (0xF8D68C, 0.30), (0xFBE9BD, 0.58), (0xF4EFE6, 0.80), (0xF4EFE6, 1)],
            [(0x4A3A1C, 0), (0x2F2518, 0.30), (0x1E1812, 0.58), (0x15120F, 0.80), (0x15120F, 1)]
        ),
        startPoint: .bottom, endPoint: .top
    )

    /// Sign up / log in: light is a soft vertical fade, dark is a glow from the top.
    static let authBg = Color.pair(0xF4EFE6, 0x15120F)
    static let authTop = Color.pair(0xF7EEDD, 0x3A2A1E)

    /// Home: top is a little darker than the page.
    static let homeBg = LinearGradient(
        stops: stops([(0xEDE3D2, 0), (0xF4EFE6, 0.4), (0xF4EFE6, 1)], [(0x1F1A16, 0), (0x15120F, 0.45), (0x15120F, 1)]),
        startPoint: .top, endPoint: .bottom
    )

    static let card = Color.pair(0xFFFCF6, 0x211C18)
    static let sub = Color.pair(0xF1EBE0, 0x2B2520)
    static let seg = Color.pair(0xEAE1D2, 0x2B2520)
    static let line = Color.pair(0xE6DDCF, 0x3A322B)
    static let text = Color.pair(0x2A2420, 0xEFE8DC)
    static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
    static let text3 = Color.pair(0x8C8073, 0x9A8F82)
    static let brand = Color.pair(0x9C2F3A, 0xF09AA3)
    static let cta = Color.pair(0x9C2F3A, 0xC24B57)
    static let ctaText = Color(hex: 0xFFFCF6)
    static let focus = Color.pair(0x9C2F3A, 0xC24B57)
    static let good = Color.pair(0x2E7D4F, 0x8FD3A8)
    static let apple = Color.pair(0x9C2F3A, 0xEFE8DC)
    static let appleText = Color.pair(0xFFFCF6, 0x15120F)
    static let dot = Color.pair(0x9C2F3A, 0xE06A74)

    // Home tiles, hero, banners, navigation bar
    static let tile1 = Color.pair(0xF5E3E2, 0x3A2224)
    static let tile1Text = Color.pair(0x9C2F3A, 0xF09AA3)
    static let tile2 = Color.pair(0xFBEBC8, 0x3A2E18)
    static let tile2Text = Color.pair(0x7A5208, 0xF2C46E)
    static let tile3 = Color.pair(0xE5EDE0, 0x22301F)
    static let tile3Text = Color.pair(0x4C6B48, 0x9CC596)
    static let tile4 = Color.pair(0xE8E6F6, 0x2C2A3A)
    static let tile4Text = Color.pair(0x4A3F9A, 0xB9B4F0)
    static let heroChip = Color(light: Color(hex: 0xFFFCF6, opacity: 0.6), dark: Color(hex: 0xFFF0D2, opacity: 0.14))
    static let heroButton = Color.pair(0xFFFCF6, 0xFBEFD6)
    static let bannerBg = Color.pair(0xFBEBC8, 0x3A2E18)
    static let bannerLine = Color.pair(0xE8C77E, 0x6B5426)
    static let bannerChip = Color.pair(0xF2B33D, 0x6B5426)
    static let bannerText = Color.pair(0x2A2420, 0xFBEFD6)
    static let nav = Color.pair(0xFFFCF6, 0x2B2520)
    static let navIcon = Color.pair(0x6E645A, 0xEFE8DC)
    static let navActive = Color(hex: 0x9C2F3A)
    static let navActiveIcon = Color(hex: 0xB5434E)
    static let toast = Color(hex: 0x2E2721)
    static let toastText = Color(hex: 0xFBEFD6)
}
