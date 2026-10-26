import SwiftUI

/// Design: design/ScrReview.dc.html, tab "Bu ders" (Ders özeti), opened after the last section of a lesson and after
/// the end-of-lesson exam: the lesson's weak topics, the words the student tapped, a short review summary from the
/// PDF (with its pages; points on weak topics are marked), and the way on: the lesson's questions, cards, the pages.
/// Like the web, there are no tabs yet ("Genel özet" and "Sınav" are still to build) and no audio card.
struct LessonSummaryView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app

    let materialId: String

    @State private var data: LessonSummary?
    @State private var recap: Result<(points: [RecapPoint], lang: Lang), RecapFailure>?

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private func t(_ key: String) -> String { prefs.t(key) }

    private enum C {
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
        static let bad = Color.pair(0xC0352B, 0xF27A70)
        static let onBad = Color.pair(0xFFFCF6, 0x2A0F0D)
        static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
    }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        weakCard
                        wordsCard
                        recapCard
                        actions
                    }
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
                }
            }
        }
        .task {
            guard data == nil else { return }
            async let summary = SummaryAPI.lessonData(materialId: materialId, lang: lang)
            async let made = SummaryAPI.recap(materialId: materialId)
            data = await summary
            recap = await made
        }
    }

    // MARK: Header

    /// "HİPERTANSİYON · SINAV 84/100 · 8 EKİM"
    private var subtitle: String {
        guard let data else { return "" }
        var parts = [data.title]
        if let score = data.score { parts.append("\(t("lsExam")) \(Format.num(score, lang))/\(Format.num(100, lang))") }
        if let on = data.scoredOn {
            let f = DateFormatter()
            f.locale = lang.locale
            f.setLocalizedDateFormatFromTemplate("dMMMM")
            parts.append(f.string(from: on))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ").uppercased(with: lang.locale)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button { app.back() } label: {
                KIcon(name: .chevronLeft, size: 24, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
            }
            .accessibilityLabel(d("Geri"))
            VStack(alignment: .leading, spacing: 1) {
                Text(d("Ders özeti")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
                Text(subtitle).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(C.text3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
        .padding(.top, KLayout.top(54, minimum: 6))
        .padding(.bottom, 10)
    }

    // MARK: Cards

    private func cardTitle(_ title: String, icon: KIconName, bg: Color, fg: Color, count: Int? = nil) -> some View {
        HStack(spacing: 10) {
            KIcon(name: icon, size: 16, width: icon == .warning ? 2 : 1.8).foregroundStyle(fg)
                .frame(width: 30, height: 30).background(bg, in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(-8))
            Text(title).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading)
            if let count, count > 0 { Text(Format.num(count, lang)).font(KFont.mono(11, .regular)).foregroundStyle(C.text3) }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func muted(_ text: String) -> some View {
        Text(text).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(C.text2)
    }

    private var weakCard: some View {
        card {
            cardTitle(d("Zayıf olduğun konular"), icon: .warning, bg: C.bad, fg: C.onBad, count: data?.weak.count)
            if let data, data.weak.isEmpty { muted(t("lsNoWeak")) }
            ForEach(data?.weak ?? []) { w in
                Button { openReader(w.page) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(w.title).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                            if let page = w.page {
                                Text("\(d("S.")) \(Format.num(page, lang))").font(KFont.mono(11, .regular)).foregroundStyle(C.priText)
                            }
                        }
                        HStack(spacing: 8) {
                            Text(d(w.sure ? "Emin olduğun hata" : "Yanlış cevap")).font(KFont.ui(11, .semibold, lang: lang)).foregroundStyle(C.bad)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(C.badSoft, in: RoundedRectangle(cornerRadius: 5))
                                .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.14, d: 1, tx: 0, ty: 0))
                            GeometryReader { g in
                                Capsule().fill(C.sub)
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(w.mastery < 35 ? C.bad : C.amb).frame(width: g.size.width * CGFloat(w.mastery) / 100)
                                    }
                            }
                            .frame(height: 5)
                            Text(Format.percent(w.mastery, lang)).font(KFont.mono(10, .regular)).foregroundStyle(C.text3).frame(minWidth: 30, alignment: .trailing)
                        }
                    }
                    .padding(.top, 10).padding(.bottom, 2)
                    .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var wordsCard: some View {
        card {
            cardTitle(d("Dokunduğun kelimeler"), icon: .hand, bg: C.priSoft, fg: C.priText)
            if let data, data.words.isEmpty { muted(t("lsNoWords")) }
            ForEach(Array((data?.words ?? []).enumerated()), id: \.offset) { _, w in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(w.word).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text).fixedSize()
                        .overlay(alignment: .bottom) {
                            Line().stroke(C.priText, style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2])).frame(height: 1.5).offset(y: 2)
                        }
                    Text(w.text).font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("×\(Format.num(w.taps, lang))").font(KFont.mono(11, .regular)).foregroundStyle(C.text3)
                }
                .padding(.top, 8)
                .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
            }
        }
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d("TEKRAR İÇİN KISA ÖZET · PDF'TEN")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.ambText)
            switch recap {
            case nil: muted(t("lsMaking"))
            case .failure(let e): muted(t(e == .locked ? "trialLocked" : e == .budget ? "askBudget" : "askFailed"))
            case .success(let made):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(made.points.enumerated()), id: \.offset) { _, p in point(p, lang: made.lang) }
                }
                .environment(\.layoutDirection, made.lang.layoutDirection)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// "• … s. 13" — the page opens the reader there; a point about a weak topic has the "Zayıf konun" mark.
    private func point(_ p: RecapPoint, lang docLang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if p.weak == true {
                Text(t("lsWeakMark")).font(KFont.ui(11, .semibold, lang: lang)).foregroundStyle(C.bad)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(C.badSoft, in: RoundedRectangle(cornerRadius: 5))
            }
            Button { openReader(p.page_from) } label: {
                (Text("• \(p.text) ").font(KFont.reading(15, lang: docLang)).foregroundStyle(KPhone.text)
                 + Text(pageRange(p)).font(KFont.mono(11, .regular)).foregroundStyle(C.priText))
                    .kLineHeight(1.55, size: 15, lang: docLang)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, p.weak == true ? 10 : 0)
        .overlay(alignment: .leading) { if p.weak == true { Rectangle().fill(C.bad).frame(width: 3) } }
    }

    private func pageRange(_ p: RecapPoint) -> String {
        let a = Format.num(p.page_from, lang)
        return p.page_to != p.page_from ? "(\(t("pageAbbr")) \(a)–\(Format.num(p.page_to, lang)))" : "(\(t("pageAbbr")) \(a))"
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                app.go(.quiz(QuizTarget(materialId: materialId, kind: .check, pageFrom: 1, pageTo: data?.pages ?? 9999)))
            } label: {
                Text(t("lsQuiz")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 52).background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            HStack(spacing: 10) {
                ghost(t("cardsTitle")) { app.go(.lessonCards(materialId)) }
                ghost(d("Sayfaları oku")) { openReader(nil) }
            }
        }
    }

    private func ghost(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.line, lineWidth: 1))
        }
    }

    private func openReader(_ page: Int?) {
        app.readerPage = page
        app.go(.reader(materialId))
    }
}

/// A straight line along the middle of its frame (the dotted underline of a tapped word).
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
