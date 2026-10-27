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
            case .paywall(let reason):
                PaywallView(reason: reason)
            case .examCenter:
                ExamCenterView()
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
            case .samples(let course):
                SamplesView(courseId: course)
            case .review(let id):
                ReviewView(reviewId: id)
            case .recording(let id, let at):
                RecordingView(recordingId: id, startAt: at)
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
            PushService.start()
            if let l = await AccountAPI.fetchLang() { prefs.lang = l }
            if let s = await SettingsAPI.fetch() {
                prefs.theme = s.appTheme
                await ReminderService.refresh(s, lang: prefs.lang)
            }
        }
        // A share link opened from outside (universal link or `kavis://s/<slug>`).
        .onOpenURL { url in
            if let slug = ShareAPI.slug(in: url) { app.pendingShare = slug }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL, let slug = ShareAPI.slug(in: url) { app.pendingShare = slug }
        }
        .task(id: "\(app.pendingShare ?? "")|\(app.route == .home)") {
            // Its own task: clearing `pendingShare` changes the id and would cancel this one mid-request.
            if app.pendingShare != nil, app.route == .home { Task { await openPendingShare() } }
        }
        // Another device signed this phone out: the server answers 401 `session_ended`, so back to the start.
        .onReceive(NotificationCenter.default.publisher(for: .sessionEnded)) { _ in
            guard app.user != nil else { return }
            Task { await app.sessionEnded() }
        }
        .toastOverlay(toast, lang: prefs.lang)
    }

    /// Opens a waiting share link on the home screen: a Premium receiver gets the lesson summary; others see the
    /// "Premium only" message.
    private func openPendingShare() async {
        guard let slug = app.pendingShare, app.route == .home else { return }
        app.pendingShare = nil
        switch await ShareAPI.open(slug: slug) {
        case .opened(let id): app.go(.lessonSummary(id))
        case .needsPremium: toast.show(prefs.t("sharePremiumOnly"))
        case .notFound, .failed: toast.show(prefs.t("errOther"))
        }
    }
}
