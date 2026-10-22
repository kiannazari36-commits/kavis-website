import Foundation

/// All interface texts in Turkish, English, Persian and Arabic.
/// The JSON files are copied from the web app (`node ios/scripts/sync-from-web.mjs`), so both apps use the same words.
/// Each file is `{ "tr": { key: text }, "en": …, "fa": …, "ar": … }`.
enum Strings {
    static let files = ["desk", "auth", "app", "reader", "study", "pages", "phone"]

    private final class BundleToken {}

    /// language -> key -> text (all files merged, like web/src/i18n/I18nProvider.tsx).
    static let dicts: [Lang: [String: String]] = {
        var merged: [Lang: [String: String]] = [:]
        for file in files {
            for (lang, dict) in decodeFile(file) {
                merged[lang, default: [:]].merge(dict) { _, new in new }
            }
        }
        return merged
    }()

    /// One file on its own (used by the tests to compare the languages).
    static func decodeFile(_ file: String) -> [Lang: [String: String]] {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "i18n-\(file)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else {
            assertionFailure("Missing texts file i18n-\(file).json — run `node ios/scripts/sync-from-web.mjs`")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { code, dict in Lang(rawValue: code).map { ($0, dict) } })
    }

    /// The text for a key; falls back to English, then to the key itself.
    /// `vars` replaces placeholders such as `{n}`.
    static func text(_ key: String, _ lang: Lang, _ vars: [String: String] = [:]) -> String {
        var s = dicts[lang]?[key] ?? dicts[.en]?[key] ?? key
        for (name, value) in vars { s = s.replacingOccurrences(of: "{\(name)}", with: value) }
        return s
    }
}
