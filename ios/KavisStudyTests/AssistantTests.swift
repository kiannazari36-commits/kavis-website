import XCTest
@testable import KavisStudy

final class AssistantTests: XCTestCase {
    /// The server's closing "SOURCES: …" line and ** bold never reach the student, also while the answer is written.
    func testOnlyTheAnswerIsShown() {
        XCTAssertEqual(AssistantAPI.visible("**Setirizin** daha az sedasyon yapar.\nSOURCES: 1"), "Setirizin daha az sedasyon yapar.")
        XCTAssertEqual(AssistantAPI.visible("Setirizin daha az sedasyon yapar.\nSOUR"), "Setirizin daha az sedasyon yapar.")
        XCTAssertEqual(AssistantAPI.visible("Sedasyon yapar."), "Sedasyon yapar.")
    }

    func testAssistantTextsExist() {
        for key in ["thinking", "aiNote", "outsidePdf", "actWeak", "actCard", "askBudget", "askDeclined", "askFailed", "trialQFull"] {
            for lang in Lang.allCases { XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) has no text in \(lang)") }
        }
    }
}
