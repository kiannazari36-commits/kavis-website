import SwiftUI

/// Design: design/ScrProgress.dc.html. The student's own numbers: study time this week against the weekly goal,
/// level and scores (written by the server), this month's calendar, most tapped words, mistakes made while "sure"
/// and the best hours (when there are enough exams). The empty variant shows until there is anything to show.
struct ProgressView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    @State private var data: ProgressData?
    private let settings = SettingsAPI.loadNow()

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private let dayLetters = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"]

    var body: some View {
        ZStack {
            KStudy.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text(d("İlerleme")).font(KFont.ui(28, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, KLayout.top(60, minimum: 8)).padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
                ScrollView {
                    if let data {
                        if data.isEmpty { empty } else { content(data) }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { data = await ProgressAPI.load() }
            }
            FloatingTabBar(active: .progress, onCourses: { app.go(.courses) }, onProgress: {}, onSettings: { toast.show(prefs.t("k165")) })
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .task { if data == nil { data = await ProgressAPI.load() } }
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

    private func timeCard(_ p: ProgressData) -> some View {
        let total = p.weekMinutes.reduce(0, +)
        let goal = Double(settings.studyDays) * settings.studyHours
        let goalText = goal == goal.rounded() ? String(Int(goal)) : String(format: "%.1f", goal)
        let maxM = max(60, p.weekMinutes.max() ?? 0)
        let todayIndex = (Calendar(identifier: .gregorian).component(.weekday, from: Date()) + 5) % 7
        let studied = p.weekMinutes.filter { $0 > 0 }
        return card {
            heading(.clock, d("Çalışma süresi"))
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
            if !studied.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(studyDuration(studied.reduce(0, +) / studied.count, prefs)).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(d("Çalışılan gün başına ortalama")).font(KFont.ui(12, lang: lang)).foregroundStyle(KStudy.text3)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(KStudy.sub, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
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
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        let first = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? now
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return card {
            Text(f.string(from: now).capitalized(with: lang.locale)).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(dayLetters, id: \.self) { Text(d($0)).font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text3) }
                ForEach(0..<(lead + count), id: \.self) { i in
                    if i < lead { Color.clear.frame(height: 36) } else {
                        let n = i - lead + 1
                        let exam = p.examDays.contains(n), today = n == comps.day
                        VStack(spacing: 2) {
                            Text(Format.num(n, lang)).font(KFont.ui(13, today ? .bold : .regular, lang: lang)).foregroundStyle(KPhone.text)
                            Circle().fill(p.studiedDays.contains(n) ? KStudy.pri : .clear).frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(exam ? KStudy.amb.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(today ? KStudy.pri : .clear, lineWidth: 1.5))
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 14) {
                HStack(spacing: 6) { Circle().fill(KStudy.pri).frame(width: 7, height: 7); Text(d("Çalışıldı")) }
                HStack(spacing: 6) { RoundedRectangle(cornerRadius: 3).fill(KStudy.amb).frame(width: 10, height: 10); Text(d("Sınav")) }
            }
            .font(KFont.ui(11, lang: lang)).foregroundStyle(KStudy.text2)
        }
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
