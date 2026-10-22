import Foundation

/// Number and count formats, same wording as web/src/i18n/format.ts.
enum Format {
    private static let faDigits = Array("۰۱۲۳۴۵۶۷۸۹")

    /// Persian uses Persian digits; the other languages use 0–9.
    static func num(_ n: Int, _ lang: Lang) -> String { num(String(n), lang) }

    static func num(_ s: String, _ lang: Lang) -> String {
        guard lang == .fa else { return s }
        return String(s.map { c in c.wholeNumberValue.map { faDigits[$0] } ?? c })
    }

    static func percent(_ n: Int, _ lang: Lang) -> String {
        switch lang {
        case .tr: "%\(n)"
        case .fa: "٪\(num(n, lang))"
        default: "\(n)%"
        }
    }
}
