import SwiftUI

/// Design: design/NewPlacement.dc.html ("Seviye tespiti"; iPad: NewIPad "placement"), opened when an upload is ready:
/// "Have you studied this before?" → no (open the PDF) / a short test / only some topics; then the topic map
/// (known / weak / to study). Same flow and server calls as the web (`web/src/pages/Placement.tsx`): the test is made
/// by the server from the lesson's own questions (no AI); grade-quiz writes the topic states.
struct PlacementView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(\.padRail) private var wide

    let materialId: String

    private enum Stage { case ask, partial, quiz, result }
    private enum Status { case know, weak, new, todo }

    @State private var lesson: PlacementAPI.Lesson?
    @State private var stage: Stage = .ask
    @State private var picked: [String: Bool]?
    @State private var test: PlacementAPI.Test?
    @State private var topicIds: [String]?
    @State private var index = 0
    /// Question id → chosen option, or -1 for "Bilmiyorum".
    @State private var answers: [String: Int] = [:]
    @State private var busy = false
    /// The grading request: the plan waits for it, so the new topic states are in before the plan is made again.
    @State private var grading: Task<Void, Never>?

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }
    private func n(_ v: Int) -> String { Format.num(v, lang) }

    private enum C {
        static let bg = LinearGradient(stops: [.init(color: .pair(0xEDE3D2, 0x1F1A16), location: 0), .init(color: .pair(0xF4EFE6, 0x15120F), location: 0.42)],
                                       startPoint: .top, endPoint: .bottom)
        static let hero = LinearGradient(colors: [.pair(0xFBE9BD, 0x4A3520), .pair(0xF5C76A, 0x6B4A22)], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let onHero = Color.pair(0x2A2420, 0xFBEFD6)
        static let heroShadow = Color(light: Color(hex: 0xE8925A, opacity: 0.22), dark: .clear)
        static let pri = Color(hex: 0x9C2F3A)
        static let onPri = Color(hex: 0xFFFCF6)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF5E3E2, 0x3A2224)
        static let ambFg = Color.pair(0xA86F0E, 0xF2C66D)
        static let ambSoft = Color.pair(0xFBEBC8, 0x3A2E18)
        static let good = Color.pair(0x2E7D4F, 0x8FD3A8)
        static let goodSoft = Color.pair(0xE3F1E7, 0x1F3328)
    }

    private static let letters = ["A", "B", "C", "D", "E", "F"]
    private static let icons = (
        no: "M4 5h6a2 2 0 0 1 2 2v12a2 2 0 0 0-2-2H4z M20 5h-6a2 2 0 0 0-2 2v12a2 2 0 0 1 2-2h6z",
        yes: "M9 11l2 2 4-4 M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
        part: "M9 6h11 M9 12h11 M9 18h11 M4 6l1 1 2-2 M4 12l1 1 2-2 M4 18h2"
    )

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            if wide {
                // Design NewIPad "placement": the page header, the content in a 640 pt column.
                VStack(alignment: .leading, spacing: 16) {
                    PadHeader(title: t("ptTitle"), sub: sub.isEmpty ? nil : "\(sub) \(prefs.d("· bildiğin konuları atlayıp zayıf olanları buluruz"))", onBack: back) {
                        if stage == .quiz { laterButton(height: 42, size: 14) }
                    }
                    ScrollView {
                        VStack(spacing: 14) {
                            content
                            footer
                        }
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
                .padPage()
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) { content }
                            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, stage == .ask || stage == .quiz ? 32 : 16)
                    }
                    .scrollIndicators(.hidden)
                    if stage == .partial || stage == .result {
                        footer.padding(.horizontal, 20).padding(.top, stage == .partial ? 12 : 10).padding(.bottom, 12)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: stage)
        .task { await load() }
    }

    // MARK: Data

    private func load() async {
        guard lesson == nil else { return }
        lesson = await PlacementAPI.lesson(materialId: materialId)
        // A test left with "Sonra devam et" goes on from the same question.
        guard let kept = PlacementAPI.saved(materialId: materialId) else { return }
        guard let q = await PlacementAPI.test(quizId: kept.quizId) else { return PlacementAPI.keep(materialId: materialId, nil) }
        test = q
        topicIds = kept.topicIds
        answers = kept.answers
        index = min(kept.index, q.quiz.questions.count - 1)
        stage = .quiz
    }

    private var topics: [PlacementAPI.Topic] { lesson?.topics ?? [] }
    private func isPicked(_ id: String) -> Bool { picked?[id] ?? true }
    private var questions: [QuizQuestion] { test?.quiz.questions ?? [] }
    private var qLang: Lang { test?.quiz.lang ?? lang }

    private var sub: String {
        guard let lesson else { return "" }
        return "\(lesson.title) · \(t("ptFileSub", ["t": n(topics.count), "p": n(lesson.pages)]))"
    }

    private func pg(_ x: PlacementAPI.Topic) -> String {
        guard let from = x.pageFrom else { return "" }
        if let to = x.pageTo, to != from { return "\(t("pageAbbr")) \(n(from))–\(n(to))" }
        return "\(t("pageAbbr")) \(n(from))"
    }

    /// Reading time of a topic: about 5 minutes a page, at least 5.
    private func minutesOf(_ x: PlacementAPI.Topic) -> Int {
        guard let from = x.pageFrom else { return 10 }
        return max(5, ((x.pageTo ?? from) - from + 1) * 5)
    }

    private func mins(_ m: Int) -> String {
        m >= 60 ? t("ptHM", ["h": n(m / 60), "m": n(m % 60)]) : t("ptM", ["m": n(m)])
    }

    /// The reader in place of this screen (back goes to where the upload started), at a page or from the start.
    private func reader(_ page: Int? = nil) {
        app.readerPage = page
        app.replace(.reader(materialId))
    }

    private func back() {
        if stage == .ask { reader() } else { stage = .ask }
    }

    private func begin(_ ids: [String]?) async {
        guard !busy else { return }
        busy = true
        let r = await PlacementAPI.start(materialId: materialId, topicIds: ids)
        busy = false
        switch r {
        case .none:
            toast.show(t("ptNoQ"))
            reader()
        case .failed:
            toast.show(t("ptFailed"))
        case .ok(let q):
            test = q
            topicIds = ids
            answers = [:]
            index = 0
            stage = .quiz
        }
    }

    private func answer(_ v: Int) {
        guard let test, index < questions.count else { return }
        answers[questions[index].id] = v
        if index < questions.count - 1 { index += 1; return }
        PlacementAPI.keep(materialId: materialId, nil)
        let given = questions.map { q in
            let a = answers[q.id] ?? -1
            return QuizAPI.Answer(questionId: q.id, chosen: a < 0 ? nil : a, hints: 0, confidence: nil, dontKnow: a < 0)
        }
        let quizId = test.quiz.id
        grading = Task { _ = await QuizAPI.saveAttempt(quizId: quizId, answers: given) }
        stage = .result
        toast.show(t("ptDone"))
    }

    private func later() {
        if let test { PlacementAPI.keep(materialId: materialId, .init(quizId: test.quiz.id, topicIds: topicIds, index: index, answers: answers)) }
        toast.show(t("ptSaved"))
        reader()
    }

    private func updatePlan() async {
        guard !busy else { return }
        busy = true
        await grading?.value
        await PlanAPI.runPlanner("build")
        busy = false
        toast.show(t("ptPlanned"))
        app.replace(.weekPlan)
    }

    private struct Row { let x: PlacementAPI.Topic; let st: Status; let min: Int; let act: String }

    /// The topic map: every topic of the lesson, from this test's answers (same rules as the server).
    private var results: [Row] {
        topics.map { x in
            let asked = questions.filter { test?.topicOf[$0.id] == x.id }
            let right = asked.filter { answers[$0.id] == $0.answer }.count
            let st: Status = asked.isEmpty ? .todo : right == asked.count ? .know : right == 0 ? .new : .weak
            let m = minutesOf(x)
            let act = switch st {
            case .know: t("ptActKnow")
            case .weak: t("ptActWeak")
            case .new: t("ptActNew", ["pg": pg(x), "m": n(m)])
            case .todo: t("ptActTodo", ["pg": pg(x), "m": n(m)])
            }
            return Row(x: x, st: st, min: st == .know ? 0 : st == .weak ? 10 : m, act: act)
        }
    }

    private func startRed() {
        let res = results
        let first = res.first { $0.st == .new || $0.st == .todo } ?? res.first { $0.st == .weak } ?? res.first
        if let first { toast.show(t("ptStartT", ["t": first.x.title])) }
        reader(first?.x.pageFrom)
    }

    private func again() {
        stage = .ask
        answers = [:]
        index = 0
        test = nil
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: back) {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("signup.k1052"))
            VStack(alignment: .leading, spacing: 1) {
                Text(t("ptTitle")).font(KFont.ui(18, .semibold, lang: lang)).foregroundStyle(KPhone.text).accessibilityAddTraits(.isHeader)
                Text(sub).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if stage == .quiz { laterButton(height: 38, size: 13) }
        }
        .padding(.horizontal, 20).padding(.top, KLayout.top(54, minimum: 6) + 6).padding(.bottom, 12)
    }

    private func laterButton(height: CGFloat, size: CGFloat) -> some View {
        Button(action: later) {
            Text(t("ptLater")).font(KFont.ui(size, lang: lang)).foregroundStyle(KPhone.text)
                .padding(.horizontal, height == 42 ? 16 : 14).frame(height: height)
                .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Stages

    @ViewBuilder private var content: some View {
        switch stage {
        case .ask: askStage
        case .partial: partialStage
        case .quiz: quizStage
        case .result: resultStage
        }
    }

    @ViewBuilder private var footer: some View {
        switch stage {
        case .partial:
            let ids = topics.filter { isPicked($0.id) }.map(\.id)
            priButton(t("ptPickGo", ["n": n(PlacementAPI.questionCount(topics.filter { isPicked($0.id) }))]), height: 58) {
                if ids.isEmpty { return toast.show(t("ptPickOne")) }
                Task { await begin(ids) }
            }
        case .result:
            VStack(spacing: 10) {
                priButton(t("ptPlan"), height: 56) { Task { await updatePlan() } }
                Button(action: startRed) {
                    Text(t("ptStart")).font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(KPhone.card, in: Capsule())
                        .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        default: EmptyView()
        }
    }

    private func priButton(_ label: String, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(label).font(KFont.ui(17, .medium, lang: lang)).foregroundStyle(C.onPri).opacity(busy ? 0 : 1)
                if busy { SwiftUI.ProgressView().tint(C.onPri) }
            }
            .frame(maxWidth: .infinity).frame(height: height)
            .background(C.pri, in: Capsule())
            .shadow(color: C.pri.opacity(0.24), radius: 15, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var askStage: some View {
        let allN = PlacementAPI.questionCount(topics)
        let opts: [(k: String, d: String, title: String, sub: String, tap: () -> Void)] = [
            ("no", Self.icons.no, t("ptNoT"), t("ptNoS"), { toast.show(t("ptOpening")); reader() }),
            ("yes", Self.icons.yes, t("ptYesT"), t("ptYesS", ["n": n(allN), "m": n(max(1, Int((Double(allN) * 0.6).rounded(.up))))]), { Task { await begin(nil) } }),
            ("part", Self.icons.part, t("ptPartT"), t("ptPartS"), { stage = .partial }),
        ]
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image("StarButton").resizable().scaledToFit().frame(width: 49, height: 49)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(RadialGradient(colors: [Color(hex: 0xB8404D), C.pri, Color(hex: 0x7A2230)],
                                                             center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 40)))
                    .accessibilityHidden(true)
                Text(t("ptAskT")).font(KFont.ui(24, .semibold, lang: lang)).kTracking(-0.02, size: 24, lang: lang)
                Text(t("ptAskS")).font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).opacity(0.85)
            }
            .foregroundStyle(C.onHero)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(C.hero, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: C.heroShadow, radius: 15, y: 14)
            ForEach(opts, id: \.k) { o in
                let pri = o.k == "yes"
                Button(action: o.tap) {
                    HStack(spacing: 14) {
                        ZStack {
                            if pri && busy { SwiftUI.ProgressView().tint(C.onPri) } else {
                                SVGShape(d: o.d).stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)).frame(width: 21, height: 21)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(pri ? Color(hex: 0xFFFCF6, opacity: 0.16) : KPhone.sub, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(o.title).font(KFont.ui(16, .semibold, lang: lang))
                            Text(o.sub).font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang)
                                .foregroundStyle(pri ? Color(hex: 0xFFFCF6, opacity: 0.82) : KPhone.text2)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(pri ? C.onPri : KPhone.text)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(pri ? C.pri : KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(pri ? .clear : KPhone.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                KIcon(name: .lock, size: 14, width: 1.8)
                Text(t("ptPrivate")).font(KFont.ui(12, lang: lang))
            }
            .foregroundStyle(KPhone.text2).padding(.horizontal, 4).padding(.vertical, 2)
        }
    }

    private var partialStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("ptPickT")).font(KFont.ui(22, .semibold, lang: lang)).kTracking(-0.01, size: 22, lang: lang).foregroundStyle(KPhone.text)
            Text(t("ptPickS")).font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(KPhone.text2).padding(.top, -6)
            VStack(spacing: 0) {
                ForEach(topics) { x in
                    let on = isPicked(x.id)
                    Button {
                        var next = picked ?? Dictionary(uniqueKeysWithValues: topics.map { ($0.id, true) })
                        next[x.id] = !on
                        picked = next
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? C.pri : .clear)
                                if on { KIcon(name: .check, size: 15, width: 3).foregroundStyle(C.onPri) } else {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(KPhone.line, lineWidth: 1.5)
                                }
                            }
                            .frame(width: 26, height: 26)
                            Text(x.title).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                            Text(pg(x)).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2)
                        }
                        .padding(.vertical, 8).frame(minHeight: 56)
                        .overlay(alignment: .bottom) { KPhone.line.frame(height: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        }
    }

    @ViewBuilder private var quizStage: some View {
        if index < questions.count {
            let q = questions[index]
            let total = questions.count
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    HStack {
                        Text(t("ptQ", ["i": n(index + 1), "n": n(total)]))
                        Spacer()
                        Text(t("ptLeft", ["m": n(max(1, Int((Double(total - index) * 0.6).rounded(.up))))]))
                    }
                    .font(KFont.mono(11, .regular)).tracking(lang.isRTL ? 0 : 0.66).foregroundStyle(KPhone.text2)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(KPhone.seg)
                            Capsule().fill(C.pri).frame(width: g.size.width * CGFloat(index) / CGFloat(max(total, 1)))
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                }
                let tag = [test?.topicTitle[q.id] ?? "", q.page.map { "\(t("pageAbbr")) \(n($0))" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
                if !tag.isEmpty {
                    Text(tag).font(KFont.ui(12, .semibold, lang: qLang)).foregroundStyle(C.ambFg)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(C.ambSoft, in: Capsule())
                        .environment(\.layoutDirection, qLang.layoutDirection)
                }
                Text(q.text).font(KFont.reading(21, .medium, lang: qLang)).kLineHeight(1.4, size: 21, lang: qLang).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, qLang.layoutDirection)
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, o in
                    Button { answer(i) } label: {
                        Text("\(Self.letters[min(i, Self.letters.count - 1)])) \(o)").font(KFont.ui(15, lang: qLang)).foregroundStyle(KPhone.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .environment(\.layoutDirection, qLang.layoutDirection)
                }
                Button { answer(-1) } label: {
                    Text(t("ptIdk")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().strokeBorder(KPhone.text2, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                Text(t("ptDontGuess")).font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text2)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 10)
            }
            .id(q.id)
        }
    }

    private var resultStage: some View {
        let res = results
        let cnt = { (k: [Status]) in res.filter { k.contains($0.st) }.count }
        let total = topics.reduce(0) { $0 + minutesOf($1) }
        let mine = res.reduce(0) { $0 + $1.min }
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("ptMap")).font(KFont.ui(13, .semibold, lang: lang)).opacity(0.8)
                HStack(spacing: 8) {
                    count(cnt([.know]), t("ptKnowL"), C.good)
                    count(cnt([.weak]), t("ptWeakL"), C.ambFg)
                    count(cnt([.new, .todo]), t("ptTodoL"), C.priText)
                }
                Text(t("ptTime", ["a": mins(total), "b": mins(mine)])).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang)
            }
            .foregroundStyle(C.onHero)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 18)
            .background(C.hero, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: C.heroShadow, radius: 15, y: 14)
            ForEach(res, id: \.x.id) { r in resultRow(r) }
            Button(action: again) {
                Text(t("ptAgain")).font(KFont.ui(13, lang: lang)).underline().foregroundStyle(KPhone.text2)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    private func count(_ v: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n(v)).font(KFont.ui(26, .bold, lang: lang)).foregroundStyle(color)
            Text(label).font(KFont.ui(12, lang: lang)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(KPhone.heroChip, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func resultRow(_ r: Row) -> some View {
        let (bg, fg, label, mark): (Color, Color, String, String) = switch r.st {
        case .know: (C.goodSoft, C.good, t("ptStKnow"), "M5 12l5 5 9-10")
        case .weak: (C.ambSoft, C.ambFg, t("ptStWeak"), "M12 8v5 M12 16h.01")
        case .new: (C.priSoft, C.priText, t("ptStNew"), "M6 6l12 12 M18 6L6 18")
        case .todo: (C.priSoft, C.priText, t("ptStTodo"), "M6 6l12 12 M18 6L6 18")
        }
        return HStack(spacing: 12) {
            SVGShape(d: mark).stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)).frame(width: 17, height: 17)
                .foregroundStyle(fg)
                .frame(width: 36, height: 36).background(bg, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(r.x.title).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(label).font(KFont.ui(11, .semibold, lang: lang)).foregroundStyle(fg)
                }
                Text(r.act).font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang).foregroundStyle(KPhone.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
    }
}
