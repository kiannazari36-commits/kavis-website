import XCTest

/// Taps through the real screens in the simulator (Turkish texts). Mock server, so everything is fast and offline.
final class FlowTests: XCTestCase {
    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-kavis.lang", "tr", "-kavis.theme", "light"] + args
        app.launch()
        return app
    }

    func testSignUpThroughEmailCodeToHome() {
        let app = launch(["-kavis.route", "welcome"])
        app.buttons["Başlayalım"].tap()
        XCTAssertTrue(app.staticTexts["Hesabını oluştur"].waitForExistence(timeout: 5), "sign up screen")

        // The button is locked until the terms are accepted: pressing it only shows a message.
        app.buttons["Hesap oluştur"].tap()
        XCTAssertTrue(app.staticTexts["Önce kullanım koşullarını onayla (kutuyu işaretle)"].waitForExistence(timeout: 3), "needs consent")

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Kullanım koşulları'")).firstMatch.tap()
        app.buttons["Hesap oluştur"].tap()
        XCTAssertTrue(app.staticTexts["E-postanı kontrol et"].waitForExistence(timeout: 5), "email code screen")

        // Without the code, "Doğrula" only shows a message.
        app.buttons["Doğrula ve devam et"].tap()
        XCTAssertTrue(app.staticTexts["Önce e-postadaki 6 haneli kodu gir"].waitForExistence(timeout: 3), "needs code")

        app.buttons["Kodu e-postadan yapıştır"].tap()
        app.buttons["Doğrula ve devam et"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 5), "home")
    }

    func testEndedTrialLocksNewPdf() {
        let app = launch(["-kavis.route", "home", "-kavis.trial", "ended"])
        XCTAssertTrue(app.buttons["PDF yükle"].waitForExistence(timeout: 5))
        app.buttons["PDF yükle"].tap()
        XCTAssertTrue(app.staticTexts["Premium'a özel"].waitForExistence(timeout: 3), "locked dialog")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Deneme süren doldu'")).firstMatch.exists)
    }

    func testPlanPanelOpensAndCloses() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["Bugünün planını aç"].tap()
        XCTAssertTrue(app.buttons["Bugünün planını kapat"].waitForExistence(timeout: 3), "panel open")
        app.buttons["Bugünün planını kapat"].tap()
        XCTAssertTrue(app.buttons["Bugünün planını aç"].waitForExistence(timeout: 3), "panel closed")
    }

    func testReviewLaterAndUndo() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["Sonra yap: ertele ya da kaldır"].tap()
        app.buttons["Yarına ertele"].tap()
        XCTAssertTrue(app.staticTexts["Tekrar yarına ertelendi"].waitForExistence(timeout: 3))
        app.buttons["Geri al"].tap()
        XCTAssertTrue(app.staticTexts["Bugün tekrar günü"].waitForExistence(timeout: 3), "review card is back")
    }
}
