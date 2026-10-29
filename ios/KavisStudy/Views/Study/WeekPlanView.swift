import SwiftUI

/// Colours of the plan and progress designs (ScrPlan / ScrProgress).
enum KStudy {
    static let bg = Color.pair(0xF4EFE6, 0x15120F)
    static let card = Color.pair(0xFFFCF6, 0x211C18)
    static let sub = Color.pair(0xF1EBE0, 0x2B2520)
    static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
    static let text3 = Color.pair(0x776C60, 0x9A8F82)
    static let line = Color.pair(0xE6DDCF, 0x3A322B)
    static let pri = Color.pair(0x9C2F3A, 0xB23A47)
    static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
    static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
    static let amb = Color(hex: 0xF2B33D)
    static let ambText = Color.pair(0x83560A, 0xF2C46E)
    static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
    static let ok = Color.pair(0x1E7A4C, 0x5BC893)
    static let okSoft = Color.pair(0xE2F3E9, 0x173328)
}

extension PlanTask {
    /// Where a task is done: the lesson, its exam, the cards, or the course.
    var route: Route {
        let course: Route = courseId.map { .course($0) } ?? .courses
        switch target {
        case "reader": return materialId.map { .reader($0) } ?? course
        case "cards", "review": return .cards(courseId)
        // A quiz task without a lesson opens the course (the `where` of one pattern used to cover only "exam_prep" and crashed here).
        case "quiz", "exam_prep": return materialId.map { .quiz(QuizTarget(materialId: $0, kind: .final)) } ?? course
        default: return course
        }
    }
}

/// "12 dk", "1 sa 30 dk" in the design's words.
func studyDuration(_ minutes: Int, _ prefs: AppPrefs) -> String {
    let m = max(0, minutes), lang = prefs.lang
    if m < 60 { return "\(Format.num(m, lang))\(prefs.d(" dk"))" }
    return "\(Format.num(m / 60, lang))\(prefs.d(" sa"))" + (m % 60 > 0 ? " \(Format.num(m % 60, lang))\(prefs.d(" dk"))" : "")
}

