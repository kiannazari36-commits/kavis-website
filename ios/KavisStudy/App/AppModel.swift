import SwiftUI
import Observation

enum AuthMode { case signup, login }

/// A chat with the assistant: which course, the first question (may be empty) and whether "AI + research" is on.
struct AssistantChatTarget: Equatable {
    var topicId: String
    var question: String = ""
    var ai = false
    /// "Soruyu çözdür": a JPEG of the question, solved step by step.
    var photo: Data? = nil
    /// A conversation from "Geçmiş" to continue (else the course's latest one).
    var threadId: String? = nil
}

/// What the student uploads (the three start buttons on home).
enum UploadKind: Equatable { case pdf, photo, audio }

enum Route: Equatable {
    case splash
    case welcome
    case auth(AuthMode)
    case onboarding
    case courseSetup
    case home
    case profile
    case settings
    /// "Sınav merkezi" (home tile).
    case examCenter
    /// Premium (Apple in-app purchase); the text key says why it opened (e.g. "pwWhyShare").
    case paywall(String?)
    /// An account already on 2 devices: the student signs one out first (`AppModel.limitDevices`).
    case deviceLimit
    case courses
    case course(String)
    /// Flash cards due now: all, or one course's.
    case cards(String?)
    /// Flash cards due now of one lesson (from the lesson summary).
    case lessonCards(String)
    case quiz(QuizTarget)
    case weekPlan
    case progress
    case upload(UploadKind)
    case reader(String)
    /// "Ders özeti" of one lesson (design ScrReview, tab "Bu ders").
    case lessonSummary(String)
    /// A lecture recording (transcript and the lecturer's emphasis), optionally from a moment (seconds).
    case recording(String, at: Double = 0)
    /// "Soru örneklerim" (the lecturer's sample questions of a course).
    case samples(String?)
    /// "Bugünün tekrarı" of the daily planner (review_sessions id).
    case review(String)
    case assistant
    case assistantChat(AssistantChatTarget)
}

/// Where the app is (screen) and who is signed in (the Supabase session, kept in the Keychain).
@Observable
final class AppModel {
    private(set) var route: Route
    /// Screens the student came from; `back()` returns to the last one.
    private var history: [Route] = []
    var user: User?
    /// The course "Bu derse PDF ekle" chose for the upload screen (read once by it).
    var uploadCourseId: String?
    /// The page the reader should open at (from the lesson summary; read once by the reader).
    var readerPage: Int?
    /// The other devices of an account that is full (2 devices), shown on the device-limit screen.
    var limitDevices: [Device] = []

    init() {
        user = AuthAPI.currentUser()
        // Test switch: `-kavis.route welcome | login | signup | verify | onboarding | setup | home | profile | settings | courses | upload | uploadPhoto | uploadAudio | reader | assistant | chat`
        // jumps to a screen (removed before launch, see TODO.md).
        switch MockFlag.value("route") {
        case "welcome": route = .welcome
        case "login": route = .auth(.login)
        case "signup", "verify": route = .auth(.signup) // verify: AuthView opens the code screen
        case "onboarding": route = .onboarding
        case "setup": route = .courseSetup
        case "home": route = .home
        case "profile", "profileEdit": route = .profile
        case "settings": route = .settings
        case "exam": route = .examCenter
        case "paywall": route = .paywall(nil)
        case "devices": route = .deviceLimit
        case "courses": route = .courses
        case "cards": route = .cards(nil)
        case "plan": route = .weekPlan
        case "progress": route = .progress
        case "upload": route = .upload(.pdf)
        case "uploadPhoto": route = .upload(.photo)
        case "uploadAudio": route = .upload(.audio)
        case "reader": route = .reader("hypertension")
        case "summary": route = .lessonSummary(MockFlag.value("material") ?? "")
        case "samples": route = .samples(nil)
        case "quiz": route = .quiz(QuizTarget(materialId: "", kind: .exam, quizId: MockFlag.value("material")))
        case "review": route = .review(MockFlag.value("material") ?? "")
        case "recording": route = .recording(MockFlag.value("material") ?? "")
        case "assistant": route = .assistant
        case "chat": route = .assistantChat(AssistantChatTarget(topicId: "hypertension"))
        default: route = .splash
        }
    }

    /// Opens a screen on top of the current one.
    func go(_ next: Route) {
        history.append(route)
        route = next
    }

    /// Shows another screen in place of the current one (back still goes to the screen before).
    func replace(_ next: Route) {
        route = next
    }

    /// Back to the screen before (`fallback` when there is none).
    func back(fallback: Route = .home) {
        route = history.popLast() ?? fallback
    }

    /// Replaces everything: used when a flow starts over (sign in, log out).
    func reset(to next: Route) {
        history = []
        route = next
    }

    /// After the splash: signed-in students go home (or to the first steps if not answered yet). A phone that
    /// another device signed out logs out here too; the device list is refreshed ("last seen").
    func finishSplash() {
        guard user != nil else { return reset(to: .welcome) }
        Task { @MainActor in
            if await DevicesAPI.signedOutElsewhere() {
                await AuthAPI.logOut()
                user = nil
                return reset(to: .welcome)
            }
            if let others = await DevicesAPI.checkDeviceLimit() { return stopAtDeviceLimit(others) }
            reset(to: await AuthAPI.needsOnboarding() ? .onboarding : .home)
        }
    }

    /// The account is on 2 other devices: nothing else opens until one of them is signed out.
    func stopAtDeviceLimit(_ others: [Device]) {
        limitDevices = others
        reset(to: .deviceLimit)
    }

    /// A slot is free now: carry on as after a login (the first steps or home).
    func continueAfterDeviceLimit() async {
        reset(to: await AuthAPI.needsOnboarding() ? .onboarding : .home)
    }

    /// A new account goes through the onboarding first; an existing one goes home.
    func signedIn(_ user: User, isNew: Bool) {
        self.user = user
        reset(to: isNew ? .onboarding : .home)
    }

    /// The server ended this phone's login (signed out from another device): log out here without calling it.
    func sessionEnded() async {
        await AuthAPI.logOut(localOnly: true)
        ReminderService.clear()
        user = nil
        reset(to: .welcome)
    }

    func signOut() async {
        await PushService.unregister()
        await DevicesAPI.signOutThisDevice()
        await AuthAPI.logOut()
        ReminderService.clear()
        user = nil
        reset(to: .welcome)
    }
}
