import SwiftUI

/// What to play: the check after a section of the reader (its pages), or the end-of-lesson exam.
struct QuizTarget: Equatable {
    /// `exam`: an exam from the exam center (`quizId`), its questions from several lessons.
    enum Kind: Equatable { case check, final, exam }
    let materialId: String
    let kind: Kind
    var quizId: String? = nil
    var pageFrom = 0
    var pageTo = 0
}

/// Design: design/ScrQuiz.dc.html (multiple choice). Choose an option, say how sure you are, see right / wrong with
/// the lecturer's explanation and the PDF page; hints count half. The server grades the try (grade-quiz) and puts
/// wrong answers given with "Eminim" into the "Hatalarım" cards.
struct QuizView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    let target: QuizTarget

    private enum Phase { case ask, conf, reveal, result }

    @State private var quiz: Quiz?
    @State private var loaded = false
    @State private var index = 0
    @State private var phase: Phase = .ask
    @State private var selected: Int?
    @State private var confidence: Confidence?
    @State private var hintsShown = 0
    @State private var answers: [QuizAPI.Answer] = []
    @State private var score: Int?
    /// "Yeni 3 soru": questions already played in this section check, and whether new ones are being fetched.
    @State private var seen: [String] = []
    @State private var gettingNew = false
    /// The answer of a written question while it is typed (at most 800 characters, as in the design).
    @State private var typed = ""
    @FocusState private var typing: Bool

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
        static let ok = Color.pair(0x1E7A4C, 0x5BC893)
        static let onOk = Color.pair(0xFFFCF6, 0x0E2A1D)
        static let okSoft = Color.pair(0xE2F3E9, 0x173328)
        static let bad = Color.pair(0xC0352B, 0xF27A70)
        static let onBad = Color.pair(0xFFFCF6, 0x2A0F0D)
        static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
        static let blue = Color.pair(0x2557A8, 0x8DB4F5)
        static let blueSoft = Color.pair(0xE5EEFB, 0x1E2C45)
    }

    private var question: QuizQuestion? {
        guard let quiz, index < quiz.questions.count else { return nil }
        return quiz.questions[index]
    }
    private var total: Int { quiz?.questions.count ?? 0 }
    private var qLang: Lang { quiz?.lang ?? .tr }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if phase == .result { result } else if let question { body(question) } else { Spacer() }
            }
            if phase == .conf { confidenceSheet }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            let q: Quiz? = switch target.kind {
            case .check: await QuizAPI.sectionCheck(materialId: target.materialId, pageFrom: target.pageFrom, pageTo: target.pageTo)
            case .final: await QuizAPI.lessonExam(materialId: target.materialId)
            case .exam: target.quizId == nil ? nil : await QuizAPI.load(quizId: target.quizId!)
            }
            if let q, !q.questions.isEmpty { quiz = q } else {
                toast.show(t("quiz.none"))
                app.back()
            }
        }
        .animation(.easeOut(duration: 0.2), value: phase)
    }

    private var headerTitle: String {
        switch target.kind {
        case .check: d("BÖLÜM KONTROLÜ")
        case .final: d("DERS SONU SINAVI")
        case .exam: d("Sınav merkezi").uppercased(with: lang.locale)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { app.back() } label: {
                    KIcon(name: .close, size: 22, width: 1.8).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
                }
                .accessibilityLabel(d("Sınavdan çık"))
                .padding(.leading, -10)
                Text("\(headerTitle) · \(Format.num(min(index + 1, total), lang))/\(Format.num(total, lang))")
                    .font(KFont.mono(11, .regular)).tracking(lang.isRTL ? 0 : 1.1).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 34, height: 1)
            }
            .frame(height: 44)
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { i in
                    Capsule().fill(i < index || phase == .result ? C.pri : i == index ? C.amb : C.line).frame(height: 5)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .padding(.top, KLayout.top(54, minimum: 6))
    }

    // MARK: Question

    private func body(_ q: QuizQuestion) -> some View {
        Group { if q.written { writtenBody(q) } else { choiceBody(q) } }
    }

    private func choiceBody(_ q: QuizQuestion) -> some View {
        let reveal = phase == .reveal
        let right = selected == q.answer
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(d("ÇOKTAN SEÇMELİ")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1)
                        .foregroundStyle(C.text2).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(C.sub, in: RoundedRectangle(cornerRadius: 5))
                    Text(q.text).font(KFont.ui(21, .semibold, lang: qLang)).kLineHeight(1.35, size: 21, lang: qLang)
                        .foregroundStyle(KPhone.text).environment(\.layoutDirection, qLang.layoutDirection)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in optionRow(i, option, q: q, reveal: reveal) }
                    if phase == .ask && !q.hints.isEmpty { hints(q) }
                    if reveal {
                        if !right && confidence == .sure { danger } else { banner(right) }
                        explanation(q)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
            }
            footer(q)
        }
    }

    /// Design ScrQuiz "YAZILI SORU": write the answer, send it, then compare it with the model answer from the PDF.
    /// Like the web and the server (grade-quiz), a written answer is saved but not scored.
    private func writtenBody(_ q: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(d("YAZILI SORU")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1)
                        .foregroundStyle(C.ambText).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 5))
                    Text(q.text).font(KFont.ui(20, .semibold, lang: qLang)).kLineHeight(1.4, size: 20, lang: qLang)
                        .foregroundStyle(KPhone.text).environment(\.layoutDirection, qLang.layoutDirection)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if phase == .ask {
                        ZStack(alignment: .topLeading) {
                            if typed.isEmpty {
                                Text(d("Cevabını yaz ya da sesle anlat…")).font(KFont.reading(17, lang: qLang)).foregroundStyle(C.text3)
                                    .padding(.horizontal, 19).padding(.vertical, 22).allowsHitTesting(false)
                            }
                            TextEditor(text: $typed)
                                .font(KFont.reading(17, lang: qLang)).foregroundStyle(KPhone.text)
                                .scrollContentBackground(.hidden)
                                .focused($typing)
                                .padding(10)
                                .onChange(of: typed) { _, v in if v.count > 800 { typed = String(v.prefix(800)) } }
                                .accessibilityLabel(d("Cevabını yaz ya da sesle anlat…"))
                        }
                        .environment(\.layoutDirection, qLang.layoutDirection)
                        .frame(height: 250)
                        .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.pri, lineWidth: 2))
                        .padding(.top, 6)
                        HStack(spacing: 10) {
                            Button { toast.show(t("k165")) } label: {
                                HStack(spacing: 8) {
                                    KIcon(name: .mic, size: 16, width: 1.8)
                                    Text(d("Sesle yanıtla")).font(KFont.ui(14, .medium, lang: lang))
                                }
                                .foregroundStyle(KPhone.text)
                                .padding(.horizontal, 14).frame(height: 44)
                                .background(C.card, in: Capsule()).overlay(Capsule().stroke(C.line, lineWidth: 1))
                            }
                            Spacer()
                            Text("\(Format.num(typed.count, lang)) / \(Format.num(800, lang))").font(KFont.mono(11, .regular)).foregroundStyle(C.text3)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(d("SENİN CEVABIN")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.text3)
                            Text(typed).font(KFont.reading(14, italic: true, lang: qLang)).kLineHeight(1.55, size: 14, lang: qLang).foregroundStyle(C.text2)
                                .environment(\.layoutDirection, qLang.layoutDirection)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(C.sub, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        HStack(alignment: .top, spacing: 10) {
                            KIcon(name: .info, size: 18, width: 1.8).foregroundStyle(C.ambText)
                            Text(t("quizWrittenNote")).font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(KPhone.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        if !q.modelAnswer.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(d("MODEL CEVAP · PDF'TEN")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.ok)
                                Text(q.modelAnswer).font(KFont.reading(15, lang: qLang)).kLineHeight(1.6, size: 15, lang: qLang).foregroundStyle(KPhone.text)
                                    .environment(\.layoutDirection, qLang.layoutDirection)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(C.okSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        explanation(q)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            footer(q)
        }
    }

    private func optionRow(_ i: Int, _ text: String, q: QuizQuestion, reveal: Bool) -> some View {
        let chosen = i == selected
        var bg = C.card, border = C.line, width: CGFloat = 1, chipBg = C.sub, chipFg = C.text2
        var mark = String(UnicodeScalar(UInt8(65 + i))), note = "", noteFg = C.text3
        if !reveal && chosen { bg = C.priSoft; border = C.pri; width = 2; chipBg = C.pri; chipFg = KPhone.ctaText }
        if reveal && i == q.answer { bg = C.okSoft; border = C.ok; width = 2; chipBg = C.ok; chipFg = C.onOk; mark = "✓"; note = d("DOĞRU CEVAP"); noteFg = C.ok }
        if reveal && chosen && i != q.answer { bg = C.badSoft; border = C.bad; width = 2; chipBg = C.bad; chipFg = C.onBad; mark = "✕"; note = d("SENİN CEVABIN"); noteFg = C.bad }
        // The server writes "A) …" in some options; the letter is shown in the circle.
        let clean = text.replacingOccurrences(of: #"^[A-E][\)\.]\s*"#, with: "", options: .regularExpression)
        return Button {
            if phase == .ask { selected = i } else { toast.show(d("Bu soru cevaplandı · devam etmek için alttaki düğmeye bas")) }
        } label: {
            HStack(spacing: 12) {
                Text(mark).font(KFont.mono(13, .semibold)).foregroundStyle(chipFg).frame(width: 30, height: 30).background(chipBg, in: Circle())
                Text(clean).font(KFont.ui(16, lang: qLang)).foregroundStyle(KPhone.text).multilineTextAlignment(.leading)
                    .environment(\.layoutDirection, qLang.layoutDirection)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !note.isEmpty { Text(note).font(KFont.mono(10, .regular)).foregroundStyle(noteFg) }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: width))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func hints(_ q: QuizQuestion) -> some View {
        let n = min(hintsShown, q.hints.count)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<n, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(t("hintTag"))\(i + 1)\(d(" / 3 · yarım puan"))").font(KFont.mono(10, .regular)).foregroundStyle(C.ambText)
                    Text(q.hints[i]).font(KFont.ui(14, lang: qLang)).foregroundStyle(KPhone.text)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button {
                if n >= q.hints.count { toast.show(t("hintsDone")) } else { hintsShown += 1 }
            } label: {
                HStack(spacing: 6) {
                    KIcon(name: .bulb, size: 15, width: 1.7)
                    Text(n == 0 ? t("hintFirst") : n < q.hints.count ? "\(t("hintMore"))\(n)/\(q.hints.count))" : t("hintsDone"))
                        .font(KFont.ui(13, lang: lang))
                }
                .foregroundStyle(KPhone.text)
                .padding(.horizontal, 14).frame(height: 38)
                .background(n == 0 ? C.ambSoft : .clear, in: Capsule())
                .overlay(Capsule().stroke(C.line, lineWidth: 1))
            }
        }
    }

    private var danger: some View {
        HStack(alignment: .top, spacing: 12) {
            KIcon(name: .warning, size: 18, width: 2).foregroundStyle(C.onBad)
                .frame(width: 34, height: 34).background(C.bad, in: RoundedRectangle(cornerRadius: 10)).rotationEffect(.degrees(-8))
            VStack(alignment: .leading, spacing: 4) {
                Text(d("Dikkat: emin olduğunuz bir hata")).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(C.bad)
                Text(d("Emin olarak yapılan hatalar sınavda en çok puan kaybettirenlerdir. Bu soru tekrar listene ve kartlarına eklendi."))
                    .font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(KPhone.text)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.badSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.bad, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }

    private func banner(_ right: Bool) -> some View {
        HStack(spacing: 10) {
            KIcon(name: right ? .check : .close, size: 20, width: 2.2)
            Text(d(right ? "Doğru!" : "Yanlış")).font(KFont.ui(15, .bold, lang: lang)).frame(maxWidth: .infinity, alignment: .leading)
            if let confidence {
                Text(d(confidence == .sure ? "Eminim" : confidence == .unsure ? "Emin değilim" : "Tahmin ettim"))
                    .font(KFont.mono(10, .regular)).foregroundStyle(C.text2)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(C.card, in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .foregroundStyle(right ? C.ok : C.bad)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(right ? C.okSoft : C.badSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func explanation(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d("AÇIKLAMA")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(C.text3)
            if !q.why.isEmpty {
                Text(q.why).font(KFont.reading(15, lang: qLang)).kLineHeight(1.6, size: 15, lang: qLang).foregroundStyle(KPhone.text)
                    .environment(\.layoutDirection, qLang.layoutDirection)
            }
            if let page = q.page, let material = q.materialId ?? (target.materialId.isEmpty ? nil : target.materialId) {
                Button { app.readerPage = page; app.go(.reader(material)) } label: {
                    HStack(spacing: 6) {
                        Text(Self.lookAt(page, lang))
                        KIcon(name: .arrowRight, size: 16, width: 2, flipsInRTL: true)
                    }
                    .font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(C.priText)
                    .frame(minHeight: 40)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// "Sayfa 14'e bak" with the right Turkish ending; "See page 14" in the other languages.
    static func lookAt(_ page: Int, _ lang: Lang) -> String {
        switch lang {
        case .tr:
            let last = page % 10, tens = (page / 10) % 10
            // Ending follows the last spoken word: bir, iki, üç … / on, yirmi, otuz … / yüz.
            let word: String = last != 0 ? ["", "e", "ye", "e", "e", "e", "ya", "ye", "e", "a"][last]
                : tens != 0 ? ["", "a", "ye", "a", "a", "ye", "a", "e", "e", "a"][tens] : "e"
            return "Sayfa \(page)'\(word) bak"
        case .en: return "See page \(page)"
        case .fa: return "صفحهٔ \(Format.num(page, .fa)) را ببین"
        case .ar: return "انظر الصفحة \(page)"
        }
    }

    private func footer(_ q: QuizQuestion) -> some View {
        let empty = q.written ? typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selected == nil
        let disabled = phase == .ask && empty
        let last = index >= total - 1
        return Button {
            switch phase {
            // A written answer has no "how sure" step: it is not scored.
            case .ask where q.written: if !empty { typing = false; phase = .reveal }
            case .ask: if selected != nil { phase = .conf }
            case .reveal: next(q)
            default: break
            }
        } label: {
            Text(phase == .reveal ? d(last ? "Sınavı bitir" : "Sonraki soru") : d(q.written ? "Gönder" : "Cevapla"))
                .font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(disabled ? C.text3 : KPhone.ctaText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(disabled ? C.line : C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(disabled)
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
        .background(C.bg)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
    }

    // MARK: Confidence

    private var confidenceSheet: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x12171E, opacity: 0.45).ignoresSafeArea().onTapGesture { phase = .ask }
            VStack(alignment: .leading, spacing: 14) {
                Capsule().fill(C.line).frame(width: 36, height: 5).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text(d("Cevabından ne kadar eminsin?")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(d("Bu bilgi tekrar takvimini ayarlamamıza yardım eder.")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text3)
                }
                ForEach([(Confidence.sure, "Eminim", KIconName.check, C.okSoft, C.ok), (.unsure, "Emin değilim", .help, C.ambSoft, C.ambText), (.guess, "Tahmin ettim", .plus, C.blueSoft, C.blue)], id: \.1) { c, label, icon, bg, fg in
                    Button {
                        confidence = c
                        phase = .reveal
                    } label: {
                        HStack(spacing: 12) {
                            KIcon(name: icon, size: 16, width: 2).foregroundStyle(fg)
                                .frame(width: 30, height: 30).background(bg, in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(-7))
                            Text(d(label)).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16).frame(height: 56)
                        .background(C.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
            .background(C.card, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }

    // MARK: Flow

    private func next(_ q: QuizQuestion) {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        answers.append(.init(questionId: q.id, chosen: q.written ? nil : selected, hints: min(hintsShown, q.hints.count), confidence: q.written ? nil : confidence,
                             written: q.written ? text : nil))
        if index >= total - 1 {
            phase = .result
            let quizId = quiz?.id ?? ""
            let given = answers
            Task { score = await QuizAPI.saveAttempt(quizId: quizId, answers: given) }
        } else {
            index += 1
            selected = nil
            confidence = nil
            hintsShown = 0
            typed = ""
            phase = .ask
        }
    }

    /// Multiple-choice answers only: written ones are not scored.
    private var gradable: [QuizAPI.Answer] { answers.filter { $0.written == nil } }

    private var rightCount: Int {
        guard let quiz else { return 0 }
        return gradable.filter { a in quiz.questions.first { $0.id == a.questionId }?.answer == a.chosen }.count
    }

    private var result: some View {
        let wrong = gradable.count - rightCount
        let writtenCount = answers.count - gradable.count
        // Only written questions: nothing to score, the ring stays full.
        let pct = gradable.isEmpty ? 100 : score ?? Int((Double(rightCount) / Double(max(gradable.count, 1)) * 100).rounded())
        return VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().stroke(C.sub, lineWidth: 10)
                Circle().trim(from: 0, to: CGFloat(pct) / 100).stroke(pct >= 70 ? C.ok : C.amb, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(Format.percent(pct, lang)).font(KFont.ui(30, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text("\(Format.num(rightCount, lang))/\(Format.num(gradable.count, lang))").font(KFont.mono(12, .regular)).foregroundStyle(C.text3)
                }
            }
            .frame(width: 140, height: 140)
if !gradable.isEmpty {
                            Text(wrong == 0 ? t("allGood") : "\(Format.num(wrong, lang))\(t("wrongsA").components(separatedBy: ".").first ?? "").")
                .font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KPhone.text).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }
            if writtenCount > 0 {
                Text("\(prefs.t("quizWrittenCount", ["n": Format.num(writtenCount, lang)])) · \(t("quizWrittenNote"))")
                    .font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 10) {
                if target.kind == .check {
                    Button { app.back() } label: { primaryLabel(t("resume")) }
                    Button { newQuestions() } label: {
                        secondaryLabel(gettingNew ? t("packMaking") : t("newA") + Format.num(3, lang) + t("retryB"))
                    }
                    .disabled(gettingNew)
                } else if target.kind == .exam {
                    Button { app.back() } label: { primaryLabel(t("k47")) }
                } else {
                    // After the end-of-lesson exam: this lesson's summary ("Ders özeti"), as on the web.
                    Button { app.replace(.lessonSummary(target.materialId)) } label: { primaryLabel(t("lessonSummary")) }
                    Button { app.back() } label: { secondaryLabel(t("k47")) }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
            .frame(maxWidth: .infinity, minHeight: 52).background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func secondaryLabel(_ text: String) -> some View {
        Text(text).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
            .frame(maxWidth: .infinity, minHeight: 50).background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.line, lineWidth: 1))
    }

    /// "Yeni 3 soru" after a section check: unseen questions of the same pages first (free); when none are left, the
    /// server writes new ones (AI, needs the trial or Premium), then they are played.
    private func newQuestions() {
        guard !gettingNew, let quiz else { return }
        let had = seen + quiz.questions.map(\.id)
        gettingNew = true
        Task {
            var next = await QuizAPI.sectionCheck(materialId: target.materialId, pageFrom: target.pageFrom, pageTo: target.pageTo, seen: had)
            if next == nil {
                let r = await QuizAPI.moreSectionQuestions(materialId: target.materialId, pageFrom: target.pageFrom, pageTo: target.pageTo)
                if r != .ok {
                    gettingNew = false
                    return toast.show(t(r == .locked ? "trialLocked" : r == .budget ? "askBudget" : "askFailed"))
                }
                next = await QuizAPI.sectionCheck(materialId: target.materialId, pageFrom: target.pageFrom, pageTo: target.pageTo, seen: had)
            }
            gettingNew = false
            guard let next else { return toast.show(t("askFailed")) }
            seen = had
            self.quiz = next
            index = 0
            answers = []
            selected = nil
            confidence = nil
            hintsShown = 0
            score = nil
            typed = ""
            phase = .ask
        }
    }
}
