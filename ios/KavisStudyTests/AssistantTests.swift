import XCTest
@testable import KavisStudy

final class AssistantTests: XCTestCase {
    func testMockTopicsAndAttachments() async {
        let topics = await AssistantAPI.listTopics()
        XCTAssertEqual(topics.count, 7)
        XCTAssertTrue(topics.contains { $0.isAll })
        for kind in AttachmentKind.allCases {
            let a = await AssistantAPI.attachment(kind)
            XCTAssertNotNil(a, "\(kind) sample file missing")
        }
    }

    func testAnswersComeFromTheLesson() {
        let pregnancy = AssistantAPI.answer(topicId: "hypertension", question: "ace inhibitörleri neden gebelikte kullanılmaz?", ai: false, lang: .tr)
        XCTAssertTrue(pregnancy.text.contains("kontrendike"))
        XCTAssertEqual(pregnancy.source, "↗ SAYFA 14")

        let cough = AssistantAPI.answer(topicId: "hypertension", question: "neden öksürük yapar", ai: false, lang: .en)
        XCTAssertTrue(cough.text.lowercased().contains("bradykinin"))
        XCTAssertNotNil(cough.source)

        let all = AssistantAPI.answer(topicId: "all", question: "metformin kimde kullanılmaz", ai: false, lang: .tr)
        XCTAssertTrue(all.text.contains("böbrek"), "'all my courses' searches every lesson")
    }

    /// CLAUDE.md: the assistant only uses the student's material. What it cannot find, it says.
    func testItDoesNotInventAnAnswer() {
        for lang in Lang.allCases {
            let r = AssistantAPI.answer(topicId: "hypertension", question: "Futbolda ofsayt nedir?", ai: false, lang: lang)
            XCTAssertNil(r.source, "no source when nothing was found")
            XCTAssertFalse(r.outsidePDF)
            XCTAssertFalse(r.text.isEmpty)
        }
        let tr = AssistantAPI.answer(topicId: "hypertension", question: "ofsayt", ai: false, lang: .tr)
        XCTAssertTrue(tr.text.contains("bulamadım"))
        // A question about another course is not answered from this one.
        let other = AssistantAPI.answer(topicId: "diabetes", question: "ace inhibitörleri neden gebelikte kullanılmaz?", ai: false, lang: .tr)
        XCTAssertTrue(other.text.contains("bulamadım"))
    }

    func testChatTextsExistInAllLanguages() {
        for lang in Lang.allCases {
            for turkish in ["Asistan", "Sürekli dinle", "Kadın sesi", "Bağlantı yok", "Tekrar dene", "Hazır sorularla devam et", "KAYNAK ·", "↗ SAYFA 14", "Önce dersi seç, sonra sor…"] {
                XCTAssertNotEqual(Strings.design(turkish, lang), lang == .tr ? "" : turkish, "\(turkish) has no \(lang) text")
            }
        }
    }
}
