import SwiftUI
import Observation

enum AuthMode { case signup, login }

enum Route: Equatable {
    case splash
    case welcome
    case auth(AuthMode)
    case home
}

/// Where the app is (screen) and who is signed in. Mock session until the server exists.
@Observable
final class AppModel {
    var route: Route
    var user: User?

    init() {
        user = AuthAPI.currentUser()
        // Test switch: `-kavis.route welcome | login | signup | home` jumps to a screen (removed before launch, see TODO.md).
        switch MockFlag.value("route") {
        case "welcome": route = .welcome
        case "login": route = .auth(.login)
        case "signup": route = .auth(.signup)
        case "home": route = .home
        default: route = .splash
        }
    }

    /// After the splash: signed-in students go straight home.
    func finishSplash() { route = user == nil ? .welcome : .home }

    func signedIn(_ user: User) {
        self.user = user
        route = .home
    }

    func signOut() async {
        await AuthAPI.logOut()
        user = nil
        route = .welcome
    }
}
