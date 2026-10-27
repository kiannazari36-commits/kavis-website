import XCTest
@testable import KavisStudy

final class AssistantTests: XCTestCase {
    /// The server's closing "SOURCES: …" line and ** bold never reach the student, also while the answer is written.
    func testOnlyTheAnswerIsShown() {
        XCTAssertEqual(AssistantAPI.visible("**Setirizin** daha az sedasyon yapar.\nSOURCES: 1"), "Setirizin daha az sedasyon yapar.")
        XCTAssertEqual(AssistantAPI.visible("Setirizin daha az sedasyon yapar.\nSOUR"), "Setirizin daha az sedasyon yapar.")
        XCTAssertEqual(AssistantAPI.visible("Sedasyon yapar."), "Sedasyon yapar.")
        XCTAssertEqual(AssistantAPI.visible("Sedasyon yapar [E1]. Az geçer [E2, E3]."), "Sedasyon yapar. Az geçer.")
    }

    func testAssistantTextsExist() {
        for key in ["thinking", "aiNote", "outsidePdf", "actWeak", "actCard", "askBudget", "askDeclined", "askFailed", "trialQFull"] {
            for lang in Lang.allCases { XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) has no text in \(lang)") }
        }
    }

    /// A "cetvel" the assistant writes as a markdown table becomes a real table; the |---| line is dropped.
    func testTablesInAnswers() {
        let parts = AnswerPart.split("Cetvel:\n\n| Özellik | Birinci kuşak |\n|---|---|\n| Sedasyon | Yapar |\n\nOrtak nokta.")
        XCTAssertEqual(parts, [.text("Cetvel:"), .table(head: ["Özellik", "Birinci kuşak"], rows: [["Sedasyon", "Yapar"]]), .text("Ortak nokta.")])
        XCTAssertEqual(AnswerPart.split("| tek satır |"), [.text("| tek satır |")])
        XCTAssertEqual(AnswerPart.split("Düz cevap."), [.text("Düz cevap.")])
    }

    func testLessonSummaryTextsExist() {
        for key in ["lessonSummary", "lsNoWeak", "lsNoWords", "lsMaking", "lsQuiz", "lsExam", "lsWeakMark", "trialLocked", "packMaking", "newA", "retryB"] {
            for lang in Lang.allCases { XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) has no text in \(lang)") }
        }
    }
}
