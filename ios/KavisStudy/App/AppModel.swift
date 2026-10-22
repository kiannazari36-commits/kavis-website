import SwiftUI
import Observation

enum AuthMode { case signup, login }

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
    case upload(UploadKind)
    case reader(String)
    case assistant
}

/// Where the app is (screen) and who is signed in. Mock session until the server exists.
@Observable
final class AppModel {
    private(set) var route: Route
    /// Screens the student came from; `back()` returns to the last one.
    private var history: [Route] = []
    var user: User?

    init() {
        user = AuthAPI.currentUser()
        // Test switch: `-kavis.route welcome | login | signup | verify | onboarding | setup | home | profile | upload | uploadPhoto | uploadAudio | reader | assistant`
        // jumps to a screen (removed before launch, see TODO.md).
        switch MockFlag.value("route") {
        case "welcome": route = .welcome
        case "login": route = .auth(.login)
        case "signup", "verify": route = .auth(.signup) // verify: AuthView opens the code screen
        case "onboarding": route = .onboarding
        case "setup": route = .courseSetup
        case "home": route = .home
        case "profile", "profileEdit": route = .profile
        case "upload": route = .upload(.pdf)
        case "uploadPhoto": route = .upload(.photo)
        case "uploadAudio": route = .upload(.audio)
        case "reader": route = .reader("hypertension")
        case "assistant": route = .assistant
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

    /// After the splash: signed-in students go straight home.
    func finishSplash() { reset(to: user == nil ? .welcome : .home) }

    /// A new account goes through the onboarding first; an existing one goes home.
    func signedIn(_ user: User, isNew: Bool) {
        self.user = user
        reset(to: isNew ? .onboarding : .home)
    }

    func signOut() async {
        await AuthAPI.logOut()
        user = nil
        reset(to: .welcome)
    }
}
