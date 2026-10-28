import XCTest

/// Taps through the real screens in the simulator (Turkish texts) against the LOCAL Supabase (`supabase start`) with a
/// fake account — never the live server. The account comes from the environment so no password is in git:
///
///     TEST_RUNNER_KAVIS_EMAIL=test3@kavis.test TEST_RUNNER_KAVIS_PASSWORD=… \
///       xcodebuild test -project KavisStudy.xcodeproj -scheme KavisStudy -destination '…' -only-testing:KavisStudyUITests
///
/// (the passwords are in supabase/local-test-users.local.md, not in git). Without them the tests that need a login are
/// skipped. The account needs one course ("Farmakoloji") with a ready lesson "Antihistaminikler" and a ready quiz
/// (id in KAVIS_QUIZ_ID, default is test3's), like test3 has. No test asks the AI or changes the account's data.
final class FlowTests: XCTestCase {
    private var email: String? { ProcessInfo.processInfo.environment["KAVIS_EMAIL"] }
    private var password: String? { ProcessInfo.processInfo.environment["KAVIS_PASSWORD"] }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ route: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-kavis.server", "local", "-kavis.lang", "tr", "-kavis.theme", "light", "-kavis.route", route] + extra
        app.launch()
        return app
    }

    private func loginButton(_ app: XCUIApplication) -> XCUIElement {
        // "Giriş yap" is both the tab on top and the big button below the form: the lower one sends the form.
        app.buttons.matching(NSPredicate(format: "label == 'Giriş yap'")).allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }!
    }

    /// Opens the app on the login screen, signs in with the fake account and waits for the home screen.
    private func signedInApp(route: String? = nil) throws -> XCUIApplication {
        guard let email, let password, !email.isEmpty else { throw XCTSkip("Set TEST_RUNNER_KAVIS_EMAIL and TEST_RUNNER_KAVIS_PASSWORD (local fake account)") }
        let app = launch("login")
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "login screen")
        emailField.tap()
        emailField.typeText(email)
        let pw = app.secureTextFields.firstMatch
        pw.tap()
        pw.typeText(password)
        loginButton(app).tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 45), "home after login")
        // Taps right after typing the password were lost (the login sheet is still going away), so open the app again:
        // the session is kept on the simulator and the home route starts clean.
        app.terminate()
        let home = launch("home")
        XCTAssertTrue(home.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 20), "home after relaunch")
        sleep(2)
        return home
    }

    // MARK: Sign up and login (no account needed)

    func testSignUpNeedsTheTermsFirst() {
        let app = launch("welcome")
        app.buttons["Başlayalım"].tap()
        XCTAssertTrue(app.staticTexts["Hesabını oluştur"].waitForExistence(timeout: 5), "sign up screen")
        // The button is locked until the terms are accepted: pressing it only shows a message.
        app.buttons["Hesap oluştur"].tap()
        XCTAssertTrue(app.staticTexts["Önce kullanım koşullarını onayla (kutuyu işaretle)"].waitForExistence(timeout: 3), "needs consent")
    }

    func testWrongPasswordShowsAMessage() {
        let app = launch("login")
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText("yok.boyle.biri@kavis.test")
        let pw = app.secureTextFields.firstMatch
        pw.tap()
        pw.typeText("yanlis-sifre-123")
        loginButton(app).tap()
        XCTAssertTrue(app.staticTexts["E-posta ya da şifre yanlış."].waitForExistence(timeout: 10), "wrong login message")
    }

    // MARK: Signed in

    private func label(_ app: XCUIApplication, beginsWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    func testLoginShowsMyCoursesOnHome() throws {
        let app = try signedInApp()
        XCTAssertTrue(label(app, beginsWith: "Derslerim klasörü").waitForExistence(timeout: 10), "the course folder card")
        XCTAssertTrue(app.staticTexts["Farmakoloji"].firstMatch.exists, "the account's course")
    }

    func testPlanPanelOpensAndCloses() throws {
        let app = try signedInApp()
        app.buttons["Bugünün planını aç"].tap()
        XCTAssertTrue(app.buttons["Bugünün planını kapat"].waitForExistence(timeout: 10), "panel open")
        app.buttons["Bugünün planını kapat"].tap()
        XCTAssertTrue(app.buttons["Bugünün planını aç"].waitForExistence(timeout: 10), "panel closed")
    }

    func testProfileShowsTheAccountAndLogsOut() throws {
        let app = try signedInApp()
        app.buttons["Profilim"].tap()
        XCTAssertTrue(app.staticTexts["test3@kavis.test"].waitForExistence(timeout: 10), "profile screen")
        app.swipeUp()
        app.buttons["Çıkış yap"].tap()
        XCTAssertTrue(app.buttons["Başlayalım"].waitForExistence(timeout: 15), "back at the welcome screen")
    }

    func testProfileBackGoesHome() throws {
        let app = try signedInApp()
        app.buttons["Profilim"].tap()
        XCTAssertTrue(app.buttons["Geri"].waitForExistence(timeout: 10))
        app.buttons["Geri"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testUploadScreenOpensAndCloses() throws {
        let app = try signedInApp()
        app.buttons["PDF yükle"].tap()
        XCTAssertTrue(app.staticTexts["Ders PDF'ini seç"].waitForExistence(timeout: 10), "upload screen")
        app.buttons["Kapat"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testCourseFolderAndReaderOpen() throws {
        let app = try signedInApp()
        label(app, beginsWith: "Derslerim klasörü").tap()
        XCTAssertTrue(app.staticTexts["Derslerim · Güz"].waitForExistence(timeout: 10), "course folder")
        label(app, beginsWith: "1 PDF").tap()
        let lesson = app.staticTexts["Antihistaminikler"].firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10), "the lesson inside the course")
        lesson.tap()
        // The reader shows the teacher's text and the translate / assistant buttons (nothing is translated or asked).
        XCTAssertTrue(app.buttons["Çevir"].firstMatch.waitForExistence(timeout: 20), "reader")
        XCTAssertTrue(app.buttons["Asistan"].exists, "assistant star in the reader")
    }

    func testAssistantScreenOpens() throws {
        let app = try signedInApp()
        app.buttons["Asistan"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'yardım edeyim'")).firstMatch.waitForExistence(timeout: 10), "assistant start")
        XCTAssertTrue(app.buttons["Gönder"].exists)
        app.buttons["Geri"].tap() // nothing is sent: no AI call
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'çalışalım'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testCardsShowTheFirstCardQuestion() throws {
        let app = try signedInApp()
        app.buttons["Kartlar"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Kartlar"].waitForExistence(timeout: 10), "cards screen")
        XCTAssertTrue(app.buttons["Cevabı göster"].waitForExistence(timeout: 10), "first card (nothing is rated)")
        app.buttons["Kapat"].tap()
    }

    func testQuizCenterOpens() throws {
        let app = try signedInApp()
        app.buttons["Sınav merkezi"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sınav merkezi"].waitForExistence(timeout: 10), "exam centre")
        XCTAssertTrue(app.buttons["Farmakoloji sınavını başlat"].waitForExistence(timeout: 10), "start button for the ready questions")
    }

    /// Opens a ready quiz (made earlier, 11 questions) by its id: no question is generated and no answer is sent.
    func testQuizShowsTheFirstQuestion() throws {
        _ = try signedInApp() // the session stays on the simulator, the route below opens the quiz directly
        let id = ProcessInfo.processInfo.environment["KAVIS_QUIZ_ID"] ?? "640eb703-0e4e-4899-abe6-c7ce01e5d668"
        let app = launch("quiz", extra: ["-kavis.material", id])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '1/11'")).firstMatch.waitForExistence(timeout: 20), "first question of 11")
        XCTAssertTrue(app.buttons["Cevapla"].exists, "answer button (nothing is answered)")
    }

    func testSettingsAndProgressTabs() throws {
        let app = try signedInApp()
        app.buttons["İlerleme"].tap()
        XCTAssertTrue(app.staticTexts["Çalışma süresi"].waitForExistence(timeout: 10), "progress")
        app.buttons["Ayarlar"].tap()
        XCTAssertTrue(app.staticTexts["ÇALIŞMA PLANI"].waitForExistence(timeout: 10), "settings")
        XCTAssertTrue(app.staticTexts["Uygulama dili"].exists)
    }

    // MARK: Onboarding (first steps only: nothing is saved before the last step)

    func testOnboardingFirstSteps() {
        let app = launch("onboarding")
        XCTAssertTrue(app.staticTexts["Uygulama dilini seç"].waitForExistence(timeout: 10))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'English'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Choose app language"].waitForExistence(timeout: 5), "English interface")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your weekly study plan"].waitForExistence(timeout: 5))
        app.buttons["Increase"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which department are you in?"].waitForExistence(timeout: 5))
    }
}
