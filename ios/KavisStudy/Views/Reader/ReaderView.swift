import AVFoundation
import SwiftUI

/// Design: design/NewReader.dc.html (phone reading page), with the lesson data and behaviour of the web reader.
/// The teacher's text is shown exactly as it is. Hard words open an explanation; the text is read aloud with the
/// phone's own voice; a sentence can be translated. Lesson data is a mock until the server exists.
struct ReaderView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(\.colorScheme) private var scheme

    let docID: String

    @State private var doc: ReaderDoc?
    @State private var sectionIndex = 1
    @State private var settings = SettingsAPI.loadNow()
    @State private var openTerm: String?
    @State private var translateText: String?
    @State private var seconds = 0
    @State private var paused = false
    @State private var speaker = Speaker()
    @State private var noteMode = false

    private static let fontSizes = [18, 20, 22, 24]

    init(docID: String) {
        self.docID = docID
        // Test switches: `-kavis.readerTerm t2` opens a term, `-kavis.readerSheet 1` opens the translation sheet.
        _openTerm = State(initialValue: MockFlag.value("readerTerm"))
        _translateText = State(initialValue: MockFlag.value("readerSheet") == "1"
            ? "İlk basamak tedavide Diüretikler, ACE inhibitörleri, anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır." : nil)
    }

    /// The reading theme: the student's choice, or light / dark mode until they choose.
    private var paperChoice: ReaderPaper {
        settings.readerPaperChosen ? settings.readerPaper : (scheme == .dark ? .dark : .sepia)
    }

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    var body: some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                themePicker
                if let doc {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(doc)
                            ForEach(doc.sections[sectionIndex].blocks) { block in
                                card(block, doc: doc)
                            }
                            sectionEnd(doc)
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Spacer()
                }
            }
            toolbar.frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 8)
            if let doc, let id = openTerm { termPopover(id, doc: doc) }
            if let text = translateText, let doc { translationSheet(text, doc: doc) }
        }
        .task {
            doc = await ReaderAPI.getDoc(id: docID)
            sectionIndex = min(sectionIndex, (doc?.sections.count ?? 1) - 1)
        }
        .task(id: paused) {
            // The study timer: counts every second while the student is reading.
            while !paused, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !paused { seconds += 1 }
            }
        }
        .onDisappear { speaker.stop() }
        .animation(.easeOut(duration: 0.2), value: openTerm)
        .animation(.easeOut(duration: 0.2), value: translateText)
    }

    // MARK: Top bar and theme

    private var fontSize: Int { Self.fontSizes.contains(settings.readerFontSize) ? settings.readerFontSize : 20 }

    private var pageLabel: String {
        guard let doc, let block = doc.sections[sectionIndex].blocks.first else { return "" }
        let label = t(block.page)
        let number = label.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) } ?? doc.page
        let percent = Int((Double(number) / Double(max(doc.pages, 1)) * 100).rounded())
        return "\(label) / \(Format.num(doc.pages, lang)) · \(Format.percent(percent, lang))"
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            circleButton(label: prefs.t("signup.k1052")) { app.back() } content: {
                KIcon(name: .back, size: 19, width: 1.8, flipsInRTL: true)
            }
            VStack(spacing: 2) {
                Text(doc?.title ?? "").font(KFont.reading(14, .semibold, lang: doc?.docLang ?? .tr)).foregroundStyle(KRead.text)
                Text(pageLabel).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.5).foregroundStyle(KRead.text2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(KRead.chrome, in: Capsule())
            .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
            circleButton(label: t("textSize")) { cycleFontSize() } content: {
                Text("Aa").font(KFont.reading(16, .bold, lang: .en))
            }
        }
        .padding(.horizontal, 16).padding(.top, KLayout.top(54, minimum: 6) + 6)
    }

    private func circleButton<Content: View>(label: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(KRead.text)
                .frame(width: 44, height: 44)
                .background(KRead.chrome, in: Circle())
                .overlay(Circle().stroke(KRead.line, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private func cycleFontSize() {
        let sizes = Self.fontSizes
        let next = sizes[((sizes.firstIndex(of: fontSize) ?? 1) + 1) % sizes.count]
        settings.readerFontSize = next
        Task { _ = await SettingsAPI.save(settings) }
        toast.show("\(t("fontSizePrefix"))\(next > fontSize ? t("fontBig") : t("fontSmall")) · \(Format.num(next, lang))")
    }

    private var themePicker: some View {
        HStack(spacing: 0) {
            ForEach([(ReaderPaper.light, "paperLight", 0xFFFCF6), (.sepia, "paperSepia", 0xF4E6CC), (.dark, "paperDark", 0x1D1915)], id: \.1) { paper, key, swatch in
                let on = paperChoice == paper
                Button {
                    settings.readerPaper = paper
                    settings.readerPaperChosen = true
                    Task { _ = await SettingsAPI.save(settings) }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: UInt32(swatch))).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(KRead.line, lineWidth: 1))
                        Text(t(key)).font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                    }
                    .foregroundStyle(on ? KRead.text : KRead.text2)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(on ? KRead.chrome : .clear, in: Capsule())
                    .shadow(color: on ? Color.black.opacity(0.12) : .clear, radius: 2, y: 1)
                }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(KRead.seg, in: Capsule())
        .padding(.horizontal, 16).padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("readingTheme"))
    }

    // MARK: Sections and page cards

    private func sectionHeader(_ doc: ReaderDoc) -> some View {
        Menu {
            ForEach(Array(doc.sections.enumerated()), id: \.offset) { i, section in
                Button(section.tab) { sectionIndex = i; openTerm = nil; speaker.stop() }
            }
        } label: {
            HStack(spacing: 10) {
                KIcon(name: .pill, size: 18, width: 1.7)
                    .foregroundStyle(KRead.chipFg)
                    .frame(width: 36, height: 36)
                    .background(KRead.chip, in: Circle())
                let parts = doc.sections[sectionIndex].tab.components(separatedBy: " · ")
                HStack(spacing: 6) {
                    Text("\(t("sectionWord").trimmingCharacters(in: .whitespaces)) \(parts.first ?? "")").font(KFont.ui(18, lang: lang)).foregroundStyle(KRead.text2)
                    Text("·").foregroundStyle(KRead.text2)
                    Text(parts.dropFirst().joined(separator: " · ")).font(KFont.reading(20, .semibold, lang: doc.docLang)).foregroundStyle(KRead.text)
                        .environment(\.layoutDirection, doc.docLang.layoutDirection)
                }
                KIcon(name: .chevronDown, size: 14, width: 2).foregroundStyle(KRead.text2)
            }
        }
        .accessibilityLabel(t("sections"))
    }

    private func card(_ block: ReaderBlock, doc: ReaderDoc) -> some View {
        let paper = KPaper.colors(paperChoice)
        let docLang = doc.docLang
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(t(block.page)).font(KFont.mono(11, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(paper.muted)
                Text(t(block.tag))
                    .font(KFont.ui(11, .semibold, lang: lang))
                    .foregroundStyle(block.tagStyle == "red" ? KRead.tagRedFg : KRead.tagVioFg)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(block.tagStyle == "red" ? KRead.tagRed : KRead.tagVio, in: Capsule())
                Spacer()
                Button { translateText = sentenceToTranslate(block, doc: doc) } label: {
                    Text(t("translate")).font(KFont.ui(12, lang: lang)).foregroundStyle(paper.ink)
                        .padding(.horizontal, 14).frame(height: 30)
                        .overlay(Capsule().stroke(paper.line, lineWidth: 1))
                }
            }
            if let heading = block.heading {
                Text(heading).font(KFont.reading(CGFloat(fontSize) - 2, .semibold, lang: docLang)).foregroundStyle(paper.ink)
                    .environment(\.layoutDirection, docLang.layoutDirection)
            }
            ForEach(Array(block.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph, paper: paper, docLang: docLang)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paper.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(paper.line, lineWidth: 1))
    }

    private func paragraphView(_ paragraph: Paragraph, paper: KPaper, docLang: Lang) -> some View {
        Text(attributed(paragraph, paper: paper))
            .font(KFont.reading(CGFloat(fontSize), lang: docLang))
            .kLineHeight(1.6, size: CGFloat(fontSize), lang: docLang)
            .foregroundStyle(paper.ink)
            .tint(paper.ink)
            .environment(\.layoutDirection, docLang.layoutDirection)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "kavis-term", let id = url.host { openTerm = id; return .handled }
                return .systemAction
            })
    }

    /// Hard words are tappable (dotted underline, the open one is highlighted); the text itself is never changed.
    private func attributed(_ paragraph: Paragraph, paper: KPaper) -> AttributedString {
        switch paragraph {
        case .selectable(let sentence):
            return AttributedString(sentence)
        case .segments(let segments):
            var out = AttributedString()
            for segment in segments {
                switch segment {
                case .text(let s):
                    out += AttributedString(s)
                case .term(let id, let word):
                    var a = AttributedString(word)
                    a.link = URL(string: "kavis-term://\(id)")
                    a.underlineStyle = Text.LineStyle(pattern: .dot, color: KRead.term)
                    if openTerm == id { a.backgroundColor = KRead.termBg }
                    out += a
                }
            }
            return out
        }
    }

    /// The card's sentence to translate: the lesson's sample sentence when this card has it, else the first paragraph.
    private func sentenceToTranslate(_ block: ReaderBlock, doc: ReaderDoc) -> String {
        if let sample = block.paragraphs.first(where: { $0.plain == doc.sampleSentence }) { return sample.plain }
        return block.paragraphs.first?.plain ?? ""
    }

    private func sectionEnd(_ doc: ReaderDoc) -> some View {
        let last = sectionIndex == doc.sections.count - 1
        return VStack(alignment: .leading, spacing: 10) {
            Text(t(doc.sections[sectionIndex].end)).font(KFont.ui(14, .medium, lang: lang)).foregroundStyle(KRead.text)
            HStack(spacing: 8) {
                Button { toast.show(prefs.t("k165")) } label: {
                    Text(t("start")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .padding(.horizontal, 18).frame(height: 40).background(KPhone.cta, in: Capsule())
                }
                if !last {
                    Button { sectionIndex += 1; speaker.stop() } label: {
                        Text(t("nextSection")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KRead.text)
                            .padding(.horizontal, 18).frame(height: 40)
                            .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KRead.chip, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Bottom bar

    private var timeText: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    private var toolbar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(timeText).font(KFont.mono(15, .semibold)).foregroundStyle(KRead.barChipFg).frame(minWidth: 52)
                Button { paused.toggle(); toast.show(paused ? t("pause") : t("resume")) } label: {
                    KIcon(name: paused ? .play : .pause, size: 16, width: 2.4)
                        .foregroundStyle(Color(hex: 0x2A2420))
                        .frame(width: 44, height: 44)
                        .background(KColor.amb, in: Circle())
                }
                .accessibilityLabel(paused ? t("resume") : t("pause"))
            }
            .padding(.leading, 14).padding(.trailing, 6)
            .frame(height: 56)
            .background(KRead.barChip, in: Capsule())
            Spacer(minLength: 0)
            barIcon(.pen, label: t("pen"), on: noteMode) { noteMode.toggle() }
            barIcon(.speaker, label: t("listen"), on: speaker.speaking) { readAloud() }
            Spacer(minLength: 0)
            Button { app.go(.assistant) } label: {
                Image("StarButton").resizable().scaledToFit().frame(width: 46, height: 46)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color(hex: 0x9C2F3A)))
            }
            .accessibilityLabel(t("assistant"))
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .background(KRead.bar, in: Capsule())
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.18), radius: 15, y: 10)
        .padding(.horizontal, 16)
    }

    private func barIcon(_ icon: KIconName, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 20, width: 1.7)
                .foregroundStyle(on ? KRead.barChipFg : KRead.barFg)
                .frame(width: 44, height: 44)
                .background(on ? KRead.barChip : .clear, in: Circle())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Reads the open section aloud with the phone's voice, in the language of the PDF.
    private func readAloud() {
        guard let doc else { return }
        if speaker.speaking { speaker.stop(); return }
        let text = doc.sections[sectionIndex].blocks.flatMap { block in
            [block.heading].compactMap { $0 } + block.paragraphs.map(\.plain)
        }.joined(separator: " ")
        speaker.speak(text, language: doc.language)
        toast.show(t("pageAloud"))
    }

    // MARK: Term explanation

    private func termPopover(_ id: String, doc: ReaderDoc) -> some View {
        let name = t("\(id)name")
        let en = doc.terms[id]?.en ?? ""
        return ZStack {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { openTerm = nil }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name).font(KFont.ui(18, .semibold, lang: lang))
                    Spacer()
                    Text(t("\(id)kind").uppercased()).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(KRead.popChip, in: RoundedRectangle(cornerRadius: 6))
                }
                Text(t("\(id)def")).font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang)
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    popButton(t("listen"), icon: .play) { speaker.speak(t("\(id)def"), language: lang.rawValue) }
                    popButton(t("addToCards")) { toast.show("\(name)\(t("addedToCards"))") }
                    popButton(t("translate"), primary: true) {
                        openTerm = nil
                        toast.show("\(name) → \(en)")
                    }
                }
            }
            .foregroundStyle(KRead.popFg)
            .padding(16)
            .frame(maxWidth: 360)
            .background(KRead.pop, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KRead.popBorder, lineWidth: 1))
            .shadow(color: Color(hex: 0x2A2420, opacity: 0.2), radius: 15, y: 12)
            .padding(.horizontal, 22)
            .offset(y: -20)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(t("termExpl"))
        }
        .transition(.opacity)
    }

    private func popButton(_ title: String, icon: KIconName? = nil, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { KIcon(name: icon, size: 11, width: 2) }
                Text(title).font(KFont.ui(13, primary ? .semibold : .regular, lang: lang))
            }
            .foregroundStyle(Color(hex: 0x2A2420).opacity(primary ? 1 : 0.9))
            .padding(.horizontal, 16).frame(height: 40)
            .background(primary ? KColor.amb : KRead.popChip, in: Capsule())
        }
    }

    // MARK: Translation

    private func translationSheet(_ text: String, doc: ReaderDoc) -> some View {
        TranslationSheet(sentence: text, doc: doc, style: settings.translationStyle, onClose: { translateText = nil })
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Translation sheet

/// Source sentence of the lecturer and its translation (language chips, literal / natural wording).
private struct TranslationSheet: View {
    @Environment(AppPrefs.self) private var prefs

    let sentence: String
    let doc: ReaderDoc
    let style: TranslationStyle
    var onClose: () -> Void

    @State private var target = "en"
    @State private var natural: Bool

    init(sentence: String, doc: ReaderDoc, style: TranslationStyle, onClose: @escaping () -> Void) {
        self.sentence = sentence
        self.doc = doc
        self.style = style
        self.onClose = onClose
        _natural = State(initialValue: style == .natural)
    }

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    var body: some View {
        let sample = doc.sampleTranslations[target]
        // The mock server translates only the sample sentence of the lesson.
        let translated = sentence == doc.sampleSentence ? (natural ? sample?.nat : sample?.lit) : nil
        ZStack(alignment: .bottom) {
            Color(hex: 0x140E0A, opacity: 0.45).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Color.pair(0xE2D7C6, 0x4A403A)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.bottom, 4)
                HStack {
                    Text(t("translation")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KRead.text)
                    Spacer()
                    Button(action: onClose) {
                        KIcon(name: .close, size: 14, width: 2.2).foregroundStyle(KRead.text2)
                            .frame(width: 36, height: 36).overlay(Circle().stroke(KRead.line, lineWidth: 1))
                    }
                    .accessibilityLabel(t("close"))
                }
                Text(t("sourceLabel")).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8).foregroundStyle(KRead.text2)
                Text(sentence).font(KFont.reading(17, lang: doc.docLang)).kLineHeight(1.5, size: 17, lang: doc.docLang)
                    .foregroundStyle(KRead.text).environment(\.layoutDirection, doc.docLang.layoutDirection)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    ForEach(["en", "fa", "ar"], id: \.self) { code in
                        chip(doc.sampleTranslations[code]?.l ?? code, on: target == code) { target = code }
                    }
                }
                HStack(spacing: 8) {
                    chip(t("literal"), on: !natural) { natural = false }
                    chip(t("natural"), on: natural) { natural = true }
                }
                Group {
                    if let translated, let sample {
                        Text(translated).font(KFont.reading(17, lang: Lang(rawValue: target) ?? .en))
                            .kLineHeight(1.5, size: 17, lang: Lang(rawValue: target) ?? .en)
                            .environment(\.layoutDirection, sample.dir == "rtl" ? .rightToLeft : .leftToRight)
                    } else {
                        Text(prefs.t("k165")).font(KFont.ui(14, lang: lang)).foregroundStyle(KRead.text2)
                    }
                }
                .foregroundStyle(KRead.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(KRead.chip.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(t(natural ? "hintNatural" : "hintLiteral")).font(KFont.ui(12, lang: lang)).foregroundStyle(KRead.text2)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
            .background(Color.pair(0xFFFBF4, 0x221C18), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: -10)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                .foregroundStyle(on ? KPhone.ctaText : KRead.text)
                .padding(.horizontal, 16).frame(height: 36)
                .background(on ? KPhone.cta : .clear, in: Capsule())
                .overlay(Capsule().stroke(on ? .clear : KRead.line, lineWidth: 1))
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Reading voice

/// Reads text aloud with the phone's own voice (no server needed).
@MainActor @Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var speaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        let tags = ["tr": "tr-TR", "en": "en-US", "fa": "fa-IR", "ar": "ar-SA"]
        utterance.voice = AVSpeechSynthesisVoice(language: tags[language] ?? language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.speaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.speaking = false }
    }
}

// MARK: - Colors

/// Colors of the phone reader (design/NewReader.dc.html).
enum KRead {
    static let bg = Color.pair(0xF1E9DA, 0x15120F)
    static let chrome = Color.pair(0xFBF6EC, 0x211C18)
    static let seg = Color.pair(0xE8DEC9, 0x211C18)
    static let text = Color.pair(0x2A2420, 0xEFE8DC)
    static let text2 = Color.pair(0x6E645A, 0xA89D90)
    static let line = Color.pair(0xE0D4BE, 0x3A322B)
    static let chip = Color.pair(0xFBEBC8, 0x3A2E18)
    static let chipFg = Color.pair(0x7A5208, 0xF2C46E)
    static let term = Color.pair(0x9C2F3A, 0xE8925A)
    static let termBg = Color(light: Color(hex: 0xF2B33D, opacity: 0.28), dark: Color(hex: 0xF2B33D, opacity: 0.16))
    static let tagVio = Color.pair(0xE8E6F6, 0x2C2A3A)
    static let tagVioFg = Color.pair(0x4A3F9A, 0xB9B4F0)
    static let tagRed = Color.pair(0xF5E3E2, 0x3A2224)
    static let tagRedFg = Color.pair(0x9C2F3A, 0xF09AA3)
    // The pop-up and the bottom bar are light in dark mode too.
    static let pop = Color.pair(0xFFFCF6, 0xEFE8DC)
    static let popFg = Color.pair(0x2A2420, 0x15120F)
    static let popChip = Color.pair(0xF1EBE0, 0xDDD2C1)
    static let popBorder = Color(light: Color(hex: 0xE6DDCF), dark: .clear)
    static let bar = Color.pair(0xFFFCF6, 0xEFE8DC)
    static let barChip = Color.pair(0xF5E3E2, 0x15120F)
    static let barFg = Color.pair(0x6E645A, 0x15120F)
    static let barChipFg = Color.pair(0x9C2F3A, 0xEFE8DC)
}

/// The page color of the chosen reading theme (Açık / Sepya / Koyu).
struct KPaper {
    let card: Color
    let ink: Color
    let line: Color
    let muted: Color

    static func colors(_ paper: ReaderPaper) -> KPaper {
        switch paper {
        case .light: KPaper(card: Color(hex: 0xFFFCF6), ink: Color(hex: 0x2A2420), line: Color(hex: 0xE6DDCF), muted: Color(hex: 0x8C8073))
        case .sepia: KPaper(card: Color(hex: 0xFBF5E8), ink: Color(hex: 0x3B3226), line: Color(hex: 0xEADFC9), muted: Color(hex: 0x7A6E5E))
        case .dark: KPaper(card: Color(hex: 0x1D1915), ink: Color(hex: 0xE6DDCF), line: Color(hex: 0x332B24), muted: Color(hex: 0x9A8F82))
        }
    }
}
