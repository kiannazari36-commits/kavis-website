import SwiftUI
import Observation

enum AuthMode { case signup, login }

/// A chat with the assistant: which course, the first question (may be empty) and whether "AI + research" is on.
struct AssistantChatTarget: Equatable {
    var topicId: String
    var question: String = ""
    var ai = false
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
    case courses
    case course(String)
    /// Flash cards due now: all, or one course's.
    case cards(String?)
    case quiz(QuizTarget)
    case weekPlan
    case progress
    case upload(UploadKind)
    case reader(String)
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

    init() {
        user = AuthAPI.currentUser()
        // Test switch: `-kavis.route welcome | login | signup | verify | onboarding | setup | home | profile | courses | upload | uploadPhoto | uploadAudio | reader | assistant | chat`
        // jumps to a screen (removed before launch, see TODO.md).
        switch MockFlag.value("route") {
        case "welcome": route = .welcome
        case "login": route = .auth(.login)
        case "signup", "verify": route = .auth(.signup) // verify: AuthView opens the code screen
        case "onboarding": route = .onboarding
        case "setup": route = .courseSetup
        case "home": route = .home
        case "profile", "profileEdit": route = .profile
        case "courses": route = .courses
        case "cards": route = .cards(nil)
        case "plan": route = .weekPlan
        case "progress": route = .progress
        case "upload": route = .upload(.pdf)
        case "uploadPhoto": route = .upload(.photo)
        case "uploadAudio": route = .upload(.audio)
        case "reader": route = .reader("hypertension")
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
            _ = await DevicesAPI.checkDeviceLimit()
            reset(to: await AuthAPI.needsOnboarding() ? .onboarding : .home)
        }
    }

    /// A new account goes through the onboarding first; an existing one goes home.
    func signedIn(_ user: User, isNew: Bool) {
        self.user = user
        reset(to: isNew ? .onboarding : .home)
    }

    func signOut() async {
        await DevicesAPI.signOutThisDevice()
        await AuthAPI.logOut()
        user = nil
        reset(to: .welcome)
    }
}
