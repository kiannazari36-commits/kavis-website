import XCTest
@testable import KavisStudy

final class APITests: XCTestCase {
    func testMockCoursesAreComplete() async {
        let courses = await CoursesAPI.listCourses()
        XCTAssertFalse(courses.isEmpty)
        for c in courses {
            for lang in Lang.allCases {
                XCTAssertFalse(c.name[lang].isEmpty, "\(c.id) has no \(lang) name")
                XCTAssertFalse(c.exam[lang].isEmpty, "\(c.id) has no \(lang) exam")
            }
            let s = CoursesAPI.stats(c)
            XCTAssertTrue((0...100).contains(s.percent), "\(c.id) percent \(s.percent)")
        }
        let first = await CoursesAPI.getCourse(id: courses[0].id)
        XCTAssertEqual(first?.id, courses[0].id)
    }

    func testDaysUntilExam() {
        XCTAssertEqual(CoursesAPI.daysUntil("2026-10-19"), 7)
    }

    func testContentLanguageRules() async throws {
        let all = await CoursesAPI.listCourses()
        let course = try XCTUnwrap(all.first { $0.language == .tr })
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
            _ = try await AuthAPI.verifyEmail(email: "a@b.c", name: "A", code: "123")
            XCTFail("a short code must fail")
        } catch {
            XCTAssertTrue(error is AuthError)
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