/// Design: design/ScrPlan.dc.html, variant "week". This week's plan made by the server (build-plan: courses, exams,
/// unread pages, weak topics and due cards; rules only, no AI). Past days are done, today is highlighted.
struct WeekPlanView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    /// iPad (design NewIPad, "plan"): the week on the left, today's checklist on the right.
    @Environment(\.padRail) private var wide

    @State private var tasks: [PlanTask]?
    @State private var busy = false
    private let settings = SettingsAPI.loadNow()

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private let names = ["PZT", "SAL", "ÇAR", "PER", "CUM", "CMT", "PAZ"]

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var days: [Date] {
        guard let monday = Self.iso.date(from: PlanAPI.monday()) else { return [] }
        return (0..<7).map { monday.addingTimeInterval(Double($0) * 86_400 + 3_600) }
    }

    var body: some View {
        if wide { wideBody } else { phoneBody }
    }

    // MARK: iPad

    private var wideBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text(d("Ders planım")).font(KFont.ui(40, .medium, lang: lang)).kTracking(-0.03, size: 40, lang: lang)
                        .foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Button { Task { await regenerate() } } label: {
                        HStack(spacing: 8) {
                            KIcon(name: .refresh, size: 16, width: 1.8)
                            Text(busy ? "…" : d("Planı yeniden oluştur")).font(KFont.ui(14, .semibold, lang: lang))
                        }
                        .foregroundStyle(KPhone.text).padding(.horizontal, 16).frame(height: 46)
                        .background(KStudy.card, in: Capsule()).overlay(Capsule().stroke(KStudy.line, lineWidth: 1))
                    }
                    .disabled(busy)
                    Button { app.go(.timetable) } label: {
                        HStack(spacing: 8) {
                            KIcon(name: .calendar, size: 16, width: 1.8)
                            Text(prefs.t("schTitle")).font(KFont.ui(14, .semibold, lang: lang))
                        }
                        .foregroundStyle(Color.pair(0x7A5208, 0xF2C66D)).padding(.horizontal, 16).frame(height: 46)
                        .background(Color.pair(0xFBEBC8, 0x3A2E18), in: Capsule())
                        .overlay(Capsule().stroke(Color.pair(0xE8C77E, 0x6B5426), lineWidth: 1.5))
                    }
                }
                HStack(alignment: .top, spacing: 18) {
                    weekCard.frame(maxWidth: .infinity)
                    VStack(spacing: 14) {
                        todayCard
                        Text(d("Bu plan her pazar akşamı otomatik hazırlanır: çalışma planın, sınav haftası, zayıf konuların ve tekrar günleri birlikte hesaba katılır. Uygulamayı açınca ne çalışacağını düşünmene gerek kalmaz."))
                            .font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(KStudy.ambSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .frame(width: 340)
                }
            }
            .padding(.leading, 8).padding(.trailing, 32)
            .padding(.top, KLayout.top(54, minimum: 10) + 8).padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(KStudy.bg.ignoresSafeArea())
        .task { if tasks == nil { await load() } }
    }

    private func load() async {
        async let courses = CoursesAPI.listCourses()
        let week = await PlanAPI.weekTasks()
        _ = await courses
        tasks = week
    }

    /// The week: one row per day, its tasks as small cards with the colour of their kind.
    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(d("Bu haftanın planı")).font(KFont.ui(18, .medium, lang: lang)).foregroundStyle(KPhone.text)
                Spacer()
                Text(subtitle).font(KFont.mono(11, .regular)).foregroundStyle(KStudy.text2).lineLimit(1)
            }
            .padding(.bottom, 8)
            let all = tasks ?? []
            let today = CoursesAPI.todayISO()
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let key = Self.iso.string(from: day)
                let items = all.filter { $0.day == key }
                let isToday = key == today
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d(names[i])).font(KFont.ui(14, isToday ? .bold : .medium, lang: lang))
                            .foregroundStyle(isToday ? KStudy.priText : KPhone.text)
                        Text(Format.num(Calendar(identifier: .gregorian).component(.day, from: day), lang)).font(KFont.mono(10, .regular)).foregroundStyle(KStudy.text2)
                    }
                    .frame(width: 58, alignment: .leading).padding(.top, 4)
                    if items.isEmpty {
                        Text(d("Dinlenme günü")).font(KFont.ui(13, lang: lang)).foregroundStyle(KStudy.text2)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    } else {
                        FlowLayout(spacing: 8, rowSpacing: 8) {
                            ForEach(items) { t in taskChip(t, past: key < today) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { Rectangle().fill(KStudy.line).frame(height: 1) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(KStudy.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(KStudy.line, lineWidth: 1))
    }

    private func taskChip(_ t: PlanTask, past: Bool) -> some View {
        let done = t.status == "done" || past
        let course = CoursesAPI.lastCourses.first { $0.id == t.courseId }?.name[lang] ?? ""
        return Button { app.go(t.route) } label: {
            VStack(alignment: .leading, spacing: 2) {
                if !course.isEmpty {
                    Text(course.uppercased(with: lang.locale)).font(KFont.ui(10, .semibold, lang: lang)).foregroundStyle(t.look.fg).lineLimit(1)
                }
                Text(t.title).font(KFont.ui(12, .medium, lang: lang)).foregroundStyle(KPhone.text)
                    .strikethrough(done).lineLimit(2).multilineTextAlignment(.leading)
                Text(studyDuration(t.minutes, prefs)).font(KFont.ui(10, lang: lang)).foregroundStyle(KStudy.text2)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(width: 176, alignment: .leading)
            .background(t.look.chip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .leading) { Rectangle().fill(t.look.fg).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(done ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    /// Today's tasks with a tick each, and the start button.
    private var todayCard: some View {
        let today = CoursesAPI.todayISO()
        let items = (tasks ?? []).filter { $0.day == today }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(d("Bugün")).font(KFont.ui(18, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Spacer()
                Text(studyDuration(items.reduce(0) { $0 + $1.minutes }, prefs)).font(KFont.mono(12, .regular)).foregroundStyle(KStudy.text2)
            }
            .padding(.bottom, 8)
            if items.isEmpty {
                Text(d("Dinlenme günü")).font(KFont.ui(13, lang: lang)).foregroundStyle(KStudy.text2).padding(.vertical, 8)
            }
            ForEach(items) { t in
                let done = t.status == "done"
                HStack(spacing: 10) {
                    Button { toggle(t) } label: {
                        Circle().fill(done ? KStudy.ok : .clear).frame(width: 26, height: 26)
                            .overlay(Circle().stroke(done ? .clear : KStudy.line, lineWidth: 1.5))
                            .overlay { if done { KIcon(name: .check, size: 13, width: 2.4).foregroundStyle(KPhone.ctaText) } }
                    }
                    .accessibilityLabel(t.title)
                    .accessibilityAddTraits(done ? .isSelected : [])
                    Button { app.go(t.route) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.text).strikethrough(done)
                                .lineLimit(2).multilineTextAlignment(.leading)
                            Text([studyDuration(t.minutes, prefs), t.why].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(done ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Rectangle().fill(KStudy.line).frame(height: 1) }
            }
            if let next = items.first(where: { $0.status != "done" }) {
                Button { app.go(next.route) } label: {
                    Text(d("Bugünün planını başlat")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(KStudy.pri, in: Capsule())
                }
                .padding(.top, 10)
            }
        }
        .padding(18)
        .background(KStudy.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.pair(0xF2D9A8, 0x4A3A1C), lineWidth: 1.5))
    }

    private func toggle(_ t: PlanTask) {
        guard let i = tasks?.firstIndex(where: { $0.id == t.id }) else { return }
        let done = tasks?[i].status != "done"
        tasks?[i].status = done ? "done" : "todo"
        Task { await PlanAPI.setDone(t.id, done) }
    }

    // MARK: Phone

    private var phoneBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { app.back() } label: {
                    KIcon(name: .back, size: 22, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
                }
                .accessibilityLabel(d("Geri"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(d("Bu haftanın planı")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(subtitle).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(KStudy.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
            .padding(.top, KLayout.top(54, minimum: 6))
            ScrollView {
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        KIcon(name: .info, size: 16, width: 1.8).foregroundStyle(KStudy.ambText)
                        Text(d("Bu plan her pazar akşamı otomatik hazırlanır: çalışma planın, sınav haftası, zayıf konuların ve tekrar günleri birlikte hesaba katılır. Uygulamayı açınca ne çalışacağını düşünmene gerek kalmaz."))
                            .font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KStudy.ambSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if let tasks {
                        ForEach(Array(days.enumerated()), id: \.offset) { i, day in dayCard(i, day, tasks) }
                    }
                    Button { Task { await regenerate() } } label: {
                        Text(busy ? "…" : d("Planı yeniden oluştur")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(KStudy.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KStudy.line, lineWidth: 1))
                    }
                    .disabled(busy)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KStudy.bg.ignoresSafeArea())
        .task {
            guard tasks == nil else { return }
            // Course names for the day titles.
            async let courses = CoursesAPI.listCourses()
            let week = await PlanAPI.weekTasks()
            _ = await courses
            tasks = week
        }
    }

    /// "26 EKİ – 1 KAS · 4 GÜN × 1,5 SA"
    private var subtitle: String {
        guard let first = days.first, let last = days.last else { return "" }
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        let hours = settings.studyHours == settings.studyHours.rounded() ? String(Int(settings.studyHours)) : String(settings.studyHours)
        let plan = "\(Format.num(settings.studyDays, lang))\(d(" gün × "))\(lang == .tr ? hours.replacingOccurrences(of: ".", with: ",") : hours)\(d(" sa"))"
        return "\(f.string(from: first)) – \(f.string(from: last)) · \(plan)".uppercased(with: lang.locale)
    }

    private func dayCard(_ i: Int, _ day: Date, _ all: [PlanTask]) -> some View {
        let key = Self.iso.string(from: day)
        let today = CoursesAPI.todayISO()
        let items = all.filter { $0.day == key }
        let kind = items.isEmpty ? "rest" : key < today ? "done" : key == today ? "today" : "planned"
        let tag: (String, Color, Color) = switch kind {
        case "done": (d("TAMAM"), KStudy.okSoft, KStudy.ok)
        case "today": (d("BUGÜN"), KStudy.pri, KPhone.ctaText)
        case "planned": (d("PLANLI"), KStudy.sub, KStudy.text2)
        default: (d("DİNLENME"), KStudy.sub, KStudy.text3)
        }
        let courseNames = items.compactMap { t in CoursesAPI.lastCourses.first { $0.id == t.courseId }?.name[lang] }
        let title = items.isEmpty ? d("Dinlenme günü") : Array(NSOrderedSet(array: courseNames)).compactMap { $0 as? String }.joined(separator: " + ").ifEmpty(items[0].title)
        let minutes = items.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(spacing: 0) {
                    Text(d(names[i])).font(KFont.mono(10, .regular)).foregroundStyle(KStudy.text3)
                    Text(Format.num(Calendar(identifier: .gregorian).component(.day, from: day), lang)).font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(KPhone.text)
                }
                .frame(width: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(KFont.ui(14, .bold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(2)
                    Text(items.isEmpty ? "—" : studyDuration(minutes, prefs)).font(KFont.mono(11, .regular)).foregroundStyle(KStudy.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(tag.0).font(KFont.mono(10, .semibold)).foregroundStyle(tag.2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(tag.1, in: RoundedRectangle(cornerRadius: 6))
            }
            ForEach(items) { t in
                let done = t.status == "done" || kind == "done"
                Button { app.go(t.route) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(t.look.fg).frame(width: 7, height: 7)
                        Text(t.title).font(KFont.ui(13, lang: lang)).strikethrough(done)
                            .foregroundStyle(done ? KStudy.text3 : KPhone.text).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                        Text(studyDuration(t.minutes, prefs)).font(KFont.mono(10, .regular)).foregroundStyle(KStudy.text3)
                    }
                    .padding(.leading, 50)
                }
                .buttonStyle(.plain)
            }
            if kind == "today", let next = items.first(where: { $0.status != "done" }) {
                Button { app.go(next.route) } label: {
                    Text(d("Bugünün planını başlat")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(KStudy.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.leading, 50)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(kind == "rest" ? Color.clear : KStudy.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(kind == "today" ? KStudy.pri : kind == "rest" ? KStudy.line : .clear,
                        style: StrokeStyle(lineWidth: kind == "today" ? 2 : 1, dash: kind == "rest" ? [5, 4] : []))
        }
        .opacity(kind == "done" ? 0.75 : 1)
    }

    /// "Planı yeniden oluştur": the server makes the rest of the week again (done tasks stay).
    private func regenerate() async {
        busy = true
        await PlanAPI.runPlanner("build")
        tasks = await PlanAPI.weekTasks()
        busy = false
        toast.show(d("Haftalık plan yeniden oluşturuldu · zayıf konular öne alındı"))
    }
}

extension String {
    func ifEmpty(_ other: String) -> String { isEmpty ? other : self }
}
