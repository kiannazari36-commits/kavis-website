import XCTest
@testable import KavisStudy

final class APITests: XCTestCase {
    /// A course as the server sends it (courses are real data now, so the tests build one).
    private func sampleCourse() -> Course {
        let pdfs = [
            Pdf(id: "p1", title: L10n(tr: "Ünite 1", en: "Ünite 1", fa: "Ünite 1", ar: "Ünite 1"), read: 100, minutes: 30, pages: 20),
            Pdf(id: "p2", title: L10n(tr: "Ünite 2", en: "Ünite 2", fa: "Ünite 2", ar: "Ünite 2"), read: 0, minutes: 0, pages: 20),
        ]
        return Course(id: "c1", name: L10n(tr: "Farmakoloji", en: "Farmakoloji", fa: "Farmakoloji", ar: "Farmakoloji"), short: nil,
                      color: .red, language: .tr, exam: CoursesAPI.examLabel("midterm", "2026-11-19"), examDate: "2026-11-19", rank: 0, pdfs: pdfs)
    }

    func testCourseStatsAndExamLabels() {
        let s = CoursesAPI.stats(sampleCourse())
        XCTAssertEqual(s.minutes, 30)
        XCTAssertEqual(s.pages, 40)
        XCTAssertEqual(s.percent, 50)
        let label = CoursesAPI.examLabel("final", "2026-01-12")
        for lang in Lang.allCases { XCTAssertFalse(label[lang].isEmpty) }
        XCTAssertTrue(label.tr.hasPrefix("Final · 12"), label.tr)
        XCTAssertEqual(CoursesAPI.examLabel(nil, nil).tr, "Sınav tarihi yok")
        XCTAssertTrue(CoursesAPI.termName(Date(timeIntervalSince1970: 1_793_000_000)).hasSuffix("Güz"))
    }

    func testDaysUntilExam() {
        XCTAssertEqual(CoursesAPI.daysUntil("2026-10-19", today: "2026-10-12"), 7)
    }

    func testContentLanguageRules() async throws {
        let course = sampleCourse()
        var s = Settings()
        XCTAssertEqual(s.contentLanguage(for: course, appLang: .en), .tr, "default is the PDF language")
        s.contentLang = .app
        XCTAssertEqual(s.contentLanguage(for: course, appLang: .en), .en)
        s.contentLang = .ar
        XCTAssertEqual(s.contentLanguage(for: course, appLang: .en), .ar)
        s.courseContentLang[course.id] = .fa
        XCTAssertEqual(s.contentLanguage(for: course, appLang: .en), .fa, "the course setting wins")
    }

