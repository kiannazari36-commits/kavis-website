import SwiftUI

/// Poppins (UI), Lora (reading text), JetBrains Mono (numbers), Vazirmatn (Persian / Arabic).
/// Poppins and Lora have no Arabic letters, so Persian and Arabic use Vazirmatn everywhere except numbers.
enum KFont {
    /// Interface text.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, lang: Lang) -> Font {
        if lang.isRTL { return .custom("Vazirmatn", size: size).weight(weight) }
        return .custom(poppins(weight), size: size)
    }

    /// Reading text of the PDF (the teacher's text). Pass the language of the PDF, not of the app.
    static func reading(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false, lang: Lang) -> Font {
        if lang.isRTL { return .custom("Vazirmatn", size: size).weight(weight) }
        let font = Font.custom("Lora", size: size).weight(weight)
        return italic ? font.italic() : font
    }

    /// Numbers (percent, minutes, counters).
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }

    private static func poppins(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "Poppins-Bold"
        case .semibold: "Poppins-SemiBold"
        case .medium: "Poppins-Medium"
        default: "Poppins-Regular"
        }
    }
}

extension View {
    /// The design's CSS `line-height` (a multiple of the font size). From iOS 26 the line height is exact.
    /// Before that SwiftUI cannot make lines tighter than the font's own height, so only looser lines are possible.
    @ViewBuilder func kLineHeight(_ multiple: CGFloat, size: CGFloat, lang: Lang) -> some View {
        if #available(iOS 26, *) {
            lineHeight(.exact(points: multiple * size))
        } else {
            lineSpacing(max(0, KFont.lineSpacing(multiple, size: size, lang: lang)))
        }
    }
}

extension KFont {
    /// Extra space between lines so a text gets the design's CSS `line-height` (a multiple of the font size).
    static func lineSpacing(_ multiple: CGFloat, size: CGFloat, lang: Lang) -> CGFloat {
        let natural = UIFont(name: lang.isRTL ? "Vazirmatn" : "Poppins-Regular", size: size)?.lineHeight ?? size * 1.5
        return multiple * size - natural
    }
}

enum KLayout {
    /// Status bar height of the design's 390 × 844 screens.
    static let designStatusBar: CGFloat = 47

    /// The design measures from the very top of the screen. Screens here start below the status bar / Dynamic Island,
    /// so that is the measure minus the status bar. Do not read `UIApplication` / `safeAreaInsets` for this inside a view:
    /// that creates an AttributeGraph cycle and SwiftUI stops updating the screen.
    static func top(_ fromScreenTop: CGFloat, minimum: CGFloat = 8) -> CGFloat {
        max(fromScreenTop - designStatusBar, minimum)
    }
}

extension View {
    /// CSS letter-spacing in em. Persian and Arabic letters are never spaced (as in the design).
    func kTracking(_ em: CGFloat, size: CGFloat, lang: Lang) -> some View {
        tracking(lang.isRTL ? 0 : em * size)
    }
}
