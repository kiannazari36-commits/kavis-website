import XCTest
@testable import KavisStudy

final class StringsTests: XCTestCase {
    /// Sentence parts that some languages do not need, empty there on purpose (as in the web): endings only Turkish
    /// and Persian need, and the start of "<email> adresine … gönderdik" (Turkish puts the email first).
    private let mayBeEmpty: Set<String> = ["attBelongs", "linkA", "resetA"]

    func testEveryLanguageHasTheSameKeysAndNoEmptyTexts() {
        for file in Strings.files {
            let d = Strings.decodeFile(file)
            XCTAssertEqual(Set(d.keys), Set(Lang.allCases), "\(file): a language is missing")
            let keys = Set(d[.en]?.keys ?? [:].keys)
            XCTAssertFalse(keys.isEmpty, "\(file) has no texts")
            for lang in Lang.allCases {
                XCTAssertEqual(Set(d[lang]?.keys ?? [:].keys), keys, "\(file): \(lang) keys differ from en")
                for (k, v) in d[lang] ?? [:] where !mayBeEmpty.contains(k) { XCTAssertFalse(v.isEmpty, "\(file).\(k) is empty in \(lang)") }
            }
        }
    }

    func testTextsAndFallbacks() {
        XCTAssertEqual(Strings.text("trialTitle", .tr), "Ücretsiz deneme")
        XCTAssertEqual(Strings.text("trialTitle", .en), "Free trial")
        XCTAssertEqual(Strings.text("trialDaysLeft", .en, ["n": "2"]), "2 days left")
        XCTAssertEqual(Strings.text("no-such-key", .fa), "no-such-key")
    }

    func testLockedMessageIsTheOneFromClaudeMd() {
        XCTAssertEqual(
            Strings.text("trialLocked", .tr),
            "Deneme süren doldu. Çalıştığın PDF'ler seninle kalıyor; yeni PDF yüklemek için Premium'a geç."
        )
    }

    /// CLAUDE.md: offline use is in every plan, free included — no text may call it Premium-only.
    func testOfflineIsNotPremiumOnly() {
        XCTAssertNil(Strings.dicts[.en]?["pwWhyOffline"])
        for lang in Lang.allCases {
            XCTAssertFalse(Strings.text("offFreeT", lang).contains("Premium"), "offFreeT (\(lang)) calls offline Premium")
            XCTAssertFalse(Strings.text("offFreeS", lang).contains("Premium"), "offFreeS (\(lang)) mentions Premium")
        }
    }
}

/// Every `prefs.d("…")` / `d("…")` in the screens must be a text of the design table, in all four languages.
final class DesignTextsTests: XCTestCase {
    func testEveryDesignTextUsedInTheScreensExists() throws {
        let viewsFolder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("KavisStudy/Views")
        let files = FileManager.default.enumerator(at: viewsFolder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "could not find the Views folder")
        let pattern = try NSRegularExpression(pattern: #"\bd\("((?:[^"\\]|\\.)*)"\)"#)
        var checked = 0
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for match in pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let literal = String(source[Range(match.range(at: 1), in: source)!]).replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\'", with: "'")
                guard let entry = Strings.designTable[literal] else {
                    XCTFail("\(file.lastPathComponent): design text not found: \"\(literal)\"")
                    continue
                }
                for lang in ["en", "fa", "ar"] { XCTAssertFalse((entry[lang] ?? "").isEmpty, "\"\(literal)\" has no \(lang) text") }
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 10)
    }

    func testDesignLookup() {
        XCTAssertEqual(Strings.design("Hesap bilgilerim", .tr), "Hesap bilgilerim")
        XCTAssertEqual(Strings.design("Hesap bilgilerim", .en), "My account details")
        XCTAssertEqual(Strings.design("Elif'in kendi yazdığı metin", .fa), "Elif'in kendi yazdığı metin", "texts that are not in the design stay as typed")
    }
}
