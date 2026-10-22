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

extension KFont {
    /// Extra space between lines so a text gets the design's CSS `line-height` (a multiple of the font size).
    static func lineSpacing(_ multiple: CGFloat, size: CGFloat, lang: Lang) -> CGFloat {
        let natural = UIFont(name: lang.isRTL ? "Vazirmatn" : "Poppins-Regular", size: size)?.lineHeight ?? size * 1.5
        return multiple * size - natural
    }
}

enum KLayout {
    /// Height of the status bar / Dynamic Island area.
    static var safeTop: CGFloat {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.safeAreaInsets.top ?? 47
    }

    /// The design measures from the very top of a 390 × 844 screen. Inside the safe area, that is this much padding.
    static func top(_ fromScreenTop: CGFloat, minimum: CGFloat = 8) -> CGFloat {
        max(fromScreenTop - safeTop, minimum)
    }
}

extension View {
    /// CSS letter-spacing in em. Persian and Arabic letters are never spaced (as in the design).
    func kTracking(_ em: CGFloat, size: CGFloat, lang: Lang) -> some View {
        tracking(lang.isRTL ? 0 : em * size)
    }
}
