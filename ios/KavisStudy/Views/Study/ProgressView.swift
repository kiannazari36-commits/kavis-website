import SwiftUI

/// Design: design/ScrProgress.dc.html. The student's own numbers: study time this week against the weekly goal,
/// level and scores (written by the server), this month's calendar, most tapped words, mistakes made while "sure"
/// and the best hours (when there are enough exams). The empty variant shows until there is anything to show.
struct ProgressView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    @State private var data: ProgressData?
    /// The course the numbers are limited to (nil = all) and the calendar's month (0 = this month, -1 = last month …).
    @State private var course: String?
    @State private var monthOffset = 0
    @State private var courses: [Course] = []
    private let settings = SettingsAPI.loadNow()

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private let dayLetters = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"]

    var body: some View {
        ZStack {
            KStudy.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(d("İlerleme")).font(KFont.ui(28, .bold, lang: lang)).foregroundStyle(KPhone.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    courseMenu
                }
                .padding(.horizontal, 20).padding(.top, KLayout.top(60, minimum: 8)).padding(.bottom, 8)
                ScrollView {
                    if let data {
                        if data.isEmpty { empty } else { content(data) }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { data = await ProgressAPI.load(course: course, month: shownMonth) }
            }
            FloatingTabBar(active: .progress, onCourses: { app.go(.courses) }, onProgress: {}, onSettings: { app.go(.settings) })
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .task(id: "\(course ?? "")|\(monthOffset)") {
            if courses.isEmpty { courses = await CoursesAPI.listCourses() }
            data = await ProgressAPI.load(course: course, month: shownMonth)
        }
    }

    private var shownMonth: Date { Calendar(identifier: .gregorian).date(byAdding: .month, value: monthOffset, to: Date()) ?? Date() }

    /// The course switch of the design: "Tüm dersler" or one course.
    private var courseMenu: some View {
        let label = courses.first { $0.id == course }?.name[lang] ?? d("Tüm dersler")
        return Menu {
            Button(d("Tüm dersler")) { course = nil }
            ForEach(courses, id: \.id) { c in Button(c.name[lang]) { course = c.id } }
        } label: {
            HStack(spacing: 6) {
                Text(label).font(KFont.ui(13, .semibold, lang: lang)).lineLimit(1)
                KIcon(name: .chevronDown, size: 14, width: 2)
            }
            .foregroundStyle(KPhone.text)
            .padding(.horizontal, 12).frame(height: 36)
            .background(KStudy.card, in: Capsule())
            .overlay(Capsule().stroke(KStudy.line, lineWidth: 1))
        }
        .accessibilityLabel(d("Tüm dersler"))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KStudy.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func heading(_ icon: KIconName?, _ title: String) -> some View {
        HStack(spacing: 10) {
            if let icon {
                KIcon(name: icon, size: 18, width: 1.7).foregroundStyle(KStudy.priText)
                    .frame(width: 34, height: 34).background(KStudy.priSoft, in: RoundedRectangle(cornerRadius: 10)).rotationEffect(.degrees(-6))
            }
            Text(title).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text)
        }
    }

    // MARK: Content

    private func content(_ p: ProgressData) -> some View {
        VStack(spacing: 12) {
            if let exam = p.exam { examCard(exam) }
            timeCard(p)
            levelCard(p)
            stats(p)
            calendar(p)
            if !p.words.isEmpty { words(p) }
            if !p.dangerous.isEmpty { dangerous(p) }
            if let best = p.bestHours { bestHours(best) }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 120)
    }

    private static let examBg = Color.pair(0x2A2420, 0x2E2721)

    /// "Vize · 19–23 Ekim": the kind of exam and its days, in the app language.
    private func examRange(_ exam: (kind: String, start: String, end: String, daysLeft: Int)) -> String {
        let kind = d(exam.kind == "final" ? "Final" : exam.kind == "makeup" ? "Bütünleme" : "Vize")
        let f = DateFormatter()
        f.locale = lang.locale
        f.dateFormat = "yyyy-MM-dd"
        guard let a = f.date(from: exam.start), let b = f.date(from: exam.end) else { return kind }
        let out = DateFormatter()
        out.locale = lang.locale
        out.setLocalizedDateFormatFromTemplate("MMMM")
        let month = out.string(from: b).capitalized(with: lang.locale)
        let day = Calendar(identifier: .gregorian)
        let da = Format.num(day.component(.day, from: a), lang), db = Format.num(day.component(.day, from: b), lang)
        return "\(kind) · \(a == b ? db : "\(da)–\(db)") \(month)"
    }

    /// Days left until the exam week, with the two shortcuts of the design.
    private func examCard(_ exam: (kind: String, start: String, end: String, daysLeft: Int)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(Format.num(exam.daysLeft, lang)).font(KFont.ui(22, .bold, lang: lang))
                    Text(d("GÜN")).font(KFont.mono(9, .regular))
                }
                .foregroundStyle(Color(hex: 0xFFFCF6))
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                .rotationEffect(.degrees(-6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(d("SINAV HAFTASINA")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(KStudy.amb)
                    Text(examRange(exam)).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button { app.openGeneralSummary = true; app.go(.lessonSummary("")) } label: {
                    Text(d("Genel özet")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                Button { app.go(.examCenter) } label: {
                    Text(d("Sınav merkezi")).font(KFont.ui(13, .bold, lang: lang)).foregroundStyle(Color(hex: 0x2A2420))
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(KStudy.amb, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Self.examBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timeCard(_ p: ProgressData) -> some View {
        let total = p.weekMinutes.reduce(0, +)
        let goal = Double(settings.studyDays) * settings.studyHours
        let goalText = goal == goal.rounded() ? String(Int(goal)) : String(format: "%.1f", goal)
        let maxM = max(60, p.weekMinutes.max() ?? 0)
        let todayIndex = (Calendar(identifier: .gregorian).component(.weekday, from: Date()) + 5) % 7
        let studied = p.weekMinutes.filter { $0 > 0 }
        return card {
            HStack {
                heading(.clock, d("Çalışma süresi"))
                Spacer()
                Text(weekRangeLabel).font(KFont.mono(11, .regular)).foregroundStyle(KStudy.text3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(studyDuration(total, prefs)).font(KFont.ui(26, .bold, lang: lang)).foregroundStyle(KPhone.text)
                Text("/ \(lang == .tr ? goalText.replacingOccurrences(of: ".", with: ",") : goalText)\(d(" sa haftalık hedef"))")
                    .font(KFont.ui(13, lang: lang)).foregroundStyle(KStudy.text3)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(KStudy.line)
                    Capsule().fill(KStudy.pri).frame(width: g.size.width * min(1, CGFloat(total) / CGFloat(max(1, goal * 60))))
                }
            }
            .frame(height: 6)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let m = p.weekMinutes[i]
                    VStack(spacing: 4) {
                        Text(m > 0 ? Format.num(m, lang) : " ").font(KFont.mono(10, .regular)).foregroundStyle(KStudy.text3)
                        RoundedRectangle(cornerRadius: 5).fill(i == todayIndex ? KStudy.amb : m > 0 ? KStudy.pri : KStudy.line)
                            .frame(height: max(4, CGFloat(m) / CGFloat(maxM) * 70))
                        Text(d(dayLetters[i])).font(KFont.ui(11, i == todayIndex ? .semibold : .regular, lang: lang))
                            .foregroundStyle(i == todayIndex ? KPhone.text : KStudy.text3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(d("Bu haftanın günlük çalışma dakikaları"))
            HStack(spacing: 8) {
                if !studied.isEmpty { averageBox(studyDuration(studied.reduce(0, +) / studied.count, prefs), d("Çalışılan gün başına ortalama")) }
                if p.fourWeekAverage > 0 { averageBox(studyDuration(p.fourWeekAverage, prefs), d("Son 4 hafta · haftalık ortalama")) }
            }
            if !p.perPdf.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(d("BU HAFTA PDF'LERE AYRILAN SÜRE")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8).foregroundStyle(KStudy.text3)
                    ForEach(Array(p.perPdf.enumerated()), id: \.offset) { i, row in
                        HStack(spacing: 10) {
                            Circle().fill(i == 0 ? KStudy.pri : KStudy.text3).frame(width: 8, height: 8)
                            Text(row.0).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text(studyDuration(row.1, prefs)).font(KFont.mono(12, .regular)).foregroundStyle(KPhone.text)
                        }
                    }
                }
            }
            Button { app.go(.settings) } label: {
                Text("\(d("Planı değiştir")) · \(Format.num(settings.studyDays, lang))\(d(" gün × "))\(hoursText)\(d(" sa"))")
                    .font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(KStudy.line, lineWidth: 1))
            }
        }
    }

    private var hoursText: String {
        let h = settings.studyHours
        let text = h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h)
        return lang == .tr ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// "5–11 EKİM": the days of this week.
    private var weekRangeLabel: String {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        var c = cal; c.firstWeekday = 2
        let monday = c.dateInterval(of: .weekOfYear, for: Date())?.start ?? start
        let sunday = c.date(byAdding: .day, value: 6, to: monday) ?? monday
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("MMMM")
        let a = Format.num(c.component(.day, from: monday), lang), b = Format.num(c.component(.day, from: sunday), lang)
        return "\(a)–\(b) \(f.string(from: sunday))".uppercased(with: lang.locale)
    }

    private func averageBox(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
            Text(label).font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text3)
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .background(KStudy.sub, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func levelCard(_ p: ProgressData) -> some View {
        let names = ["Başlangıç", "Gelişiyor", "İyi", "Çok iyi", "Uzman"]
        let cur = ProgressAPI.levelIndex(p.level) ?? -1
        return card {
            HStack(spacing: 10) {
                KIcon(name: .target, size: 18, width: 1.7).foregroundStyle(KStudy.ambText)
                    .frame(width: 34, height: 34).background(KStudy.ambSoft, in: RoundedRectangle(cornerRadius: 10)).rotationEffect(.degrees(-6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(d("SEVİYE")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(KStudy.text3)
                    Text(cur >= 0 ? d(names[cur]) : "—").font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(KPhone.text)
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 4) {
                        Capsule().fill(i < cur ? KStudy.pri : i == cur ? KStudy.amb : KStudy.line).frame(height: 6)
                        Text(d(names[i])).font(KFont.ui(10, i == cur ? .bold : .regular, lang: lang))
                            .foregroundStyle(i == cur ? KPhone.text : KStudy.text3).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    private func stats(_ p: ProgressData) -> some View {
        let items: [(String, String, Color)] = [
            (p.lastScore.map { Format.num($0, lang) } ?? "—", "Son puan", KStudy.priText),
            (p.bestScore.map { Format.num($0, lang) } ?? "—", "En iyi puan", KPhone.text),
            ("\(Format.num(p.pagesRead, lang))/\(Format.num(p.pagesTotal, lang))", "Okunan sayfa", KPhone.text),
            (Format.num(p.studiedDaysCount, lang), "Çalışılan gün", KPhone.text),
            (Format.num(p.dueCards, lang), "Bugünkü kart", KPhone.text),
            (Format.num(p.streak, lang), "Gün seri", KStudy.ambText),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items, id: \.1) { v, l, fg in
                VStack(spacing: 2) {
                    Text(v).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.6)
                    Text(d(l)).font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text3).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(KStudy.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func calendar(_ p: ProgressData) -> some View {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let shown = shownMonth
        let first = cal.dateInterval(of: .month, for: shown)?.start ?? shown
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: shown)?.count ?? 30
        let todayDay = monthOffset == 0 ? cal.component(.day, from: now) : -1
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return card {
            HStack(spacing: 8) {
                Text(f.string(from: shown).capitalized(with: lang.locale)).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                monthButton(.chevronLeft, label: d("Önceki ay")) { monthOffset -= 1 }
                monthButton(.chevron, label: d("Sonraki ay")) { monthOffset += 1 }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(dayLetters, id: \.self) { Text(d($0)).font(KFont.mono(10, .regular)).foregroundStyle(KStudy.text3) }
                ForEach(0..<(lead + count), id: \.self) { i in
                    if i < lead { Color.clear.frame(height: 42) } else {
                        let n = i - lead + 1
                        let exam = p.examDays.contains(n), next = p.nextReviewDays.contains(n), today = n == todayDay
                        let week = p.examWeekDays.contains(n)
                        VStack(spacing: 2) {
                            Text(Format.num(n, lang)).font(KFont.ui(13, today || next ? .bold : .medium, lang: lang))
                                .foregroundStyle(exam ? Color(hex: 0x2A2420) : week ? KStudy.priText : monthOffset > 0 || (monthOffset == 0 && n > todayDay) ? KStudy.text3 : KPhone.text)
                                .frame(width: 32, height: 32)
                                .background(exam ? KStudy.amb : week ? KStudy.priSoft : .clear, in: Circle())
                                .overlay(Circle().stroke(next ? KColor.bad : today ? KPhone.text : .clear, lineWidth: 2))
                            Circle().fill(p.studiedDays.contains(n) ? KStudy.text2 : .clear).frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            FlowLayout(spacing: 12, rowSpacing: 6) {
                legend(Circle().fill(KStudy.text2).frame(width: 6, height: 6), d("Çalışıldı"))
                legend(Circle().fill(KStudy.amb).frame(width: 12, height: 12), d("Sınav"))
                legend(Circle().stroke(KColor.bad, lineWidth: 2).frame(width: 12, height: 12), d("Sonraki tekrar"))
                legend(Capsule().fill(KStudy.priSoft).frame(width: 18, height: 12), d("Sınav haftası"))
            }
            .font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text2)
        }
    }

    private func legend<Mark: View>(_ mark: Mark, _ text: String) -> some View {
        HStack(spacing: 6) { mark; Text(text) }
    }

    private func monthButton(_ icon: KIconName, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 16, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text)
                .frame(width: 36, height: 36).background(KStudy.sub, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func words(_ p: ProgressData) -> some View {
        card {
            heading(.book, d("En çok dokunulan kelimeler"))
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(p.words, id: \.0) { w, n in
                    HStack(spacing: 6) {
                        Text(w).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text)
                        Text("×\(Format.num(n, lang))").font(KFont.mono(11, .regular)).foregroundStyle(KStudy.priText)
                    }
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(KStudy.sub, in: Capsule())
                }
            }
        }
    }

    private func dangerous(_ p: ProgressData) -> some View {
        card {
            heading(.warning, d("Tehlikeli hatalar"))
            ForEach(p.dangerous, id: \.0) { q, n in
                HStack(alignment: .top, spacing: 10) {
                    Text(q).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Format.num(n, lang))×").font(KFont.mono(12, .semibold)).foregroundStyle(KStudy.priText)
                }
                .padding(12)
                .background(KStudy.priSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button { app.go(.cards(nil)) } label: {
                Text(prefs.t("cardsTitle")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KStudy.priText)
            }
        }
    }

    private func bestHours(_ b: (from: Int, to: Int, rate: Int, late: Int?)) -> some View {
        card {
            heading(.clock, d("Öneri: en verimli saatlerin"))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d:00–%02d:00 · %%%d", b.from, b.to, b.rate)).font(KFont.mono(16, .semibold)).foregroundStyle(KPhone.text)
                Text(d("En verimli saatler")).font(KFont.ui(12, lang: lang)).foregroundStyle(KStudy.text3)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(KStudy.ambSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: Empty

    private var empty: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<21, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8).fill(KStudy.line.opacity(i % 5 == 2 ? 0.9 : 0.45)).frame(height: 30)
                }
            }
            .padding(.horizontal, 24).padding(.top, 30)
            .accessibilityHidden(true)
            Text(d("Henüz ilerleme yok")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
            Text(d("İlk dersini okuyup bir bölüm kontrolü çözdüğünde seviyen, puanların ve takvimin burada görünür."))
                .font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2).multilineTextAlignment(.center).padding(.horizontal, 28)
            Button { app.go(.courses) } label: {
                Text(d("Derslerime git")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .padding(.horizontal, 26).frame(height: 48).background(KStudy.pri, in: Capsule())
            }
        }
        .padding(.bottom, 120)
    }
}
