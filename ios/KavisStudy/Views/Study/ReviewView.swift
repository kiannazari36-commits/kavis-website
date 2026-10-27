import SwiftUI

/// Design: design/NewRevise.dc.html ("Bugünün tekrarı"), the same steps as the web's /review: 1 a summary made for
/// the student (the lesson's review points, else its weak topics) → 2 the due cards (Biliyorum / Tekrar sor, saved
/// like the cards screen) → 3 up to 3 questions (saved as a quiz try the server grades) → result. "Sonra devam et"
/// leaves without finishing; "Bitir" closes today's review.
struct ReviewView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    let reviewId: String

    @State private var review: PlanAPI.Review?
    @State private var loaded = false
    @State private var data: LessonSummary?
    @State private var recap: Result<(points: [RecapPoint], lang: Lang), RecapFailure>?
    @State private var cards: [FlashCard] = []
    @State private var quiz: Quiz?

    @State private var step = 0
    @State private var ci = 0
    @State private var flipped = false
    @State private var known: [Int: Bool] = [:]
    @State private var qi = 0
    @State private var answers: [Int: Int] = [:]
    @State private var saved = false

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    private enum C {
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let seg = Color.pair(0xEAE1D2, 0x2B2520)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let pri = Color(hex: 0x9C2F3A)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF5E3E2, 0x3A2224)
        static let ambSoft = Color.pair(0xFBEBC8, 0x3A2E18)
        static let ambFg = Color.pair(0xA86F0E, 0xF2C66D)
        static let ambLine = Color.pair(0xE8C77E, 0x6B5426)
        static let good = Color.pair(0x2E7D4F, 0x8FD3A8)
        static let goodSoft = Color.pair(0xE3F1E7, 0x1F3328)
        static let trackOff = Color.pair(0xD9CFBE, 0x4A4038)
        static let bg = LinearGradient(colors: [Color.pair(0xEDE3D2, 0x1F1A16), Color.pair(0xF4EFE6, 0x15120F)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.42))
    }

    private var questions: [QuizQuestion] { quiz?.questions ?? [] }
    private var qLang: Lang { quiz?.lang ?? recapLang }
    private var points: [RecapPoint] { if case .success(let r) = recap { r.points } else { [] } }
    private var recapLang: Lang { if case .success(let r) = recap { r.lang } else { lang } }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let review, review.status != "done" {
                            if step < 3 { stepBar }
                            switch step {
                            case 0: summary
                            case 1: cardStep
                            case 2: questionStep
                            default: result
                            }
                        } else if loaded {
                            Text(t(review == nil ? "rvLoadFail" : "rvNoReview")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 34)
                }
            }
            .padColumn()
        }
        .task(id: reviewId) {
            guard let r = await PlanAPI.review(reviewId) else { loaded = true; return }
            async let c = PlanAPI.reviewCards(r)
            async let q = PlanAPI.reviewQuestions(r)
            if let m = r.materialId { data = await SummaryAPI.lessonData(materialId: m, lang: lang) }
            cards = await c
            quiz = await q
            review = r
            loaded = true
            if let m = r.materialId { recap = await SummaryAPI.recap(materialId: m) }
        }
    }

    // MARK: Header and steps

    private var header: some View {
        HStack(spacing: 12) {
            Button { app.back() } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46).background(C.card, in: Circle()).overlay(Circle().stroke(C.line, lineWidth: 1))
            }
            .accessibilityLabel(t("rvBack"))
            VStack(alignment: .leading, spacing: 1) {
                Text(t("rvTitle")).font(KFont.ui(18, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                if let review {
                    Text([review.title, "~\(Format.num(review.minutes, lang))\(prefs.d(" dk"))"].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(KFont.ui(12, lang: lang)).foregroundStyle(C.text2).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { app.back() } label: {
                Text(t("rvLater")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text)
                    .padding(.horizontal, 12).frame(height: 38).overlay(Capsule().stroke(C.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.top, KLayout.top(60, minimum: 6)).padding(.bottom, 12)
    }

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Button { i == 1 ? toCards() : i == 2 ? afterCards() : (step = 0) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(i < step ? C.good : i == step ? C.pri : C.trackOff).frame(height: 5)
                        Text("\(Format.num(i + 1, lang)) · \(t(["rvStepSum", "rvStepCards", "rvStepQs"][i]))")
                            .font(KFont.ui(12, i == step ? .semibold : .regular, lang: lang)).foregroundStyle(i == step ? KPhone.text : C.text2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(i == step ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func primary(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                .frame(maxWidth: .infinity, minHeight: 52).background(C.pri, in: Capsule())
        }
    }

    private func ghost(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity, minHeight: 52).overlay(Capsule().stroke(C.line, lineWidth: 1))
        }
    }

    private func muted(_ key: String) -> some View {
        Text(t(key)).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2)
    }

    // MARK: 1 · Summary

    private var summary: some View {
        let weak = data?.weak ?? []
        let sure = weak.filter(\.sure).count
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("rvPrepared")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Text(t("rvIntro")).font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(KPhone.text)
                FlowLayout(spacing: 6) {
                    if sure > 0 { chip(t("rvChipSure").replacingOccurrences(of: "{n}", with: Format.num(sure, lang)), C.priText) }
                    if !weak.isEmpty { chip(t("rvChipWeak").replacingOccurrences(of: "{n}", with: Format.num(weak.count, lang)), C.ambFg) }
                    if !points.isEmpty { chip(t("rvChipForget"), C.good) }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(C.ambLine, lineWidth: 1))

            Text(t("rvSumHead").replacingOccurrences(of: "{n}", with: Format.num(points.isEmpty ? weak.count : points.count, lang)))
                .font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(C.text2).padding(.horizontal, 4).padding(.top, 4)
            if !points.isEmpty {
                ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                    sumCard(i, p.text, textLang: recapLang, pages: Format.pagesShort(p.page_from, p.page_to, recapLang), why: p.weak == true ? "rvWhyWeak" : "rvWhyForget", weak: p.weak == true)
                }
            } else {
                ForEach(Array(weak.enumerated()), id: \.element.id) { i, w in
                    sumCard(i, w.title, textLang: lang, pages: w.page.map { Format.pagesShort($0, $0, lang) }, why: w.sure ? "rvWhySure" : "rvWhyWeak", weak: true)
                }
            }
            if case .failure = recap, weak.isEmpty { muted("rvNoSum") }
            primary(t("rvToCards"), toCards)
        }
    }

    private func chip(_ text: String, _ fg: Color) -> some View {
        Text(text).font(KFont.ui(11, .semibold, lang: lang)).foregroundStyle(fg)
            .padding(.horizontal, 10).frame(height: 26).background(C.card, in: Capsule())
    }

    private func sumCard(_ i: Int, _ text: String, textLang: Lang, pages: String?, why: String, weak: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(Format.num(i + 1, lang)).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(C.priText)
                    .frame(width: 28, height: 28).background(C.priSoft, in: Circle())
                Text(text).font(KFont.ui(15, .medium, lang: textLang)).kLineHeight(1.45, size: 15, lang: textLang).foregroundStyle(KPhone.text)
                    .environment(\.layoutDirection, textLang.isRTL ? .rightToLeft : .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let pages {
                    Text(pages).font(KFont.mono(10, .regular)).foregroundStyle(C.text2)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(C.seg, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            (Text(t("rvWhy")).fontWeight(.semibold) + Text(" " + t(why)))
                .font(KFont.ui(12, lang: lang)).foregroundStyle(weak ? C.ambFg : C.good)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(weak ? C.ambSoft : C.goodSoft, in: RoundedRectangle(cornerRadius: 12))
                .padding(.leading, 38)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(C.line, lineWidth: 1))
    }

    // MARK: 2 · Cards

    private func toCards() {
        guard !cards.isEmpty else { return afterCards() }
        ci = 0
        flipped = false
        step = 1
    }

    private func afterCards() {
        if questions.isEmpty { step = 3 } else { qi = 0; step = 2 }
    }

    private func mark(_ yes: Bool) {
        guard ci < cards.count else { return }
        let card = cards[ci]
        Task { await CardsAPI.rate(card, yes ? .good : .again) }
        known[ci] = yes
        flipped = false
        if ci >= cards.count - 1 {
            toast.show(t("rvToQs"))
            afterCards()
        } else {
            ci += 1
        }
    }

    @ViewBuilder private var cardStep: some View {
        if ci < cards.count {
            let card = cards[ci]
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t("rvCardOf").replacingOccurrences(of: "{a}", with: Format.num(ci + 1, lang)).replacingOccurrences(of: "{b}", with: Format.num(cards.count, lang)))
                        .font(KFont.mono(11, .regular)).foregroundStyle(C.text2)
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(cards.indices, id: \.self) { i in
                            Circle().fill(known[i] == true ? C.good : known[i] == false ? C.ambLine : i == ci ? C.pri : C.trackOff).frame(width: 9, height: 9)
                        }
                    }
                }
                Button { flipped.toggle() } label: {
                    VStack(spacing: 14) {
                        Text(card.q).font(KFont.ui(20, .semibold, lang: card.lang)).multilineTextAlignment(.center)
                        if flipped {
                            Rectangle().fill(C.ambLine).frame(width: 60, height: 2)
                            Text(card.a).font(KFont.ui(17, lang: card.lang)).kLineHeight(1.5, size: 17, lang: card.lang).multilineTextAlignment(.center)
                            if let page = card.page {
                                Text("\(t("rvSource")) \(Format.pagesShort(page, page, card.lang))").font(KFont.mono(10, .regular)).foregroundStyle(C.text2)
                            }
                        } else {
                            Text(t("rvThink")).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text2)
                        }
                    }
                    .foregroundStyle(KPhone.text)
                    .environment(\.layoutDirection, card.lang.isRTL ? .rightToLeft : .leftToRight)
                    .padding(24)
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(C.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(flipped ? C.ambLine : C.line, lineWidth: 1.5))
                    .shadow(color: Color(light: Color(hex: 0x2A2420, opacity: 0.08), dark: .clear), radius: 15, y: 12)
                }
                .buttonStyle(.plain)
                .accessibilityHint(t("rvFlip"))
                if flipped {
                    HStack(spacing: 10) {
                        Button { mark(false) } label: {
                            Text(t("rvAskAgain")).font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                                .frame(maxWidth: .infinity, minHeight: 52).background(C.ambSoft, in: Capsule()).overlay(Capsule().stroke(C.ambLine, lineWidth: 1))
                        }
                        primary(t("rvKnow")) { mark(true) }
                    }
                } else {
                    ghost(t("rvShowAnswer")) { flipped = true }
                }
            }
        } else {
            muted("rvNoCards")
            primary(t("rvToQs"), afterCards)
        }
    }

    // MARK: 3 · Questions

    private func nextQuestion() {
        guard answers[qi] != nil else { return }
        if qi < questions.count - 1 { qi += 1; return }
        // The answers are saved as a quiz try; the server grades it (grade-quiz).
        if let quiz, !saved {
            saved = true
            let list = questions.enumerated().map { QuizAPI.Answer(questionId: $0.element.id, chosen: answers[$0.offset], hints: 0, confidence: nil) }
            Task { _ = await QuizAPI.saveAttempt(quizId: quiz.id, answers: list) }
        }
        step = 3
    }

    @ViewBuilder private var questionStep: some View {
        if qi < questions.count {
            let q = questions[qi]
            let chosen = answers[qi]
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rvQOf").replacingOccurrences(of: "{a}", with: Format.num(qi + 1, lang)).replacingOccurrences(of: "{b}", with: Format.num(questions.count, lang)))
                    .font(KFont.mono(11, .regular)).foregroundStyle(C.text2)
                Group {
                    Text(q.text).font(KFont.ui(19, .semibold, lang: qLang)).kLineHeight(1.4, size: 19, lang: qLang).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, o in
                        let right = chosen != nil && i == q.answer
                        let wrong = chosen == i && i != q.answer
                        Button { if chosen == nil { answers[qi] = i } } label: {
                            Text("\(["A", "B", "C", "D", "E"][min(i, 4)])) \(o)").font(KFont.ui(15, lang: qLang)).foregroundStyle(KPhone.text)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .background(right ? C.goodSoft : wrong ? C.priSoft : C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(right ? C.good : wrong ? C.priText : C.line, lineWidth: right || wrong ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                    if let chosen {
                        let ok = chosen == q.answer
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t(ok ? "rvCorrect" : "rvNotQuite")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(ok ? C.good : C.priText)
                            if !q.why.isEmpty { Text(q.why).font(KFont.ui(14, lang: qLang)).kLineHeight(1.5, size: 14, lang: qLang).foregroundStyle(KPhone.text) }
                            if let page = q.page { Text("\(t("rvSource")) \(Format.pagesShort(page, page, qLang))").font(KFont.mono(10, .regular)).foregroundStyle(C.text2) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ok ? C.goodSoft : C.priSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .environment(\.layoutDirection, qLang.isRTL ? .rightToLeft : .leftToRight)
                if chosen != nil { primary(t(qi >= questions.count - 1 ? "rvFinish" : "nextQ"), nextQuestion) }
            }
        } else {
            muted("rvNoQs")
            primary(t("rvFinish")) { step = 3 }
        }
    }

    // MARK: Result

    private var result: some View {
        let right = questions.enumerated().filter { answers[$0.offset] == $0.element.answer }.count
        let knew = known.values.filter { $0 }.count
        let again = cards.indices.filter { known[$0] == false }
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("rvDone")).font(KFont.ui(24, .semibold, lang: lang))
                HStack(spacing: 10) {
                    stat("\(Format.num(right, lang)) / \(Format.num(questions.count, lang))", t("rvQsRight"))
                    stat("\(Format.num(knew, lang)) / \(Format.num(cards.count, lang))", t("rvCardsKnown"))
                }
            }
            .foregroundStyle(KColor.onHero)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGradient.hero, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color(light: Color(hex: 0xE8925A, opacity: 0.22), dark: .clear), radius: 15, y: 14)
            if !again.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("rvAskedFirst")).font(KFont.ui(13, .semibold, lang: lang))
                    ForEach(again, id: \.self) { i in Text("• \(cards[i].question)").font(KFont.ui(13, lang: cards[i].lang)) }
                }
                .foregroundStyle(KPhone.text)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(C.ambLine, lineWidth: 1))
            }
            primary(t("rvFinish")) {
                Task {
                    if let review { await PlanAPI.setReview(review.id, done: true) }
                    toast.show(t("rvDone"))
                    app.reset(to: .home)
                }
            }
            ghost(t("rvAgain")) {
                known = [:]
                answers = [:]
                qi = 0
                saved = false
                toCards()
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(KFont.ui(26, .bold, lang: lang))
            Text(label).font(KFont.ui(12, lang: lang))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KPhone.heroChip, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
