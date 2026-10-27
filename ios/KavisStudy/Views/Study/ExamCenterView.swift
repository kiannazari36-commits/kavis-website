import SwiftUI

/// Design: design/ScrReview.dc.html, variants "exam" / "examAll" / "setWeek" ("Sınav merkezi", from the home tile).
/// The exam week from the courses' exam days (with "Değiştir" to set it), an exam of one course or of several, the
/// number of questions and "Zayıf konulara ağırlık ver". The server puts the exam together from the questions already
/// written for the student's lessons (Edge Function build-exam, no AI); it is played in the quiz screen and graded
/// like any quiz. The design's dark exam card is bordo in light mode (CLAUDE.md: no very dark boxes in light mode).
struct ExamCenterView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    private enum Mode { case course, all }

    @State private var courses: [Course] = []
    @State private var exams: [CourseExam] = []
    @State private var ready: [String: Int] = [:]
    @State private var loaded = false
    @State private var mode: Mode = .course
    @State private var selected: String?
    @State private var allSelected: Set<String> = []
    @State private var count = 40
    @State private var weakFocus = true
    @State private var building = false
    @State private var weekOpen = false

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }

    fileprivate enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let sub = Color.pair(0xF1EBE0, 0x2B2520)
        static let seg = Color.pair(0xFFFCF6, 0x463D35)
        static let text = Color.pair(0x2A2420, 0xEFE8DC)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let pri = Color.pair(0x9C2F3A, 0xB23A47)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
        static let ambText = Color.pair(0x83560A, 0xF2C46E)
        static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
        static let examBg = Color.pair(0x9C2F3A, 0x2E2721)
        static let onDark = Color(hex: 0xFFFCF6)
    }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        weekCard
                        modes
                        courseList
                        optionsCard
                        startButton
                    }
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            if weekOpen {
                ExamWeekSheet(courses: courses, exams: exams, current: week?.kind ?? .midterm, onClose: { weekOpen = false }) { saved in
                    weekOpen = false
                    if saved { Task { exams = await ExamsAPI.upcoming() } }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: weekOpen)
        .task {
            guard !loaded else { return }
            loaded = true
            async let c = CoursesAPI.listCourses()
            async let e = ExamsAPI.upcoming()
            async let r = ExamsAPI.readyQuestions()
            courses = await c
            exams = await e
            ready = await r
            // The course with the nearest exam is chosen first.
            selected = exams.first.map(\.courseId) ?? courses.first?.id
            allSelected = Set(courses.map(\.id))
        }
    }

    // MARK: Week

    /// The coming exam week: the kind of the nearest exam and the days of that kind close to it.
    private var week: (kind: CourseExam.Kind, from: String, to: String)? { Self.week(of: exams) }

    static func week(of exams: [CourseExam]) -> (kind: CourseExam.Kind, from: String, to: String)? {
        guard let first = exams.first else { return nil }
        let limit = day(first.date).flatMap { Calendar.current.date(byAdding: .day, value: 21, to: $0) }
        let same = exams.filter { $0.kind == first.kind && (day($0.date).map { limit == nil || $0 <= limit! } ?? false) }
        return (first.kind, first.date, same.map(\.date).max() ?? first.date)
    }

    static func day(_ iso: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)
    }

    static func kindName(_ k: CourseExam.Kind, _ prefs: AppPrefs) -> String {
        switch k {
        case .midterm: prefs.d("Vize")
        case .final: prefs.d("Final")
        case .makeup: prefs.d("Bütünleme")
        }
    }

    /// "19–23 Ekim" / "30 Eki – 3 Kas".
    static func range(_ from: String, _ to: String, _ lang: Lang) -> String {
        guard let a = day(from), let b = day(to) else { return "" }
        let f = DateFormatter()
        f.locale = lang.locale
        if a == b { f.setLocalizedDateFormatFromTemplate("dMMMM"); return Format.num(f.string(from: a), lang) }
        let cal = Calendar.current
        if cal.component(.month, from: a) == cal.component(.month, from: b) {
            f.setLocalizedDateFormatFromTemplate("MMMM")
            let n = { Format.num(cal.component(.day, from: $0), lang) }
            return lang == .en ? "\(f.string(from: a)) \(n(a))–\(n(b))" : "\(n(a))–\(n(b)) \(f.string(from: a))"
        }
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return Format.num("\(f.string(from: a)) – \(f.string(from: b))", lang)
    }

    fileprivate static func shortDay(_ iso: String, _ lang: Lang) -> String {
        guard let d = day(iso) else { return "" }
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return Format.num(f.string(from: d), lang)
    }

    private var daysLeft: Int? {
        guard let w = week else { return nil }
        return max(0, CoursesAPI.daysUntil(w.from))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            Button { app.back() } label: {
                KIcon(name: .chevronLeft, size: 24, width: 1.8, flipsInRTL: true).foregroundStyle(C.text).frame(width: 44, height: 44)
            }
            .accessibilityLabel(d("Geri"))
            VStack(alignment: .leading, spacing: 1) {
                Text(d("Sınav merkezi")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(C.text)
                HStack(spacing: 6) {
                    Text(d(week?.kind == .midterm || week == nil ? "VİZE HAFTASINA HAZIRLIK" : "SINAV HAFTASI"))
                        .font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(C.text3).lineLimit(1)
                    HStack(spacing: 4) {
                        KIcon(name: .star, size: 9, width: 0).foregroundStyle(Color(hex: 0xE39A26))
                        Text(d("Hocanın tarzında")).font(KFont.ui(9, .semibold, lang: lang)).foregroundStyle(C.text2)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(hex: 0xF2B33D, opacity: 0.2), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
        .padding(.top, KLayout.top(54, minimum: 6))
        .padding(.bottom, 10)
    }

    // MARK: Cards

    private var weekCard: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(daysLeft.map { Format.num($0, lang) } ?? "–").font(KFont.ui(40, .bold, lang: lang)).kTracking(-0.03, size: 40, lang: lang)
                Text(d("GÜN KALDI")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8).opacity(0.85)
            }
            .frame(width: 74)
            VStack(alignment: .leading, spacing: 3) {
                Text(d("SINAV HAFTASI")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(Color(hex: 0xF2B33D))
                if let w = week {
                    Text("\(Self.kindName(w.kind, prefs)) · \(Self.range(w.from, w.to, lang))").font(KFont.ui(16, .bold, lang: lang))
                    Text(d("Takviminden alındı")).font(KFont.ui(12, lang: lang)).opacity(0.85)
                } else {
                    Text(d("Sınav haftanı gir")).font(KFont.ui(16, .bold, lang: lang))
                    Text(d("Uygulama hatırlatmaları ve sınavları buna göre hazırlar.")).font(KFont.ui(12, lang: lang)).opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { weekOpen = true } label: {
                Text(d("Değiştir")).font(KFont.ui(12, .semibold, lang: lang)).foregroundStyle(C.onDark)
                    .padding(.horizontal, 12).frame(height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(C.onDark)
        .padding(16)
        .background(C.examBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var modes: some View {
        HStack(spacing: 10) {
            modeButton(.course, d("Derse özel sınav"), d("Tek bir ders, ör. yalnızca Toksikoloji"), icon: .book)
            modeButton(.all, d("Genel sınav"), d("Bu dönemin tüm derslerinden tek sınav"), icon: .list)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(d("Sınav türü"))
    }

    private func modeButton(_ m: Mode, _ title: String, _ sub: String, icon: KIconName) -> some View {
        let on = mode == m
        return Button {
            mode = m
            count = m == .all ? 60 : 40
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                KIcon(name: icon, size: 17, width: 1.8).foregroundStyle(on ? C.onDark : C.text2)
                    .frame(width: 32, height: 32).background(on ? C.pri : C.sub, in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(-8))
                Text(title).font(KFont.ui(14, .bold, lang: lang)).foregroundStyle(C.text).multilineTextAlignment(.leading)
                Text(sub).font(KFont.ui(11, lang: lang)).foregroundStyle(C.text3).multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(on ? C.priSoft : C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? C.pri : C.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func examDay(_ course: Course) -> String? {
        let mine = exams.filter { $0.courseId == course.id }
        return (mine.first { $0.kind == week?.kind } ?? mine.first)?.date
    }

    private var courseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(d(mode == .all ? "SINAVA GİRECEK DERSLER" : "BİR DERS SEÇ"))
                .font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.text3)
                .padding(.top, 8).padding(.bottom, 4)
            ForEach(courses) { course in
                let on = mode == .all ? allSelected.contains(course.id) : selected == course.id
                Button {
                    if mode == .all {
                        if on { allSelected.remove(course.id) } else { allSelected.insert(course.id) }
                    } else {
                        selected = course.id
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: mode == .all ? 6 : 11)
                                .fill(on ? C.pri : .clear)
                                .overlay(RoundedRectangle(cornerRadius: mode == .all ? 6 : 11).stroke(on ? .clear : C.text3, lineWidth: 1.5))
                            if on { KIcon(name: .check, size: 12, width: 3).foregroundStyle(C.onDark) }
                        }
                        .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.name[lang]).font(KFont.ui(14, .semibold, lang: .tr)).foregroundStyle(C.text)
                            Text("\(Format.num(course.pdfs.count, lang)) PDF · \(Format.num(ready[course.id] ?? 0, lang)) \(d("soru hazır"))")
                                .font(KFont.mono(10, .regular)).foregroundStyle(C.text3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let day = examDay(course) {
                            Text(Self.shortDay(day, lang)).font(KFont.mono(11, .regular))
                                .foregroundStyle(on ? C.ambText : C.text2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(on ? C.ambSoft : C.sub, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var optionsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(d("Soru sayısı")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach([20, 40, 60], id: \.self) { n in
                        let on = n == count
                        Button { count = n } label: {
                            Text(Format.num(n, lang)).font(KFont.mono(12, .semibold)).foregroundStyle(on ? C.text : C.text2)
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(on ? C.seg : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .shadow(color: on ? .black.opacity(0.12) : .clear, radius: 1.5, y: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(3)
                .background(C.sub, in: RoundedRectangle(cornerRadius: 10))
            }
            Rectangle().fill(C.line).frame(height: 1)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(d("Zayıf konulara ağırlık ver")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text)
                    Text(d("Soruların yarısı zayıf konulardan gelir")).font(KFont.ui(11, lang: lang)).foregroundStyle(C.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { weakFocus.toggle() } label: {
                    Capsule().fill(weakFocus ? C.pri : Color.pair(0xDDD2C1, 0x463D35)).frame(width: 46, height: 28)
                        .overlay(alignment: weakFocus ? .trailing : .leading) {
                            Circle().fill(C.onDark).frame(width: 22, height: 22).padding(3)
                        }
                        .animation(.easeInOut(duration: 0.15), value: weakFocus)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(d("Zayıf konulara ağırlık ver"))
                .accessibilityValue(weakFocus ? "1" : "0")
                .accessibilityAddTraits(.isToggle)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var chosenIds: [String] {
        mode == .all ? courses.map(\.id).filter(allSelected.contains) : selected.map { [$0] } ?? []
    }

    private var startLabel: String {
        if mode == .all { return d("Genel sınavı başlat") }
        let name = courses.first { $0.id == selected }?.name[lang] ?? ""
        return name + d(" sınavını başlat")
    }

    private var startButton: some View {
        Button { Task { await start() } } label: {
            Text(building ? prefs.t("packMaking") : startLabel)
                .font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(C.onDark)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(chosenIds.isEmpty ? 0.5 : 1)
        }
        .disabled(building || chosenIds.isEmpty)
    }

    private func start() async {
        building = true
        defer { building = false }
        switch await ExamsAPI.build(courseIds: chosenIds, count: count, weakFocus: weakFocus) {
        case .ok(let id): app.go(.quiz(QuizTarget(materialId: "", kind: .exam, quizId: id)))
        case .empty: toast.show(prefs.t("quiz.none"))
        case .failed: toast.show(prefs.t("errOther"))
        }
    }
}

/// "Sınav haftanı gir" (design ScrReview "setWeek"): the exam kind, the week on the calendar and each course's day.
private struct ExamWeekSheet: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast
    typealias C = ExamCenterView.C

    let courses: [Course]
    let exams: [CourseExam]
    let current: CourseExam.Kind
    var onClose: () -> Void
    var onDone: (Bool) -> Void

    @State private var kind: CourseExam.Kind = .midterm
    @State private var month = Date()
    @State private var from: Date?
    @State private var to: Date?
    /// Course id → its day in the week.
    @State private var days: [String: Date] = [:]
    @State private var saving = false
    @State private var ready = false

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.pair(0x12171E, 0x000000).opacity(0.5).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(C.line).frame(width: 36, height: 5).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d("Sınav haftanı gir")).font(KFont.ui(19, .bold, lang: lang)).foregroundStyle(C.text)
                    Text(d("Uygulama hatırlatmaları ve sınavları buna göre hazırlar.")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text3)
                }
                kinds
                monthHeader
                calendar
                perCourse
                Button { Task { await save() } } label: {
                    Text(d("Kaydet")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(C.onDark)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .opacity(from == nil || saving ? 0.5 : 1)
                }
                .disabled(from == nil || saving)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 30)
            .background(C.card, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear(perform: prepare)
    }

    /// Starts from the current week of this kind (or empty, this month).
    private func prepare() {
        guard !ready else { return }
        ready = true
        kind = current
        load(kind)
    }

    private func load(_ k: CourseExam.Kind) {
        let mine = exams.filter { $0.kind == k }
        let dates = mine.compactMap { ExamCenterView.day($0.date) }
        from = dates.min()
        to = dates.max()
        month = from ?? Date()
        days = Dictionary(mine.compactMap { e in ExamCenterView.day(e.date).map { (e.courseId, $0) } }, uniquingKeysWith: { a, _ in a })
    }

    private var kinds: some View {
        HStack(spacing: 4) {
            ForEach(CourseExam.Kind.allCases, id: \.self) { k in
                let on = k == kind
                Button { kind = k; load(k) } label: {
                    Text(ExamCenterView.kindName(k, prefs)).font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                        .foregroundStyle(on ? C.text : C.text2)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(on ? C.card : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: on ? .black.opacity(0.12) : .clear, radius: 1.5, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(C.sub, in: RoundedRectangle(cornerRadius: 10))
    }

    private func iso(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private var monthHeader: some View {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return HStack(spacing: 6) {
            Button { month = cal.date(byAdding: .month, value: -1, to: month) ?? month } label: {
                KIcon(name: .chevronLeft, size: 16, width: 2, flipsInRTL: true).foregroundStyle(C.text2).frame(width: 28, height: 28)
            }
            Text(Format.num(f.string(from: month), lang)).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(C.text)
            Button { month = cal.date(byAdding: .month, value: 1, to: month) ?? month } label: {
                KIcon(name: .chevron, size: 16, width: 2, flipsInRTL: true).foregroundStyle(C.text2).frame(width: 28, height: 28)
            }
            Spacer()
            if let from {
                Text(ExamCenterView.range(iso(from), iso(to ?? from), lang)).font(KFont.mono(11, .regular)).foregroundStyle(C.priText)
            }
        }
    }

    private var calendar: some View {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<count).map { cal.date(byAdding: .day, value: $0, to: first) }
        let letters = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(letters, id: \.self) { Text(d($0)).font(KFont.mono(10, .regular)).foregroundStyle(C.text3) }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day) } else { Color.clear.frame(height: 36) }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func dayCell(_ day: Date) -> some View {
        let start = from.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let end = (to ?? from).map { cal.isDate($0, inSameDayAs: day) } ?? false
        let inside = from.map { f in day >= cal.startOfDay(for: f) && day <= cal.startOfDay(for: to ?? f) } ?? false
        let edge = start || end
        return Button { tap(day) } label: {
            Text(Format.num(cal.component(.day, from: day), lang))
                .font(KFont.ui(13, inside ? .bold : .medium, lang: lang))
                .foregroundStyle(edge ? C.onDark : inside ? C.priText : C.text)
                .frame(width: 32, height: 32)
                .background(edge ? C.pri : .clear, in: Circle())
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: start ? 16 : 0, bottomLeadingRadius: start ? 16 : 0,
                                           bottomTrailingRadius: end ? 16 : 0, topTrailingRadius: end ? 16 : 0)
                        .fill(inside ? C.priSoft : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    /// First tap: the first day; second tap: the last day; a tap after that starts again.
    private func tap(_ day: Date) {
        if let f = from, to == nil, day >= f {
            to = day
        } else {
            from = day
            to = nil
        }
        // Every course gets a day inside the new week (the first day unless it already has one there).
        guard let f = from else { return }
        let last = to ?? f
        for c in courses where !(days[c.id].map { $0 >= f && $0 <= last } ?? false) { days[c.id] = f }
    }

    /// The days of the week, for a course's chip (tap moves to the next day).
    private func next(after day: Date) -> Date {
        guard let f = from else { return day }
        let last = to ?? f
        let n = cal.date(byAdding: .day, value: 1, to: day) ?? day
        return n > last ? f : n
    }

    private var perCourse: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(C.line).frame(height: 1)
            Text(d("DERS BAZINDA SINAV GÜNLERİ")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.text3)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(courses) { c in
                    Button { if let day = days[c.id] { days[c.id] = next(after: day) } } label: {
                        HStack(spacing: 4) {
                            Text(c.short?[lang] ?? c.name[lang]).lineLimit(1)
                            Text(days[c.id].map { ExamCenterView.shortDay(iso($0), lang) } ?? "–").bold()
                        }
                        .font(KFont.ui(12, lang: .tr)).foregroundStyle(C.text)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(C.sub, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let picked = Dictionary(uniqueKeysWithValues: days.map { ($0.key, iso($0.value)) })
        if await ExamsAPI.saveWeek(kind: kind, days: picked, existing: exams) {
            onDone(true)
        } else {
            toast.show(prefs.t("errOther"))
        }
    }
}
