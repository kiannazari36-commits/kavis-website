import XCTest
@testable import KavisStudy

final class StringsTests: XCTestCase {
    /// Sentence endings that only Turkish and Persian need; empty in English and Arabic on purpose (as in the web).
    private let mayBeEmpty: Set<String> = ["attBelongs"]

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
