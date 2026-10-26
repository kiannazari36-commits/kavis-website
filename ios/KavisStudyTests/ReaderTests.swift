import XCTest
@testable import KavisStudy

final class ReaderTests: XCTestCase {
    /// A reading page as the server stores it (material_content.reader_doc), in the web's format.
    private let json = #"""
    {"language": "tr", "sections": [
      {"title": "Tanım", "blocks": [
        {"pageFrom": 1, "pageTo": 2, "tag": "definition", "heading": "Hipertansiyon nedir?",
         "paragraphs": [["Vakaların çoğu ", {"term": "primer", "text": "primer hipertansiyon"}, " grubundadır."],
                        {"selectable": true, "text": "Sekonder hipertansiyonda belirli bir neden vardır."}]}]},
      {"title": "İlaç tedavisi", "blocks": [
        {"pageFrom": 3, "pageTo": 3, "tag": "side_effect", "paragraphs": [["ACE inhibitörleri öksürük yapabilir."]]},
        {"pageFrom": 4, "pageTo": 4, "tag": "something_new", "paragraphs": []}]}
    ]}
    """#

    private func doc() throws -> ReaderDoc { try JSONDecoder().decode(ReaderDoc.self, from: Data(json.utf8)) }

    func testServerReadingPageDecodes() throws {
        let d = try doc()
        XCTAssertEqual(d.docLang, .tr, "the teacher's PDF stays in its own language")
        XCTAssertEqual(d.sections.count, 2)
        XCTAssertEqual(d.pageCount, 3)
        XCTAssertEqual(d.sections[1].pageFrom, 3)
        XCTAssertEqual(d.sections[1].pageTo, 4)
    }

    func testTheTeachersTextIsReadBackUnchanged() throws {
        let block = try XCTUnwrap(try doc().sections.first?.blocks.first)
        XCTAssertEqual(block.paragraphs[0].plain, "Vakaların çoğu primer hipertansiyon grubundadır.")
        XCTAssertEqual(block.paragraphs[1].plain, "Sekonder hipertansiyonda belirli bir neden vardır.")
    }

    /// Every block kind has a label in all four languages; an unknown kind falls back to "Tanım".
    func testEveryTagHasALabel() throws {
        let blocks = try doc().sections.flatMap(\.blocks)
        XCTAssertEqual(blocks[1].tagLabel.key, "tagSide")
        XCTAssertTrue(blocks[1].tagLabel.red)
        XCTAssertEqual(blocks[2].tagLabel.key, "s1tag")
        for key in ["s1tag", "tagDose", "tagSide", "s3tag", "s4tag", "tagGeneral", "pageLabel", "pagesLabel", "pageOf", "resumeAt", "secEnd", "s4end", "noReaderDoc"] {
            for lang in Lang.allCases { XCTAssertNotEqual(Strings.text(key, lang), key, "\(key) has no text in \(lang)") }
        }
    }

    /// Same rule as the web and the server (group-sections): about one section per page is too many.
    func testTooManySectionsAreGrouped() throws {
        func make(sections: Int, pages: Int) -> ReaderDoc {
            let blocks = (1...pages).map { #"{"pageFrom": \#($0), "pageTo": \#($0), "tag": "general", "paragraphs": []}"# }
            let per = max(1, pages / sections)
            let list = (0..<sections).map { i in
                #"{"title": "S\#(i)", "blocks": [\#(blocks[min(i * per, pages - 1)])]}"#
            }
            return try! JSONDecoder().decode(ReaderDoc.self, from: Data(#"{"language": "tr", "sections": [\#(list.joined(separator: ","))]}"#.utf8))
        }
        XCTAssertFalse(ReaderAPI.needsGrouping(try doc()))
        XCTAssertTrue(ReaderAPI.needsGrouping(make(sections: 20, pages: 20)))
        XCTAssertFalse(ReaderAPI.needsGrouping(make(sections: 4, pages: 20)))
    }

    func testLongPdfIsCutIntoPartsOfAtMost100Pages() {
        XCTAssertEqual(UploadAPI.partsFor(100), 1)
        XCTAssertEqual(UploadAPI.partsFor(101), 2)
        XCTAssertEqual(UploadAPI.partsFor(164), 2)
        XCTAssertEqual(UploadAPI.partsFor(301), 4)
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

final class StudyTests: XCTestCase {
    private func card(reps: Int, interval: Double, ease: Double) -> FlashCard {
        FlashCard(id: "c", q: "Soru?\n\nA) bir\nB) iki", a: "B", note: "", page: 3, deck: "D", lang: .tr,
                  intervalDays: interval, ease: ease, reps: reps, againCount: 0)
    }

    /// Same spaced-repetition rule as the web: first "Bildim" 4 days, then interval × ease.
    func testGoodIntervalLikeTheWeb() {
        XCTAssertEqual(CardsAPI.goodInterval(card(reps: 0, interval: 0, ease: 2.5)), 4)
        XCTAssertEqual(CardsAPI.goodInterval(card(reps: 1, interval: 4, ease: 2.5)), 10)
        XCTAssertEqual(CardsAPI.goodInterval(card(reps: 2, interval: 1, ease: 2.0)), 8)
    }

    func testTestCardKeepsItsOptions() {
        let c = card(reps: 0, interval: 0, ease: 2.5)
        XCTAssertEqual(c.question, "Soru?")
        XCTAssertEqual(c.options, "A) bir\nB) iki")
    }

    func testTurkishPageEndings() {
        XCTAssertEqual(QuizView.lookAt(14, .tr), "Sayfa 14'e bak")
        XCTAssertEqual(QuizView.lookAt(13, .tr), "Sayfa 13'e bak")
        XCTAssertEqual(QuizView.lookAt(6, .tr), "Sayfa 6'ya bak")
        XCTAssertEqual(QuizView.lookAt(10, .tr), "Sayfa 10'a bak")
        XCTAssertEqual(QuizView.lookAt(2, .tr), "Sayfa 2'ye bak")
        XCTAssertEqual(QuizView.lookAt(9, .tr), "Sayfa 9'a bak")
        XCTAssertEqual(QuizView.lookAt(100, .tr), "Sayfa 100'e bak")
    }
}
