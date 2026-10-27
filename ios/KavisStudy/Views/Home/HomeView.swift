import SwiftUI

/// Design: design/NewHome.dc.html (phone home). Buttons whose screens are not built yet show a short toast.
struct HomeView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(NetworkMonitor.self) private var network

    private enum Later: Equatable { case evening, tomorrow, skip }

    @State private var later: Later?
    @State private var reviewMenuOpen = false
    @State private var planOpen = false
    @State private var settings = SettingsAPI.loadNow()
    @State private var courses: [Course] = CoursesAPI.lastCourses
    @State private var todayTasks: [PlanTask] = []
    @State private var todayReview: TodayReview?

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }
    private func soon() { toast.show(t("k165")) }
    private var offline: Bool { !network.isOnline || settings.offlineMode }

    var body: some View {
        ZStack {
            KPhone.homeBg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if offline { offlineBanner }
                        heading
                        uploadButtons
                        review
                        tiles
                        coursesCard
                        TrialCardView(status: trial.status, onPremium: { app.go(.paywall(nil)) })
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            FloatingTabBar(onCourses: { app.go(.courses) }, onProgress: { app.go(.progress) }, onSettings: { app.go(.settings) })
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
            if !planOpen {
                PlanTab(count: todayTasks.filter { $0.status != "done" }.count) { withAnimation(.easeOut(duration: 0.25)) { planOpen = true } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, KLayout.top(296, minimum: 120))
            }
            if planOpen {
                PlanPanel(tasks: todayTasks, onClose: { withAnimation(.easeOut(duration: 0.25)) { planOpen = false } }, onItem: openTask, onWeek: { planOpen = false; app.go(.weekPlan) })
            }
            if let key = trial.lockedKey {
                TrialLockedDialog(
                    messageKey: key,
                    ended: trial.status.ended,
                    onCancel: { trial.lockedKey = nil },
                    onPremium: { let key = trial.lockedKey; trial.lockedKey = nil; app.go(.paywall(key == "pwWhyShare" ? key : nil)) }
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: trial.lockedKey)
        .animation(.easeOut(duration: 0.2), value: later)
        .animation(.easeOut(duration: 0.2), value: reviewMenuOpen)
        .task {
            Task { photo = await AvatarAPI.fetch() }
            async let list = CoursesAPI.listCourses()
            async let week = PlanAPI.weekTasks()
            async let review = PlanAPI.todayReview()
            Task { unread = await NotificationsAPI.hasUnread() }
            await trial.refresh()
            courses = await list
            todayTasks = await week.filter { $0.day == CoursesAPI.todayISO() }
            todayReview = await review
        }
    }

    // MARK: Top bar

    @State private var photo: UIImage? = AvatarAPI.cached()
    @State private var unread = false

    private var fullName: String { app.user?.name ?? "Elif Yıldız" }
    private var firstName: String { fullName.split(separator: " ").first.map(String.init) ?? fullName }
    private var initials: String {
        fullName.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            profileButton
            Spacer()
            Button { app.go(.assistant) } label: {
                ZStack {
                    Circle().fill(RadialGradient(
                        colors: [Color(hex: 0xB8404D), Color(hex: 0x9C2F3A), Color(hex: 0x7A2230)],
                        center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 32
                    ))
                    Image("StarButton").resizable().scaledToFit().frame(width: 46 * 0.88, height: 46 * 0.88)
                }
                .frame(width: 46, height: 46)
                .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 9, y: 6)
            }
            .accessibilityLabel(t("home.k390"))
            Button { app.go(.notifications) } label: {
                KIcon(name: .bell, size: 20, width: 1.6)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if unread { Circle().fill(KPhone.dot).frame(width: 8, height: 8).padding(.top, 11).padding(.trailing, 12) }
                    }
            }
            .accessibilityLabel(t("home.k504"))
        }
        .padding(.horizontal, 20)
        .padding(.top, KLayout.top(60, minimum: 6))
    }

    private var profileButton: some View {
        Button { app.go(.profile) } label: {
            HStack(spacing: 8) {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(Circle())
                } else {
                    Text(initials)
                        .font(KFont.ui(13, .semibold, lang: lang))
                        .foregroundStyle(KPhone.ctaText)
                        .frame(width: 34, height: 34)
                        .background(KPhone.navActive, in: Circle())
                }
                (Text("\(t("home.k1440")) ") + Text(firstName).fontWeight(.semibold))
                    .font(KFont.ui(14, lang: lang))
                    .foregroundStyle(KPhone.text)
                KIcon(name: .chevronDown, size: 14, width: 2).foregroundStyle(KPhone.text)
            }
            .padding(.leading, 5).padding(.trailing, 12)
            .frame(height: 44)
            .background(KPhone.card, in: Capsule())
            .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
        }
        .accessibilityLabel(t("home.k1677"))
    }

    // MARK: Content

    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            KIcon(name: .wifiOff, size: 18, width: 1.8)
                .foregroundStyle(KPhone.bannerText)
                .frame(width: 36, height: 36)
                .background(KPhone.bannerChip, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t("home.offlineTitle")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Text(t("home.offlineText"))
                    .font(KFont.ui(12, lang: lang))
                    .kLineHeight(1.45, size: 12, lang: lang)
                    .foregroundStyle(KPhone.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(KPhone.bannerBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KPhone.bannerLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var heading: some View {
        (Text("\(t("home.k599"))\n").font(KFont.ui(34, .regular, lang: lang)).foregroundStyle(KPhone.text3)
            + Text(t("home.k2555")).font(KFont.ui(34, .medium, lang: lang)).foregroundStyle(KPhone.text))
            .kTracking(-0.03, size: 34, lang: lang)
            .kLineHeight(1.1, size: 34, lang: lang)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var uploadButtons: some View {
        // Uploading is Premium-only after the trial and needs internet.
        func open(_ kind: UploadKind) -> () -> Void {
            {
                if offline { toast.show(t("home.uploadOffline")) } else { trial.perform(.pdf) { app.go(.upload(kind)) } }
            }
        }
        return HStack(spacing: 8) {
            uploadButton(.upload, "PDF", label: t("home.k1586"), primary: true, action: open(.pdf))
            uploadButton(.camera, t("home.k1013"), label: t("home.k1016"), action: open(.photo))
            uploadButton(.mic, t("home.k1832"), label: t("home.k1832"), action: open(.audio))
            uploadButton(.help, t("home.k1905"), label: t("home.k1903"), action: { offline ? toast.show(t("home.uploadOffline")) : app.go(.samples(nil)) })
        }
    }

    private func uploadButton(_ icon: KIconName, _ title: String, label: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                KIcon(name: icon, size: 20, width: 1.6)
                Text(title).font(KFont.ui(11, primary ? .medium : .regular, lang: lang)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(primary ? KPhone.ctaText : KPhone.text)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(primary ? KPhone.navActive : KPhone.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(primary ? .clear : KPhone.line, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    // MARK: Today's review

    /// Only when the daily planner made a review for today (summary + cards + questions).
    @ViewBuilder private var review: some View {
        if let later { laterCard(later) } else if let todayReview { reviewHero(todayReview) }
        if reviewMenuOpen && later == nil && todayReview != nil { reviewMenu }
    }

    /// A plan task opens where it is done (the lesson, its exam or the cards) and counts as done.
    private func openTask(_ task: PlanTask) {
        planOpen = false
        app.go(task.route)
        if task.status != "done" { Task { await PlanAPI.setDone(task.id, true) } }
    }

    private func reviewHero(_ r: TodayReview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                KIcon(name: .sync, size: 22, width: 1.7)
                    .frame(width: 46, height: 46)
                    .background(KPhone.heroChip, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("home.k602")).font(KFont.ui(18, .semibold, lang: lang))
                    Text(t("home.reviewSub", ["t": r.title, "c": Format.num(r.cards, lang), "q": Format.num(r.questions, lang), "m": Format.num(r.minutes, lang)]))
                        .font(KFont.ui(13, lang: lang)).opacity(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                Button { reviewMenuOpen.toggle() } label: {
                    Text(t("home.k1882"))
                        .font(KFont.ui(15, .medium, lang: lang))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .overlay(Capsule().stroke(lineWidth: 1.5))
                        .opacity(0.85)
                }
                .accessibilityLabel(t("home.k1884"))
                .accessibilityAddTraits(reviewMenuOpen ? .isSelected : [])
                Button { app.go(.review(r.id)) } label: {
                    HStack(spacing: 8) {
                        KIcon(name: .play, size: 14)
                        Text(t("home.k2062")).font(KFont.ui(15, .medium, lang: lang))
                    }
                    .foregroundStyle(Color(hex: 0x2A2420))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(KPhone.heroButton, in: Capsule())
                }
            }
        }
        .foregroundStyle(KColor.onHero)
        .padding(18)
        .background(KGradient.hero, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(light: Color(hex: 0xF2B33D, opacity: 0.28), dark: .clear), radius: 15, y: 12)
    }

    private var reviewMenu: some View {
        let options: [(Later, String, KIconName)] = [
            (.evening, "home.reviewEvening", .clock),
            (.tomorrow, "home.reviewTomorrow", .calendar),
            (.skip, "home.reviewSkip", .trash),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.0) { option, key, icon in
                Button {
                    later = option
                    reviewMenuOpen = false
                    // "Yarın" and "Bugün atla" move the review on the server; "Akşam" keeps it for today.
                    if option != .evening, let id = todayReview?.id { Task { await PlanAPI.setReview(id, done: false) } }
                    toast.show(t(Self.messageKeys[option]!.title))
                } label: {
                    HStack(spacing: 8) {
                        KIcon(name: icon, size: 16, width: 1.8)
                        Text(t(key)).font(KFont.ui(13, lang: lang)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(KPhone.text)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(KPhone.card, in: Capsule())
                    .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("home.k2064"))
    }

    private static let messageKeys: [Later: (title: String, sub: String)] = [
        .evening: ("home.msgEvening", "home.msgEveningSub"),
        .tomorrow: ("home.msgTomorrow", "home.msgTomorrowSub"),
        .skip: ("home.msgSkip", "home.msgSkipSub"),
    ]

    private func laterCard(_ state: Later) -> some View {
        let keys = Self.messageKeys[state]!
        let canStart = state != .skip
        return HStack(spacing: 12) {
            KIcon(name: state == .skip ? .close : .clock, size: 20, width: 2)
                .foregroundStyle(KPhone.tile2Text)
                .frame(width: 44, height: 44)
                .background(KPhone.tile2, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t(keys.title)).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Text(t(keys.sub)).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if canStart {
                Button {
                    later = nil
                    if let id = todayReview?.id { app.go(.review(id)) }
                } label: {
                    Text(t("home.k2629")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .padding(.horizontal, 14).frame(height: 38)
                        .background(KPhone.navActive, in: Capsule())
                }
            }
            Button { later = nil; toast.show(t("home.msgUndo")) } label: {
                Text(t("home.k1053")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text)
                    .padding(.horizontal, 14).frame(height: 38)
                    .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .kPhoneCard()
    }

    // MARK: Tiles and courses

    private func tileTapped(_ key: String) {
        switch key {
        case "home.tileCards": app.go(.cards(nil))
        case "home.tileExam": app.go(.examCenter)
        case "home.tileSummary":
            // The summary of the lesson the student is working on (else the newest one).
            let pdfs = CoursesAPI.lastCourses.flatMap(\.pdfs)
            if let pdf = pdfs.first(where: { $0.read > 0 && $0.read < 100 }) ?? pdfs.first { app.go(.lessonSummary(pdf.id)) } else { toast.show(t("quiz.none")) }
        default: soon()
        }
    }

    private var tiles: some View {
        let items: [(KIconName, String, Color, Color, Color)] = [
            (.checklist, "home.tileExam", KPhone.tile1, KPhone.tile1Text, KPhone.card),
            (.cards, "home.tileCards", KPhone.tile2, KPhone.tile2Text, KPhone.sub),
            (.book, "home.tileSummary", KPhone.tile3, KPhone.tile3Text, KPhone.card),
        ]
        return HStack(spacing: 10) {
            ForEach(items, id: \.1) { icon, key, chip, fg, bg in
                Button { tileTapped(key) } label: {
                    VStack(spacing: 10) {
                        KIcon(name: icon, size: 20, width: 1.6)
                            .foregroundStyle(fg)
                            .frame(width: 44, height: 44)
                            .background(chip, in: Circle())
                        Text(t(key)).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 116)
                    .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                }
            }
        }
    }

    private var coursesCard: some View {
        Button { app.go(.courses) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    KIcon(name: .folder, size: 21, width: 1.6)
                        .foregroundStyle(KPhone.tile2Text)
                        .frame(width: 44, height: 44)
                        .background(KPhone.tile2, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("home.k787")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        Text(coursesLine).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    KIcon(name: .arrowRight, size: 16, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text)
                }
                // The student's first three courses (the design's three chips), in their folder colours.
                if !courses.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(courses.prefix(3)) { c in
                            let (bg, fg) = chipColors(c.color)
                            chip(c.short?[lang] ?? c.name[lang], bg: bg, fg: fg)
                        }
                    }
                }
            }
            .padding(14)
            .kPhoneCard()
        }
        .buttonStyle(.plain)
    }

    /// "Güz dönemi · 5 ders · 13 PDF · 19 sa" from the student's courses.
    private var coursesLine: String {
        let minutes = courses.reduce(0) { $0 + CoursesAPI.stats($1).minutes }
        return t("home.coursesSub", [
            "term": t(CoursesAPI.termName().hasSuffix("Güz") ? "home.termFall" : "home.termSpring"),
            "c": Format.num(courses.count, lang),
            "p": Format.num(courses.reduce(0) { $0 + $1.pdfs.count }, lang),
            "h": Format.num(minutes / 60, lang),
        ])
    }

    private func chipColors(_ c: CourseColor) -> (Color, Color) {
        switch c {
        case .red: (KPhone.tile1, KPhone.tile1Text)
        case .amb: (KPhone.tile4, KPhone.tile4Text)
        default: (KPhone.tile2, KPhone.tile2Text)
        }
    }

    private func chip(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(KFont.ui(11, .semibold, lang: lang))
            .foregroundStyle(fg)
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(bg, in: Capsule())
    }
}
