import SwiftUI
import XCTest
@testable import KavisStudy

final class ThemeTests: XCTestCase {
    private func assertBounds(_ d: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                              file: StaticString = #filePath, line: UInt = #line) {
        let r = SVGPathParser.parse(d).boundingRect
        XCTAssertEqual(r.minX, x, accuracy: 0.15, "minX of \(d)", file: file, line: line)
        XCTAssertEqual(r.minY, y, accuracy: 0.15, "minY of \(d)", file: file, line: line)
        XCTAssertEqual(r.width, w, accuracy: 0.3, "width of \(d)", file: file, line: line)
        XCTAssertEqual(r.height, h, accuracy: 0.3, "height of \(d)", file: file, line: line)
    }

    func testSVGLinesAndRelativeCommands() {
        assertBounds("M9 6h11", 9, 6, 11, 0)
        assertBounds("M4 5L10 5 L10 11 Z", 4, 5, 6, 6)
        assertBounds("M3 6h18v12H3z", 3, 6, 18, 12)
        assertBounds("M.5.5L1.5.5", 0.5, 0.5, 1, 0) // numbers without separators
    }

    func testSVGArcsMakeACircle() {
        // The design's circle: radius 9 around (12, 12).
        assertBounds("M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z", 3, 3, 18, 18)
    }

    func testEveryIconParses() {
        let icons: [KIconName] = [.lock, .upload, .list, .checklist, .cards, .mic, .back, .check, .mail, .eye, .eyeOff, .book, .bell,
                                  .refresh, .play, .camera, .help, .chevron, .chevronDown, .chevronLeft, .folder, .close, .send, .clock,
                                  .calendar, .trash, .chart, .sliders, .apple, .star]
        for icon in icons {
            let r = SVGPathParser.parse(icon.rawValue).boundingRect
            XCTAssertFalse(r.isNull || r.isEmpty, "\(icon) is empty")
            XCTAssertTrue(CGRect(x: -0.5, y: -0.5, width: 25, height: 25).contains(r), "\(icon) leaves the 24 × 24 box: \(r)")
        }
    }

    func testNumberFormats() {
        XCTAssertEqual(Format.num(12, .fa), "۱۲")
        XCTAssertEqual(Format.num(12, .ar), "12")
        XCTAssertEqual(Format.percent(56, .tr), "%56")
        XCTAssertEqual(Format.percent(56, .en), "56%")
        XCTAssertEqual(Format.percent(56, .fa), "٪۵۶")
    }

    func testPhoneTextsAreThere() {
        for lang in Lang.allCases {
            XCTAssertNotEqual(Strings.text("welcome.k482", lang), "welcome.k482", "welcome button missing in \(lang)")
        }
        XCTAssertEqual(Strings.text("welcome.k482", .tr), "Başlayalım")
        XCTAssertEqual(Strings.text("welcome.k482", .en), "Let's start")
    }
}

final class AuthRulesTests: XCTestCase {
    func testPasswordScoreMatchesTheWeb() {
        XCTAssertEqual(AuthView.passwordScore(""), 0)
        XCTAssertEqual(AuthView.passwordScore("abc"), 1)
        XCTAssertEqual(AuthView.passwordScore("abcdefgh"), 1)
        XCTAssertEqual(AuthView.passwordScore("Abcdefg1"), 3)
        XCTAssertEqual(AuthView.passwordScore("Abcdefg1!"), 4)
    }

    func testAuthTextsExistInAllLanguages() {
        for lang in Lang.allCases {
            for key in ["signup.titleUp1", "signup.titleIn1", "signup.needConsent", "signup.needCode", "signup.k864", "signup.p0a", "devFullTitle", "k165"] {
                XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) missing in \(lang)")
            }
        }
        XCTAssertEqual(Strings.text("signup.titleIn1", .en), "Welcome")
        XCTAssertEqual(Strings.text("signup.titleIn2", .en), "back")
    }
}
