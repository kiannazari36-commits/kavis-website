import SwiftUI

/// Interface languages (CLAUDE.md): Turkish, English, Persian, Arabic. Persian and Arabic are right-to-left.
enum Lang: String, CaseIterable, Codable, Identifiable {
    case tr, en, fa, ar

    var id: String { rawValue }
    var isRTL: Bool { self == .fa || self == .ar }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Each language written in itself.
    var name: String {
        switch self {
        case .tr: "Türkçe"
        case .en: "English"
        case .fa: "فارسی"
        case .ar: "العربية"
        }
    }
}
