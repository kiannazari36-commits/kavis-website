import Foundation
import Supabase

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
    /// False until the student picks a reading theme; before that the reader follows light / dark mode.
    var readerPaperChosen = false
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
        readerPaperChosen = try c.decodeIfPresent(Bool.self, forKey: .readerPaperChosen) ?? readerPaperChosen
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

/// Settings live in the account (table user_settings, one row per student, the same as the web). The phone keeps a
/// copy so the first screen opens with the right reader paper / text size before the server answers.
/// The per-course content language is courses.content_lang_override (server); the copy here is the phone's.
enum SettingsAPI {
    private static let key = "kavis.settings"

    private struct Row: Codable {
        var content_lang: ContentLangChoice
        var plan_mode: PlanMode
        var study_days: Int
        var study_hours: Double
        var reader_paper: ReaderPaper
        var reader_font_size: Int
        var translation_style: TranslationStyle
        var push_notifications: Bool
        var sync: Bool
        var cheer_notifications: Bool
        var offline_mode: Bool
        var auto_download: Bool
    }
    private static let columns =
        "content_lang, plan_mode, study_days, study_hours, reader_paper, reader_font_size, translation_style, push_notifications, sync, cheer_notifications, offline_mode, auto_download"

    /// The phone's copy (instant, may be old).
    static func loadNow() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return s
    }

    private static func cache(_ s: Settings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// The account's settings from the server (kept as the phone's copy), or nil when offline / signed out.
    static func fetch() async -> Settings? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        guard let rows: [Row] = try? await supabase.from("user_settings").select(columns).eq("user_id", value: id).limit(1).execute().value,
              let r = rows.first
        else { return nil }
        var s = loadNow()
        s.contentLang = r.content_lang
        s.planMode = r.plan_mode
        s.studyDays = r.study_days
        s.studyHours = r.study_hours
        s.readerPaper = r.reader_paper
        s.readerFontSize = r.reader_font_size
        s.translationStyle = r.translation_style
        s.pushNotifications = r.push_notifications
        s.sync = r.sync
        s.cheerNotifications = r.cheer_notifications
        s.offlineMode = r.offline_mode
        s.autoDownload = r.auto_download
        cache(s)
        return s
    }

    /// Saves on the phone at once and in the account when signed in.
    static func save(_ s: Settings) async -> Settings {
        cache(s)
        guard let id = supabase.auth.currentUser?.id else { return s }
        let row = Row(content_lang: s.contentLang, plan_mode: s.planMode, study_days: s.studyDays, study_hours: s.studyHours,
                      reader_paper: s.readerPaper, reader_font_size: s.readerFontSize, translation_style: s.translationStyle,
                      push_notifications: s.pushNotifications, sync: s.sync, cheer_notifications: s.cheerNotifications,
                      offline_mode: s.offlineMode, auto_download: s.autoDownload)
        _ = try? await supabase.from("user_settings").update(row).eq("user_id", value: id).execute()
        return s
    }
}
