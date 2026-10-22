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
    // Mock states to try the screens: launch with `-kavis.trial active | full | ended`.
    private static let mocks: [String: TrialStatus] = [
        "active": TrialStatus(premium: false, ended: false, daysLeft: 2, pdfsUsed: 1, questionsUsed: 23),
        "full": TrialStatus(premium: false, ended: false, daysLeft: 1, pdfsUsed: 2, questionsUsed: 60),
        "ended": TrialStatus(premium: false, ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41),
    ]

    static func statusNow() -> TrialStatus {
        var s = mocks[MockFlag.value("trial") ?? "active"] ?? mocks["active"]!
        s.premium = PremiumAPI.isPremium()
        return s
    }

    static func getTrial() async -> TrialStatus {
        await fakeRequest(statusNow(), ms: 0)
    }
}