    func testOldSavedSettingsGetDefaults() throws {
        let s = try JSONDecoder().decode(Settings.self, from: Data(#"{"studyDays": 5}"#.utf8))
        XCTAssertEqual(s.studyDays, 5)
        XCTAssertEqual(s.contentLang, .pdf)
    }

    func testTrialLimits() {
        XCTAssertEqual([TrialLimits.days, TrialLimits.pdfs, TrialLimits.questions, TrialLimits.pagesPerPdf], [3, 2, 60, 100])
        let ended = TrialStatus(premium: false, ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41)
        XCTAssertFalse(ended.canUploadPdf)
        XCTAssertFalse(ended.canAskAssistant)
        var premium = ended
        premium.premium = true
        XCTAssertTrue(premium.canUploadPdf && premium.canAskAssistant)
        let full = TrialStatus(premium: false, ended: false, daysLeft: 1, pdfsUsed: 2, questionsUsed: 60)
        XCTAssertFalse(full.canUploadPdf)
        XCTAssertFalse(full.canAskAssistant)
    }

    func testEmailCodeMustHaveSixDigits() async throws {
        do {
            _ = try await AuthAPI.verifyEmail(email: "a@b.c", code: "123")
            XCTFail("a short code must fail")
        } catch {
            // Checked before any network call.
            XCTAssertEqual(error as? AuthFailure, .code)
        }
    }

    func testPremiumPlansHaveNoPrices() async throws {
        let offer = await PremiumAPI.getOffer()
        XCTAssertEqual(offer.plans.map(\.id), ["year", "term", "month"])
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mock-premium", withExtension: "json")
            ?? Bundle.main.url(forResource: "mock-premium", withExtension: "json"))
        let text = try String(contentsOf: url, encoding: .utf8)
        for currency in ["₺", "$", "€", "£", " TL", "USD", "TRY"] {
            XCTAssertFalse(text.contains(currency), "Premium data must not contain a price or currency: \(currency)")
        }
    }
}

final class TrialRulesTests: XCTestCase {
    func testLockReasons() {
        let active = TrialModel(status: TrialStatus(premium: false, ended: false, daysLeft: 2, pdfsUsed: 1, questionsUsed: 23))
        XCTAssertNil(active.lockReason(for: .pdf))
        XCTAssertNil(active.lockReason(for: .question))
        XCTAssertEqual(active.lockReason(for: .share), "pwWhyShare", "sharing is Premium only")

        let full = TrialModel(status: TrialStatus(premium: false, ended: false, daysLeft: 1, pdfsUsed: 2, questionsUsed: 60))
        XCTAssertEqual(full.lockReason(for: .pdf), "trialPdfFull")
        XCTAssertEqual(full.lockReason(for: .question), "trialQFull")
        XCTAssertNil(full.lockReason(for: .generate))

        let ended = TrialModel(status: TrialStatus(premium: false, ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41))
        for action in [TrialAction.pdf, .question, .generate, .share] {
            XCTAssertNotNil(ended.lockReason(for: action), "\(action) must be locked after the trial")
        }
        XCTAssertEqual(ended.lockReason(for: .pdf), "trialLocked")

        let premium = TrialModel(status: TrialStatus(premium: true, ended: true, daysLeft: 0, pdfsUsed: 9, questionsUsed: 999))
        for action in [TrialAction.pdf, .question, .generate, .share] { XCTAssertNil(premium.lockReason(for: action)) }
    }

    func testPerformRunsOnlyWhenAllowed() {
        var ran = 0
        let ended = TrialModel(status: TrialStatus(premium: false, ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41))
        ended.perform(.pdf) { ran += 1 }
        XCTAssertEqual(ran, 0)
        XCTAssertEqual(ended.lockedKey, "trialLocked")
        let active = TrialModel(status: TrialStatus(premium: false, ended: false, daysLeft: 2, pdfsUsed: 0, questionsUsed: 0))
        active.perform(.pdf) { ran += 1 }
        XCTAssertEqual(ran, 1)
        XCTAssertNil(active.lockedKey)
    }
}

final class OnboardingRulesTests: XCTestCase {
    func testDepartmentsAreDesignTexts() {
        XCTAssertEqual(OnboardingView.departments.count, 6)
        for name in OnboardingView.departments {
            for lang in Lang.allCases { XCTAssertFalse(Strings.design(name, lang).isEmpty) }
        }
        XCTAssertEqual(Strings.design("Eczacılık", .en), "Pharmacy")
    }

    func testYearLabels() {
        XCTAssertEqual(Format.yearLabel(3, .tr), "3. sınıf")
        XCTAssertEqual(Format.yearLabel(3, .en), "Year 3")
        XCTAssertEqual(Format.yearLabel(3, .fa), "سال ۳")
    }

    /// Written questions are kept (with their model answer); multiple choice needs 2+ options.
    func testQuizQuestionKinds() throws {
        let json = """
        [{"id":"w","text":"Neden?","kind":"written","options":null,"answer_index":null,"model_answer":"Çünkü.","explanation":null,"source_page":1,"hints":[]},
         {"id":"m","text":"Hangisi?","kind":"multiple_choice","options":["a","b"],"answer_index":1,"model_answer":null,"explanation":"x","source_page":2,"hints":[]},
         {"id":"bad","text":"?","kind":"multiple_choice","options":["a"],"answer_index":0,"model_answer":null,"explanation":null,"source_page":null,"hints":null}]
        """
        let rows = try JSONDecoder().decode([QuizAPI.QRow].self, from: Data(json.utf8))
        let qs = rows.compactMap { QuizAPI.question($0) }
        XCTAssertEqual(qs.map(\.id), ["w", "m"])
        XCTAssertTrue(qs[0].written)
        XCTAssertEqual(qs[0].modelAnswer, "Çünkü.")
        XCTAssertFalse(qs[1].written)
        XCTAssertEqual(qs[1].answer, 1)
    }
}
