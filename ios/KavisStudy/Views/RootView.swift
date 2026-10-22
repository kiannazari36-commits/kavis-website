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
                    onStart: { app.go(.auth(.signup)) },
                    onLogin: { app.go(.auth(.login)) }
                )
            case .auth(let start):
                AuthView(start: start, onBack: { app.back(fallback: .welcome) })
            case .onboarding:
                OnboardingView()
            case .courseSetup:
                CourseSetupView()
            case .home:
                HomeView()
            case .profile:
                ProfileView()
            case .upload(let kind):
                UploadView(kind: kind)
            case .reader(let id):
                ReaderView(docID: id)
            case .assistant:
                Color.clear.overlay(Text(prefs.t("k165")))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        .toastOverlay(toast, lang: prefs.lang)
    }
}
