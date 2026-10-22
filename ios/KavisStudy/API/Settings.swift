import Foundation

/// Language for quiz questions, cards and summaries (CLAUDE.md "Content language").
/// `pdf` = same as the uploaded PDF (default), `app` = same as the interface, or a chosen language.
enum ContentLangChoice: String, Codable, CaseIterable {
    case pdf, app, tr, en, fa, ar
}

enum PlanMode: String, Codable { case aim, own, none }
enum ReaderPaper: String, Codable { case light, sepia, dark }
enum TranslationStyle: String, Codable { case literal, natural }

struct Settings: Codable, Equatable {
    var contentLang: ContentLangChoice = .pdf
    /// Per-course override; a missing course uses the general setting. The course setting wins.
    var courseContentLang: [String: ContentLangChoice] = [:]
    var planMode: PlanMode = .aim
    /// Study days per week and hours per day (chosen at sign-up, editable in Settings).
    var studyDays = 4
    var studyHours = 1.5
    /// Default reading paper and text size in the reader.
    var readerPaper: ReaderPaper = .sepia
    var readerFontSize = 20
    var translationStyle: TranslationStyle = .natural
    var pushNotifications = true
    var sync = true
    var cheerNotifications = true
    var offlineMode = false
    var autoDownload = true

    init() {}

    /// Missing keys (an older saved version) fall back to the defaults.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contentLang = try c.decodeIfPresent(ContentLangChoice.self, forKey: .contentLang) ?? contentLang
        courseContentLang = try c.decodeIfPresent([String: ContentLangChoice].self, forKey: .courseContentLang) ?? courseContentLang
        planMode = try c.decodeIfPresent(PlanMode.self, forKey: .planMode) ?? planMode
        studyDays = try c.decodeIfPresent(Int.self, forKey: .studyDays) ?? studyDays
        studyHours = try c.decodeIfPresent(Double.self, forKey: .studyHours) ?? studyHours
        readerPaper = try c.decodeIfPresent(ReaderPaper.self, forKey: .readerPaper) ?? readerPaper
        readerFontSize = try c.decodeIfPresent(Int.self, forKey: .readerFontSize) ?? readerFontSize
        translationStyle = try c.decodeIfPresent(TranslationStyle.self, forKey: .translationStyle) ?? translationStyle
        pushNotifications = try c.decodeIfPresent(Bool.self, forKey: .pushNotifications) ?? pushNotifications
        sync = try c.decodeIfPresent(Bool.self, forKey: .sync) ?? sync
        cheerNotifications = try c.decodeIfPresent(Bool.self, forKey: .cheerNotifications) ?? cheerNotifications
        offlineMode = try c.decodeIfPresent(Bool.self, forKey: .offlineMode) ?? offlineMode
        autoDownload = try c.decodeIfPresent(Bool.self, forKey: .autoDownload) ?? autoDownload
    }

    /// The language quiz questions, cards and summaries are written in for a course.
    /// Buttons and menus always stay in the app language.
    func contentLanguage(for course: Course, appLang: Lang) -> Lang {
        switch courseContentLang[course.id] ?? contentLang {
        case .pdf: course.language
        case .app: appLang
        case .tr: .tr
        case .en: .en
        case .fa: .fa
        case .ar: .ar
        }
    }
}

enum SettingsAPI {
    private static let key = "kavis.settings"

    // The mock keeps settings on the phone; a real server will store them in the account.
    static func loadNow() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return s
    }

    static func save(_ s: Settings) async -> Settings {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
        return await fakeRequest(s, ms: 0)
    }
}
