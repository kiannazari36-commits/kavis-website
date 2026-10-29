import SwiftUI

/// Design: design/NewHome.dc.html (phone home). Buttons whose screens are not built yet show a short toast.
struct HomeView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(NetworkMonitor.self) private var network
    /// iPad (design NewIPad, home): two columns and the "Bugünün planı" column instead of the phone's side panel.
    @Environment(\.padRail) private var wide

    private enum Later: Equatable { case evening, tomorrow, skip }

    @State private var later: Later?
    @State private var reviewMenuOpen = false
    @State private var planOpen = false
    @State private var settings = SettingsAPI.loadNow()
    @State private var courses: [Course] = CoursesAPI.lastCourses
    @State private var todayTasks: [PlanTask] = []
    @State private var todayReview: TodayReview?
    @State private var tomorrowClasses: [ClassEntry] = []

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }
    private func soon() { toast.show(t("k165")) }
    private var offline: Bool { !network.isOnline || settings.offlineMode }

    var body: some View {
        ZStack {
            KPhone.homeBg.ignoresSafeArea()
            if wide { wideLayout } else {
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
            }
            FloatingTabBar(onCourses: { app.go(.courses) }, onProgress: { app.go(.progress) }, onSettings: { app.go(.settings) })
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
            if !planOpen {
                PlanTab(count: todayTasks.filter { $0.status != "done" }.count) { withAnimation(.easeOut(duration: 0.25)) { planOpen = true } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, wide ? 250 : KLayout.top(296, minimum: 120))
            }
            if planOpen && !wide {
                PlanPanel(tasks: todayTasks, onClose: { withAnimation(.easeOut(duration: 0.25)) { planOpen = false } }, onItem: openTask, onToggle: toggleDone, onWeek: { planOpen = false; app.go(.weekPlan) })
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
            if wide {
                let wd = (Calendar(identifier: .gregorian).component(.weekday, from: Date()) + 5) % 7 + 1
                tomorrowClasses = await TimetableAPI.list().filter { $0.weekday == wd % 7 + 1 }
            }
        }
    }

    // MARK: iPad

    /// Design NewIPad, home: greeting row, one-line title, then the main column (review, uploads, tiles, courses
    /// grid, trial) and, when open, the "Bugünün planı" column.
    private var wideLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    profileButton
                    Spacer()
                    wideRoundButtons
                }
                (Text("\(t("home.k599")) ").foregroundStyle(KPhone.text3) + Text(t("home.k2555")).foregroundStyle(KPhone.text))
                    .font(KFont.ui(44, .medium, lang: lang))
                    .kTracking(-0.03, size: 44, lang: lang)
                    .accessibilityAddTraits(.isHeader)
                if offline { offlineBanner }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        review
                        wideUploads
                        wideTiles
                        HStack(alignment: .firstTextBaseline) {
                            (Text(prefs.d("Derslerim")) + Text(" · \(Format.num(courses.count, lang))\(prefs.d(" ders"))").foregroundStyle(KPhone.text3))
                                .font(KFont.ui(22, .medium, lang: lang)).foregroundStyle(KPhone.text)
                            Spacer()
                            Button { app.go(.courses) } label: {
                                Text(t("padCoursesLink")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.navActive)
                            }
                        }
                        .padding(.top, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: planOpen ? 2 : 3), spacing: 14) {
                            ForEach(courses) { c in courseTile(c) }
                        }
                        TrialCardView(status: trial.status, onPremium: { app.go(.paywall(nil)) })
                    }
                    .frame(maxWidth: .infinity)
                    if planOpen {
                        planColumn.frame(width: 340)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.leading, 8).padding(.trailing, planOpen ? 32 : 76)
            .padding(.top, KLayout.top(54, minimum: 10) + 8).padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    /// Bell and assistant (the iPad header order of the design).
    private var wideRoundButtons: some View {
        HStack(spacing: 10) {
            Button { app.go(.notifications) } label: {
                KIcon(name: .bell, size: 20, width: 1.6)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 48, height: 48)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if unread { Circle().fill(KPhone.dot).frame(width: 8, height: 8).padding(.top, 12).padding(.trailing, 13) }
                    }
            }
            .accessibilityLabel(t("home.k504"))
            Button { app.go(.assistant) } label: {
                Image("StarButton").resizable().scaledToFit().frame(width: 42, height: 42)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(RadialGradient(colors: [Color(hex: 0xB8404D), Color(hex: 0x9C2F3A), Color(hex: 0x7A2230)],
                                                             center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 32)))
                    .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 9, y: 6)
            }
            .accessibilityLabel(t("home.k390"))
        }
    }

    /// The four upload buttons as one row of pills (icon and word side by side).
    private var wideUploads: some View {
        func open(_ kind: UploadKind) -> () -> Void {
            { if offline { toast.show(t("home.uploadOffline")) } else { trial.perform(.pdf) { app.go(.upload(kind)) } } }
        }
        let items: [(KIconName, String, () -> Void)] = [
            (.upload, t("home.k1586"), open(.pdf)), (.camera, t("home.k1013"), open(.photo)), (.mic, t("home.k1832"), open(.audio)),
            (.help, t("home.k1905"), { offline ? toast.show(t("home.uploadOffline")) : app.go(.samples(nil)) }),
        ]
        return HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button(action: item.2) {
                    HStack(spacing: 8) {
                        KIcon(name: item.0, size: 18, width: 1.7)
                        Text(item.1).font(KFont.ui(14, i == 0 ? .medium : .regular, lang: lang)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(i == 0 ? KPhone.ctaText : KPhone.text)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(i == 0 ? KPhone.navActive : KPhone.card, in: Capsule())
                    .overlay(Capsule().stroke(i == 0 ? .clear : KPhone.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var wideTiles: some View {
        let items: [(KIconName, String, Color, Color)] = [
            (.checklist, "home.tileExam", KPhone.tile1, KPhone.tile1Text),
            (.cards, "home.tileCards", KPhone.tile2, KPhone.tile2Text),
            (.book, "home.tileSummary", KPhone.tile3, KPhone.tile3Text),
        ]
        return HStack(spacing: 12) {
            ForEach(items, id: \.1) { icon, key, chip, fg in
                Button { tileTapped(key) } label: {
                    HStack(spacing: 10) {
                        KIcon(name: icon, size: 20, width: 1.6).foregroundStyle(fg)
                            .frame(width: 44, height: 44).background(chip, in: Circle())
                        // Two lines when the plan panel narrows the tiles, so the name is never cut ("Sınav mer…").
                        Text(t(key)).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                            .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .kPhoneCard(radius: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One course in the grid: name, exam, how much of its PDFs is read.
    private func courseTile(_ c: Course) -> some View {
        let stats = CoursesAPI.stats(c)
        let (chipBg, chipFg) = chipColors(c.color)
        return Button { app.go(.course(c.id)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(Format.num(c.pdfs.count, lang)) PDF").font(KFont.mono(10, .medium)).foregroundStyle(chipFg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(chipBg, in: Capsule())
                Text(c.name[lang]).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    .lineLimit(2).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                Text(studyDuration(stats.minutes, prefs)).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                Capsule().fill(KPhone.sub).frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(KPhone.navActive).frame(width: g.size.width * CGFloat(stats.percent) / 100) }
                    }
                Text(Format.percent(stats.percent, lang)).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2)
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .top)
            .kPhoneCard(radius: 24)
        }
        .buttonStyle(.plain)
    }

    /// "Bugünün planı": today's tasks, the next exam, tomorrow's classes and the sample-questions shortcut.
    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                (Text("\(t("home.p0a")) ").foregroundStyle(KPhone.text) + Text(t("home.p0b")).foregroundStyle(KPhone.text3))
                    .font(KFont.ui(21, .medium, lang: lang))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { app.go(.weekPlan) } label: {
                    Text(t("home.k1116")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
                }
                Button { withAnimation(.easeOut(duration: 0.25)) { planOpen = false } } label: {
                    KIcon(name: .close, size: 14, width: 2.2).foregroundStyle(KPhone.text2)
                        .frame(width: 38, height: 38).background(KPhone.card, in: Circle())
                        .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                }
                .accessibilityLabel(t("home.k616"))
            }
            if todayTasks.isEmpty {
                Text(t("plan.empty")).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text2)
            }
            ForEach(todayTasks) { item in
                let look = item.look
                let done = item.status == "done"
                HStack(spacing: 12) {
                    Button { openTask(item) } label: {
                        HStack(spacing: 12) {
                            KIcon(name: look.icon, size: 18, width: 1.6).foregroundStyle(look.fg)
                                .frame(width: 42, height: 42).background(look.chip, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                                    .strikethrough(done).lineLimit(2).multilineTextAlignment(.leading)
                                Text([t("plan.min", ["m": Format.num(item.minutes, lang)]), item.why].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    PlanCheck(done: done, title: item.title) { toggleDone(item) }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .kPhoneCard(radius: 22)
                .opacity(done ? 0.6 : 1)
            }
            examCard
            Button { app.go(.timetable) } label: {
                shortcutRow(.calendar,
                            top: tomorrowClasses.isEmpty ? t("padNoClassesTmr") : t("padClassesTmr", ["n": Format.num(tomorrowClasses.count, lang)]),
                            title: tomorrowClasses.first.map { "\(Format.num($0.start, lang)) · \($0.title)" } ?? t("schTitle"))
                    .kPhoneCard(radius: 24)
            }
            .buttonStyle(.plain)
            Button { app.go(.samples(nil)) } label: {
                HStack(spacing: 14) {
                    KIcon(name: .help, size: 21, width: 1.7).foregroundStyle(KPhone.tile4Text)
                        .frame(width: 50, height: 50).background(KPhone.tile4, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prefs.d("Elinde soru var mı?")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        Text(t("padSamplesSub")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(KPhone.bannerLine, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
            }
            .buttonStyle(.plain)
        }
    }

    /// Days to the nearest exam of the student's courses (opens the exam center).
    private var examCard: some View {
        let today = CoursesAPI.todayISO()
        let next = courses.compactMap { c in c.examDate.map { (c, $0) } }.filter { $0.1 >= today }.min { $0.1 < $1.1 }
        return Button { app.go(.examCenter) } label: {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(next.map { Format.num(CoursesAPI.daysUntil($0.1), lang) } ?? "–").font(KFont.ui(20, .bold, lang: lang))
                    Text(prefs.d("GÜN")).font(KFont.ui(9, .semibold, lang: lang))
                }
                .foregroundStyle(KPhone.ctaText)
                .frame(width: 56, height: 56).background(Color.white.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(next.map { "\($0.0.name[lang]) · \($0.0.exam[lang])" } ?? t("padNoExam"))
                        .font(KFont.ui(16, .semibold, lang: lang)).lineLimit(2).multilineTextAlignment(.leading)
                    Text(t("padExamSoon")).font(KFont.ui(12, lang: lang)).opacity(0.8)
                }
                .foregroundStyle(KPhone.ctaText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(KPhone.navActive, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shortcutRow(_ icon: KIconName, top: String, title: String) -> some View {
        HStack(spacing: 12) {
            KIcon(name: icon, size: 20, width: 1.7).foregroundStyle(KPhone.tile4Text)
                .frame(width: 46, height: 46).background(KPhone.tile4, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(top).font(KFont.mono(10, .regular)).kTracking(0.06, size: 10, lang: lang).foregroundStyle(KPhone.text2)
                Text(title).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            KIcon(name: .chevron, size: 14, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
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

    /// A plan task opens where it is done (the lesson, its exam or the cards). It is not ticked: the student does that.
    private func openTask(_ task: PlanTask) {
        planOpen = false
        app.go(task.route)
    }

    /// The student ticks a task as done, or takes the tick back.
    private func toggleDone(_ task: PlanTask) {
        guard let i = todayTasks.firstIndex(where: { $0.id == task.id }) else { return }
        let done = todayTasks[i].status != "done"
        todayTasks[i].status = done ? "done" : "todo"
        Task { await PlanAPI.setDone(task.id, done) }
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
