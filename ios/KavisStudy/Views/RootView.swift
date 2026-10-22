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
                    onStart: { toast.show(prefs.t("k165")) },
                    onLogin: { toast.show(prefs.t("k165")) }
                )
            case .auth, .home:
                Color.clear.overlay(Text(prefs.t("k165")))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        .toastOverlay(toast, lang: prefs.lang)
    }
}
