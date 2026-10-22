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
        // A new account goes to the onboarding before home.
        XCTAssertTrue(app.staticTexts["Uygulama dilini seç"].waitForExistence(timeout: 5), "onboarding")
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

    func testProfileEditAndLogOut() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["Profilim"].tap()
        XCTAssertTrue(app.staticTexts["Elif Yıldız"].waitForExistence(timeout: 5), "profile screen")
        XCTAssertTrue(app.staticTexts["Ücretsiz deneme"].exists, "the plan card shows the trial")
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Hesap bilgilerim'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Kaydet"].waitForExistence(timeout: 3), "edit page")
        app.buttons["Kaydet"].tap()
        XCTAssertTrue(app.staticTexts["Bilgilerin kaydedildi"].waitForExistence(timeout: 3), "saved message")
        app.buttons["Çıkış yap"].tap()
        XCTAssertTrue(app.buttons["Başlayalım"].waitForExistence(timeout: 5), "back at the welcome screen")
    }

    func testProfileBackGoesHome() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["Profilim"].tap()
        XCTAssertTrue(app.staticTexts["Elif Yıldız"].waitForExistence(timeout: 5))
        app.buttons["Geri"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testOnboardingSteps() {
        let app = launch(["-kavis.route", "onboarding"])
        // Step 1: the language changes at once.
        XCTAssertTrue(app.staticTexts["Uygulama dilini seç"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'English'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Choose app language"].waitForExistence(timeout: 3), "English interface")
        app.buttons["Continue"].tap()
        // Step 2: weekly plan.
        XCTAssertTrue(app.staticTexts["Your weekly study plan"].waitForExistence(timeout: 3))
        app.buttons["Increase"].tap()
        app.buttons["Continue"].tap()
        // Step 3: department.
        XCTAssertTrue(app.staticTexts["Which department are you in?"].waitForExistence(timeout: 3))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Medicine'")).firstMatch.tap()
        app.buttons["Continue"].tap()
        // Steps 4-6: intro cards, then the term courses.
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3), "intro cards have Skip")
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        app.buttons["Let's start"].tap()
        // The term courses: add one more suggestion, then create the folder and land on home.
        XCTAssertTrue(app.staticTexts["2026–2027 Fall term"].waitForExistence(timeout: 3), "course setup")
        XCTAssertTrue(app.buttons["Create my folder · 5 courses"].exists)
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Biopharmaceutics'")).firstMatch.tap()
        app.buttons["Create my folder · 6 courses"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'shall we study'")).firstMatch.waitForExistence(timeout: 5), "home")
    }

    func testSkippingTheIntroGoesHome() {
        let app = launch(["-kavis.route", "onboarding", "-kavis.onboardingStep", "3"])
        app.buttons["Atla"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testUploadPhotosThroughProcessingToHome() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["PDF yükle"].tap()
        XCTAssertTrue(app.staticTexts["Ders PDF'ini seç"].waitForExistence(timeout: 5), "upload screen")
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'PDF yok mu'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Dersi hazırla · 4 sayfa"].waitForExistence(timeout: 3), "photo page")
        app.buttons["Dersi hazırla · 4 sayfa"].tap()
        XCTAssertTrue(app.staticTexts["Ders hazırlanıyor…"].waitForExistence(timeout: 3), "processing")
        // The mock server finishes in about 5 seconds, then the student is back home.
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 15), "home")
    }

    func testTooLongPdfSheetThenProcessing() {
        let app = launch(["-kavis.route", "upload", "-kavis.uploadMode", "long"])
        XCTAssertTrue(app.staticTexts["Bu PDF çok uzun"].waitForExistence(timeout: 5), "100 page sheet")
        app.buttons["Devam et"].tap()
        XCTAssertTrue(app.staticTexts["Ders hazırlanıyor…"].waitForExistence(timeout: 3))
    }

    func testCloseButtonReturnsHome() {
        let app = launch(["-kavis.route", "home"])
        app.buttons["PDF yükle"].tap()
        XCTAssertTrue(app.staticTexts["Ders PDF'ini seç"].waitForExistence(timeout: 5))
        app.buttons["Kapat"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 5))
    }
}
