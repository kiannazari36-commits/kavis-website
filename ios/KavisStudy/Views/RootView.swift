import SwiftUI

/// Chooses the screen for the current route and carries the toast.
struct RootView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    var body: some View {
        Group {
            switch app.route {
            case .splash:
                SplashView { if app.route == .splash { app.finishSplash() } }
            case .welcome:
                WelcomeView(
                    onStart: { app.route = .auth(.signup) },
                    onLogin: { app.route = .auth(.login) }
                )
            case .auth(let start):
                AuthView(start: start, onBack: { app.route = .welcome })
            case .home:
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        .toastOverlay(toast, lang: prefs.lang)
    }
}
