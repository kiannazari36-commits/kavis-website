import Foundation

/// Number and count formats, same wording as web/src/i18n/format.ts.
enum Format {
    /// "1 hour ago" for a device's last use (an ISO date from the server).
    static func lastSeen(_ iso: String, _ lang: Lang) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let r = RelativeDateTimeFormatter()
        r.locale = lang.locale
        return r.localizedString(for: date, relativeTo: Date())
    }

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

    /// "3. sınıf", "Year 3", "سال ۳", "السنة 3".
    static func yearLabel(_ n: Int, _ lang: Lang) -> String {
        switch lang {
        case .tr: "\(n). sınıf"
        case .en: "Year \(n)"
        case .fa: "سال \(num(n, lang))"
        case .ar: "السنة \(n)"
        }
    }

    /// "48 sayfa · 6,2 MB", "48 pages · 6.2 MB", …
    static func fileMeta(pages: Int, megabytes: Double, _ lang: Lang) -> String {
        let mb = String(format: "%.1f", megabytes)
        switch lang {
        case .tr: return "\(pages) sayfa · \(mb.replacingOccurrences(of: ".", with: ",")) MB"
        case .en: return "\(pages) pages · \(mb) MB"
        case .fa: return "\(num(pages, lang)) صفحه · \(num(mb.replacingOccurrences(of: ".", with: "٫"), lang)) مگابایت"
        case .ar: return "\(pages) صفحة · \(mb) ميغابايت"
        }
    }

    /// 754 seconds → "12:34" (recording times; an hour or more → "1:02:34").
    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
