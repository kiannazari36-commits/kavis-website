import Foundation

/// Free trial (CLAUDE.md): 3 days, max 2 PDFs, 60 assistant questions, each PDF max 100 pages.
enum TrialLimits {
    static let days = 3
    static let pdfs = 2
    static let questions = 60
    static let pagesPerPdf = 100
}

struct TrialStatus: Equatable {
    var premium: Bool
    var ended: Bool
    var daysLeft: Int
    var pdfsUsed: Int
    var questionsUsed: Int

    /// After the trial (and without Premium): reading old PDFs, notes, highlights, cards, summaries and
    /// offline use stay. New PDF upload, new assistant questions, new quizzes/cards and sharing need Premium.
    var canUseNewFeatures: Bool { premium || !ended }
    var canUploadPdf: Bool { premium || (!ended && pdfsUsed < TrialLimits.pdfs) }
    var canAskAssistant: Bool { premium || (!ended && questionsUsed < TrialLimits.questions) }
}

enum TrialAPI {
    // Mock states to try the screens: launch with `-kavis.trial active | full | ended` (Debug test switch).
    private static let mocks: [String: TrialStatus] = [
        "active": TrialStatus(premium: false, ended: false, daysLeft: 2, pdfsUsed: 1, questionsUsed: 23),
        "full": TrialStatus(premium: false, ended: false, daysLeft: 1, pdfsUsed: 2, questionsUsed: 60),
        "ended": TrialStatus(premium: false, ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41),
    ]

    /// Shown until the server answers: the last known status, or a fresh trial.
    private(set) static var last = TrialStatus(premium: false, ended: false, daysLeft: TrialLimits.days, pdfsUsed: 0, questionsUsed: 0)

    static func statusNow() -> TrialStatus {
        if let flag = MockFlag.value("trial"), let mock = mocks[flag] { return mock }
        return last
    }

    /// Premium and trial status from the server (RPC `access_status`, the same as the web); nil when offline.
    static func getTrial() async -> TrialStatus? {
        if let flag = MockFlag.value("trial"), let mock = mocks[flag] { return mock }
        struct Row: Decodable { let premium: Bool; let trial_ended: Bool; let days_left: Int; let lessons_used: Int; let questions_used: Int }
        guard supabase.auth.currentUser != nil,
              let a: Row = try? await supabase.rpc("access_status").execute().value else { return nil }
        last = TrialStatus(premium: a.premium, ended: a.trial_ended, daysLeft: a.days_left, pdfsUsed: a.lessons_used, questionsUsed: a.questions_used)
        return last
    }
}
