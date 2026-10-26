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
            case .settings:
                SettingsView()
            case .deviceLimit:
                DeviceLimitView()
            case .courses:
                CoursesListView()
            case .course(let id):
                CourseFolderView(courseId: id)
            case .cards(let course):
                CardsView(courseId: course)
            case .lessonCards(let id):
                CardsView(materialId: id)
            case .quiz(let target):
                QuizView(target: target)
            case .weekPlan:
                WeekPlanView()
            case .progress:
                ProgressView()
            case .upload(let kind):
                UploadView(kind: kind)
            case .reader(let id):
                ReaderView(docID: id)
            case .lessonSummary(let id):
                LessonSummaryView(materialId: id)
            case .assistant:
                AssistantHomeView()
            case .assistantChat(let target):
                AssistantChatView(target: target)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        // The account's language and appearance apply on this phone too (set on another device or at sign-up),
        // and the reminder follows the account's settings.
        .task(id: app.user?.id) {
            guard app.user != nil else { return }
            if let l = await AccountAPI.fetchLang() { prefs.lang = l }
            if let s = await SettingsAPI.fetch() {
                prefs.theme = s.appTheme
                await ReminderService.refresh(s, lang: prefs.lang)
            }
        }
        .toastOverlay(toast, lang: prefs.lang)
    }
}
