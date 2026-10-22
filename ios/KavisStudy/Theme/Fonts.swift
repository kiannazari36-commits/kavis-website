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
