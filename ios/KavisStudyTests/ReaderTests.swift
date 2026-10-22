import XCTest
@testable import KavisStudy

final class ReaderTests: XCTestCase {
    private func doc() async throws -> ReaderDoc {
        let loaded = await ReaderAPI.getDoc(id: "hypertension")
        return try XCTUnwrap(loaded)
    }

    func testMockLessonLoads() async throws {
        let d = try await doc()
        XCTAssertEqual(d.language, "tr", "the teacher's PDF stays in its own language")
        XCTAssertEqual(d.sections.count, 4)
        XCTAssertEqual(d.pages, 48)
        XCTAssertFalse(d.sections.flatMap(\.blocks).isEmpty)
    }

    /// Every label, tag and term the lesson uses must have a text in all four languages.
    func testEveryTextOfTheLessonExists() async throws {
        let d = try await doc()
        var keys = Set<String>()
        for section in d.sections {
            keys.insert(section.end)
            for block in section.blocks {
                keys.insert(block.page); keys.insert(block.tag)
                for case .segments(let segments) in block.paragraphs {
                    for case .term(let id, _) in segments {
                        XCTAssertNotNil(d.terms[id], "\(id) is not in the terms table")
                        keys.formUnion(["\(id)name", "\(id)kind", "\(id)def"])
                    }
                }
            }
        }
        for lang in Lang.allCases {
            for key in keys { XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) has no text in \(lang)") }
        }
    }

    func testTheTeachersTextIsReadBackUnchanged() async throws {
        let d = try await doc()
        let block = try XCTUnwrap(d.sections[1].blocks.first)
        let text = block.paragraphs.first?.plain
        XCTAssertEqual(text, "İlk basamak tedavide Diüretikler, ACE inhibitörleri, anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır.")
    }

    func testSampleSentenceHasTranslationsInThreeLanguages() async throws {
        let d = try await doc()
        for code in ["en", "fa", "ar"] {
            let t = try XCTUnwrap(d.sampleTranslations[code])
            XCTAssertFalse(t.lit.isEmpty); XCTAssertFalse(t.nat.isEmpty)
        }
        XCTAssertEqual(d.sampleTranslations["fa"]?.dir, "rtl")
    }

    func testReadingThemeFollowsTheModeUntilChosen() {
        var s = Settings()
        XCTAssertFalse(s.readerPaperChosen)
        s.readerPaper = .light
        s.readerPaperChosen = true
        let data = try? JSONEncoder().encode(s)
        let back = data.flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
        XCTAssertEqual(back?.readerPaper, .light)
        XCTAssertEqual(back?.readerPaperChosen, true)
    }
}
