import AVFoundation
import PDFKit
import SwiftUI
import PencilKit

/// Design: design/NewReader.dc.html (phone reading page), with the lesson data and behaviour of the web reader
/// (`web/src/pages/Reader.tsx`). The teacher's text is shown exactly as it is. Hard words open an explanation; the
/// text is read aloud with the phone's own voice; a paragraph can be translated. Pages seen on screen are saved as
/// read, and the lesson opens at the page where the student stopped.
/// "Orijinal PDF | Okuma modu" (as the web, 4 Nov 2026): the teacher's own pages (PDFKit, with hard words,
/// highlights, the selection menu and the pen) or the reading page; lessons without a PDF file have only the second.
struct ReaderView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(\.colorScheme) private var scheme
    /// iPad (design NewIPad, reader): one wide header, section tabs, a 620 pt reading column and the assistant panel.
    @Environment(\.padRail) private var wide
    @Environment(TrialModel.self) private var trial

    let docID: String

    @State private var lesson: Lesson?
    @State private var loaded = false
    @State private var sectionIndex = 0
    @State private var settings = SettingsAPI.loadNow()
    @State private var openTerm: String?
    @State private var translateText: String?
    @State private var seconds = 0
    @State private var paused = false
    @State private var speaker = Speaker()
    @State private var noteMode = false
    /// Handwritten notes by page (loaded with the lesson) and the molecule open in its sheet.
    @State private var ink: [InkKey: InkPage] = [:]
    @State private var inkSaving: [InkKey: Task<Void, Never>] = [:]
    @State private var molecule: (mol: Molecule, page: Int)?
    /// The top block on screen (its index in the section) and every page seen since the last save.
    @State private var topBlock: Int?
    @State private var seen: Set<Int> = []
    @State private var atPage: Int?
    /// iPad: the assistant panel. Landscape: on the right, open by default (design). Portrait: a sheet over the lower part
    /// of the reading page, closed by default, so the reading column keeps its width.
    @State private var panelChoice: Bool?
    @State private var portrait = false
    private var panelOpen: Bool {
        get { panelChoice ?? !portrait }
        nonmutating set { panelChoice = newValue }
    }
    @State private var showPdf = false
    @State private var shareOpen = false
    /// "pdf" (default) or "text"; kept on this device, as the web keeps it per browser.
    @AppStorage("kavis.readerMode") private var modePref = "pdf"
    /// The lesson has an original PDF (a copy on the phone or a PDF file on the server).
    @State private var hasPdf = false
    @State private var pdfDoc: PDFDocument?
    @State private var pdfFailed = false
    /// The PDF page in the middle of the screen, the page it opens at and a jump asked by the section menu.
    @State private var pdfPage = 1
    @State private var startAt = 1
    @State private var pdfJump: PdfJump?
    /// Handwriting on the PDF pages (its own surface: other coordinates than the page cards).
    @State private var pdfInk: [Int: InkPage] = [:]
    @State private var pdfInkSaving: [Int: Task<Void, Never>] = [:]
    @State private var pdfSel: PdfSelection?
    @State private var clearSel = 0
    /// What the student highlighted ("Vurgula"), marked on the PDF and in reading mode.
    @State private var highlights: [String] = []
    @State private var pageAsk = false
    @State private var pageQuery = ""
    /// iPad: a question for the assistant panel (selected text); `panelKey` makes the panel ask it.
    @State private var panelQuestion = ""
    @State private var panelKey = 0
    private var pdfMode: Bool { hasPdf && modePref == "pdf" }
    /// The page the student is on (the assistant is told it).
    private var currentPage: Int { pdfMode ? pdfPage : (atPage ?? lesson?.lastPage ?? 1) }

    private static let fontSizes = [18, 20, 22, 24]

    init(docID: String) {
        self.docID = docID
    }

    /// The reading theme: the student's choice, or light / dark mode until they choose.
    private var paperChoice: ReaderPaper {
        settings.readerPaperChosen ? settings.readerPaper : (scheme == .dark ? .dark : .sepia)
    }

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }

    private var doc: ReaderDoc? { lesson?.doc }
    private var section: ReaderSection? {
        guard let doc, !doc.sections.isEmpty else { return nil }
        return doc.sections[min(sectionIndex, doc.sections.count - 1)]
    }

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
                .onChange(of: geo.size, initial: true) { _, size in portrait = size.height > size.width }
        }
    }

    private func content(_ size: CGSize) -> some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            HStack(spacing: 0) {
                ZStack {
                    readingColumn
                    if let pdfSel, pdfMode, openTerm == nil { selectionBar(pdfSel) }
                    else if pdfMode, pdfDoc != nil, !noteMode, let doc { pdfSectionEnd(doc) }
                    if section != nil || pdfMode {
                        toolbar.fixedSize(horizontal: wide, vertical: false)
                            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, wide ? 24 : 8)
                    }
                }
                if wide, !portrait, panelOpen, let lesson {
                    panel(lesson)
                    .frame(width: 380)
                    .padding(.vertical, 16).padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            if wide, portrait, panelOpen, let lesson {
                panel(lesson)
                .frame(maxWidth: 760)
                .frame(height: size.height * 0.62)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 6)
                .padding(.horizontal, 16).padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let lesson, let id = openTerm, let term = lesson.terms[id] { termPopover(term) }
            if let text = translateText, let lesson { translationSheet(text, lesson: lesson) }
            if shareOpen, let lesson { ShareDialog(materialId: docID, lessonTitle: lesson.title, onClose: { shareOpen = false }) }
        }
        .fullScreenCover(isPresented: $showPdf) {
            PdfFullView(materialId: docID, startPage: currentPage, terms: lesson?.terms ?? [:], highlights: highlights,
                        docLang: doc?.docLang ?? .tr, onHighlight: addHighlight,
                        onAsk: { q in showPdf = false; askPanel(q) }, onClose: { showPdf = false })
        }
        .task {
            guard !loaded else { return }
            lesson = await ReaderAPI.getLesson(id: docID)
            loaded = true
            restorePlace()
            hasPdf = await ReaderAPI.hasPdf(materialId: docID)
            highlights = await ReaderAPI.highlights(materialId: docID)
            ink = await InkAPI.load(materialId: docID)
            let recs = await RecordingAPI.recordingsOf(docID)
            recordingId = (recs.first { $0.status == "ready" } ?? recs.first)?.id
            marks = await RecordingAPI.lectureMarks(docID)
            // So the share button knows at once whether the student has Premium.
            if !trial.status.premium { await trial.refresh() }
        }
        .task(id: paused) {
            // The study timer: counts every second while the student is reading.
            while !paused, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !paused { seconds += 1 }
            }
        }
        .task(id: "\(sectionIndex)-\(topBlock ?? -1)-\(pdfMode ? pdfPage : -1)") { await savePlace() }
        .task(id: pdfMode) { await loadPdf() }
        .onChange(of: pdfPage) { _, p in
            seen.insert(p)
            // In the original PDF all pages stand one under the other: the open section is the one on screen.
            if pdfMode, let s = sectionOf(p) { sectionIndex = s }
        }
        .alert(t("pageFind"), isPresented: $pageAsk) {
            TextField(t("pageFind"), text: $pageQuery).keyboardType(.numberPad)
            Button(t("pageGo")) { jumpToPage() }
            Button(t("close"), role: .cancel) { pageQuery = "" }
        }
        .onDisappear {
            speaker.stop()
            if let lesson, let course = lesson.courseId {
                let s = seconds
                Task { await ReaderAPI.saveStudyTime(courseId: course, materialId: lesson.id, seconds: s) }
            }
        }
        .sheet(isPresented: Binding(get: { molecule != nil }, set: { if !$0 { molecule = nil } })) {
            if let molecule, let doc {
                MoleculeSheet(molecule: molecule.mol, page: molecule.page, contentLang: doc.docLang).presentationDetents([.large])
            }
        }
        .animation(.easeOut(duration: 0.2), value: openTerm)
        .animation(.easeOut(duration: 0.2), value: translateText)
        .animation(.easeOut(duration: 0.2), value: shareOpen)
        .animation(.easeOut(duration: 0.15), value: pdfSel)
    }

    // MARK: Original PDF

    /// The PDF (the phone's copy, else downloaded once) and its handwriting, the first time the PDF view opens.
    private func loadPdf() async {
        guard pdfMode, pdfDoc == nil, !pdfFailed else { return }
        guard let data = await ReaderAPI.pdfData(materialId: docID), let d = PDFDocument(data: data) else { pdfFailed = true; return }
        pdfDoc = d
        pdfPage = min(max(1, startAt), d.pageCount)
        seen.insert(pdfPage)
        pdfInk = await InkAPI.loadPdf(materialId: docID)
    }

    private func sectionOf(_ page: Int) -> Int? {
        guard let doc else { return nil }
        return doc.sections.firstIndex { page >= $0.pageFrom && page <= $0.pageTo }
            ?? doc.sections.lastIndex { $0.pageFrom <= page }
    }

    /// Switching the view keeps the page: the reading mode opens the section of the page on screen, the PDF the
    /// page of the card on screen.
    private func setMode(_ m: String) {
        guard m != (pdfMode ? "pdf" : "text") else { return }
        let page = currentPage
        pdfSel = nil
        openTerm = nil
        speaker.stop()
        noteMode = false
        modePref = m
        if m == "text" {
            guard let doc, let s = sectionOf(page) else { return }
            sectionIndex = s
            let b = doc.sections[s].blocks.firstIndex { page >= $0.pageFrom && page <= $0.pageTo } ?? 0
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                topBlock = b
            }
        } else {
            startAt = page
            pdfPage = page
        }
    }

    /// Section menu and page search in the PDF: show that page.
    private func showPage(_ page: Int) {
        pdfSel = nil
        openTerm = nil
        pdfJump = PdfJump(page: page, n: (pdfJump?.n ?? 0) + 1)
    }

    private func jumpToPage() {
        let p = Int(pageQuery.trimmingCharacters(in: .whitespaces)) ?? 0
        pageQuery = ""
        guard let pdfDoc, p >= 1, p <= pdfDoc.pageCount else { toast.show(t("pageNotFound")); return }
        showPage(p)
    }

    /// "Orijinal PDF | Okuma modu" (web: modeSeg).
    private var modeSwitch: some View {
        HStack(spacing: 0) {
            ForEach([("pdf", "modePdf"), ("text", "modeText")], id: \.0) { m, key in
                let on = (pdfMode ? "pdf" : "text") == m
                Button { setMode(m) } label: {
                    Text(t(key)).font(KFont.ui(13, on ? .semibold : .medium, lang: lang))
                        .foregroundStyle(on ? Color.white : KRead.text2)
                        .lineLimit(1)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(on ? Color(hex: 0x9C2F3A) : .clear, in: Capsule())
                }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(KRead.chrome, in: Capsule())
        .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("readerView"))
    }

    /// The phone's row under the header in the PDF: the switch, the page (tap: page search) and the section menu.
    private func pdfBar(_ doc: ReaderDoc?) -> some View {
        HStack(spacing: 8) {
            modeSwitch
            Spacer(minLength: 0)
            if let pdfDoc {
                Button { pageAsk = true } label: {
                    Text("\(Format.num(pdfPage, lang))/\(Format.num(pdfDoc.pageCount, lang))")
                        .font(KFont.mono(12, .medium)).foregroundStyle(KRead.text)
                        .padding(.horizontal, 12).frame(height: 38)
                        .background(KRead.chrome, in: Capsule())
                        .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
                }
                .accessibilityLabel(t("pageFind"))
            }
            if let doc, !doc.sections.isEmpty {
                Menu {
                    ForEach(Array(doc.sections.enumerated()), id: \.offset) { i, s in
                        Button("\(Format.num(i + 1, lang)) · \(s.title)") { goSection(i) }
                    }
                } label: {
                    KIcon(name: .chevronDown, size: 14, width: 2).foregroundStyle(KRead.text)
                        .frame(width: 38, height: 38)
                        .background(KRead.chrome, in: Circle())
                        .overlay(Circle().stroke(KRead.line, lineWidth: 1))
                }
                .accessibilityLabel(t("sections"))
            }
        }
    }

    private var pdfPane: some View {
        Group {
            if let pdfDoc {
                PdfPagesView(
                    document: pdfDoc, page: $pdfPage, startPage: startAt, jump: pdfJump, writing: noteMode, ink: $pdfInk,
                    terms: lesson?.terms ?? [:], selectedTerm: openTerm, highlights: highlights, bottomInset: 120,
                    onInk: { pg, strokes in savePdfInk(page: pg, strokes: strokes) },
                    onTerm: { key in
                        guard let key, lesson?.terms[key] != nil else { openTerm = nil; return }
                        if openTerm != key, let id = lesson?.terms[key]?.id { ReaderAPI.tapTerm(id) }
                        pdfSel = nil
                        openTerm = key
                    },
                    onSelect: { pdfSel = $0 },
                    clearSelection: clearSel
                )
                .padding(.top, 8)
            } else if pdfFailed {
                VStack(spacing: 14) {
                    Spacer()
                    Text(t("pdfFailed")).font(KFont.ui(15, lang: lang)).foregroundStyle(KRead.text2)
                    Button { modePref = "text" } label: {
                        Text(t("toReadingMode")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                            .padding(.horizontal, 22).frame(height: 44).background(KPhone.cta, in: Capsule())
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                    Text(t("pdfLoading")).font(KFont.ui(14, lang: lang)).foregroundStyle(KRead.text2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Saves a PDF page's handwriting a moment after the last stroke (the same surface as the iPad's full-screen PDF).
    private func savePdfInk(page: Int, strokes: [InkStroke]) {
        pdfInkSaving[page]?.cancel()
        let id = docID
        pdfInkSaving[page] = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await InkAPI.save(materialId: id, key: InkKey(page: page), strokes: strokes, surface: .pdf)
        }
    }

    private func addHighlight(_ sel: PdfSelection) {
        if !highlights.contains(sel.text) {
            highlights.append(sel.text)
            Task { await ReaderAPI.addHighlight(materialId: docID, page: sel.page, text: sel.text) }
        }
        toast.show(t("highlighted"))
    }

    /// After a menu action the selection goes (so the new highlight shows).
    private func done() {
        pdfSel = nil
        clearSel += 1
    }

    /// The menu over selected PDF text, just above the bottom bar.
    private func selectionBar(_ sel: PdfSelection) -> some View {
        PdfSelectionBar(
            onTranslate: { done(); translateText = sel.text },
            onCopy: { done(); UIPasteboard.general.string = sel.text; toast.show(t("copied")) },
            onHighlight: { done(); addHighlight(sel) },
            onAsk: { done(); askPanel(t("askSentence") + sel.text) }
        )
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, wide ? 100 : 82)
    }

    /// On the last page of a section (as the web, under that page): its check, and after the last one the summary.
    @ViewBuilder private func pdfSectionEnd(_ doc: ReaderDoc) -> some View {
        if let s = sectionOf(pdfPage), pdfPage == doc.sections[s].pageTo, let lesson {
            let last = s >= doc.sections.count - 1
            HStack(spacing: 8) {
                Text(last ? t("s4end") : t("secEnd", ["n": Format.num(s + 1, lang)]))
                    .font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KRead.text).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    let sec = doc.sections[s]
                    app.go(.quiz(QuizTarget(materialId: lesson.id, kind: last ? .final : .check, pageFrom: sec.pageFrom, pageTo: sec.pageTo, nextSection: last ? nil : s + 1)))
                } label: {
                    Text(t("start")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .padding(.horizontal, 16).frame(height: 36).background(KPhone.cta, in: Capsule())
                }
                if last {
                    Button { app.go(.lessonSummary(lesson.id)) } label: {
                        Text(t("lessonSummary")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KRead.text)
                            .padding(.horizontal, 14).frame(height: 36)
                            .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
                    }
                }
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(KRead.chip, in: Capsule())
            .frame(maxWidth: wide ? 620 : .infinity)
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, wide ? 100 : 82)
            .transition(.opacity)
        }
    }

    /// Asks the assistant about this lesson (and its open page). iPad: the panel; phone: the assistant's chat.
    private func askPanel(_ question: String?) {
        guard let lesson else { return }
        if wide {
            withAnimation(.easeOut(duration: 0.2)) { panelOpen = true }
            guard let question else { return }
            panelQuestion = question
            panelKey += 1
            // Asked once: a panel made again later (turning the iPad) must not ask it a second time.
            Task {
                try? await Task.sleep(for: .seconds(1))
                panelQuestion = ""
            }
        } else {
            app.go(.assistantChat(AssistantChatTarget(topicId: lesson.courseId ?? "all", question: question ?? "",
                                                      materialId: docID, lessonTitle: lesson.title, page: currentPage)))
        }
    }

    private func panel(_ lesson: Lesson) -> some View {
        AssistantChatView(
            target: AssistantChatTarget(topicId: lesson.courseId ?? "all", question: panelQuestion, materialId: docID,
                                        lessonTitle: lesson.title, page: currentPage),
            onClose: { withAnimation(.easeOut(duration: 0.2)) { panelOpen = false } }
        )
        .id(panelKey)
    }

    // MARK: Progress

    /// Coming back to a lesson: open the section and page where the student stopped.
    /// A page asked by the lesson summary ("Sayfaları oku", a weak topic's page) wins over the saved place.
    private func restorePlace() {
        let asked = app.readerPage
        app.readerPage = nil
        // After a section check: the next section, from its top (as on the web).
        if let next = app.readerSection {
            app.readerSection = nil
            if let doc, next < doc.sections.count { startAt = doc.sections[next].pageFrom; pdfPage = startAt; goSection(next); return }
        }
        startAt = max(1, asked ?? lesson?.lastPage ?? 1)
        pdfPage = startAt
        guard let lesson, let doc = lesson.doc, (asked ?? lesson.lastPage) > 1 else { return }
        let last = asked ?? lesson.lastPage
        guard let s = doc.sections.firstIndex(where: { $0.blocks.contains { last >= $0.pageFrom && last <= $0.pageTo } }) else { return }
        sectionIndex = s
        let b = doc.sections[s].blocks.firstIndex { last >= $0.pageFrom && last <= $0.pageTo } ?? 0
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            topBlock = b
        }
        if asked == nil { toast.show(t("resumeAt", ["p": Format.num(last, lang)])) }
    }

    /// A moment after scrolling stops: the pages seen are saved as read, and the page on screen as the place to
    /// open next time.
    private func savePlace() async {
        try? await Task.sleep(for: .milliseconds(1500))
        guard !Task.isCancelled, let lesson, !seen.isEmpty else { return }
        let at: Int
        if pdfMode { at = pdfPage } else if let section { at = section.blocks[min(topBlock ?? 0, section.blocks.count - 1)].pageFrom } else { return }
        atPage = at
        if let r = await ReaderAPI.markRead(lesson, pages: seen, at: at) {
            self.lesson?.pagesRead = r.pagesRead
            self.lesson?.percent = r.percent
            self.lesson?.lastPage = at
        }
    }

    private var notReady: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(lesson?.title ?? "").font(KFont.ui(18, .semibold, lang: lang)).foregroundStyle(KRead.text)
            Text(t("noReaderDoc")).font(KFont.ui(14, lang: lang)).foregroundStyle(KRead.text2).multilineTextAlignment(.center)
            Button { app.back() } label: {
                Text(prefs.t("signup.k1052")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .padding(.horizontal, 22).frame(height: 44).background(KPhone.cta, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: Top bar and theme

    private var fontSize: Int { Self.fontSizes.contains(settings.readerFontSize) ? settings.readerFontSize : 20 }

    /// "FARMAKOLOJİ · SAYFA 12/48 · %25" like the web.
    private var pageLabel: String {
        guard let lesson, lesson.doc != nil || pdfMode else { return "" }
        let n = pdfMode ? (pdfDoc?.pageCount ?? lesson.pageCount) : lesson.pageCount
        let info = "\(t("pageOf", ["p": Format.num(currentPage, lang), "n": Format.num(n, lang)])) · \(Format.percent(lesson.percent, lang))"
        return lesson.courseName.isEmpty ? info : "\(lesson.courseName.uppercased(with: lang.locale)) · \(info)"
    }

    /// Header, the theme row (phone) or section tabs (iPad), and the section's page cards.
    private var readingColumn: some View {
        VStack(spacing: 0) {
            if wide { wideTopBar } else { topBar }
            if wide {
                if let doc { sectionTabs(doc) } else if hasPdf { HStack { modeSwitch; Spacer() }.padding(.horizontal, 28).padding(.top, 14) }
            } else if pdfMode {
                pdfBar(doc).padding(.horizontal, 16).padding(.top, 10)
            } else {
                if hasPdf { HStack { modeSwitch; Spacer() }.padding(.horizontal, 16).padding(.top, 10) }
                themePicker
            }
            if pdfMode {
                pdfPane
            } else if let doc, let section {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !wide { sectionHeader(doc) }
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(section.blocks.enumerated()), id: \.offset) { i, block in
                                card(block, doc: doc, ink: InkKey(page: block.pageFrom, block: inkOrdinal(doc, block: i)))
                                    .id(i)
                                    .onAppear { for p in block.pageFrom...max(block.pageFrom, block.pageTo) { seen.insert(p) } }
                            }
                        }
                        .scrollTargetLayout()
                        sectionEnd(doc)
                    }
                    .frame(maxWidth: wide ? 620 : .infinity)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, wide ? 28 : 16).padding(.top, wide ? 14 : 12).padding(.bottom, 120)
                }
                .scrollPosition(id: $topBlock, anchor: .top)
                .scrollIndicators(.hidden)
                // With the pen on a finger draws on the cards instead of scrolling (as on the PDF pages).
                .scrollDisabled(noteMode)
            } else if loaded {
                notReady
            } else {
                Spacer()
            }
        }
    }

    // MARK: iPad header

    /// Back, the lesson title, the reading theme, recording, text size and the assistant panel button in one row.
    private var wideTopBar: some View {
        HStack(spacing: 10) {
            circleButton(label: prefs.t("signup.k1052")) { app.back() } content: {
                KIcon(name: .back, size: 19, width: 1.8, flipsInRTL: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson?.title ?? "").font(KFont.reading(24, .medium, lang: doc?.docLang ?? .tr)).foregroundStyle(KRead.text).lineLimit(1)
                Text(pageLabel).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(KRead.text2).lineLimit(1)
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            themeSegment(compact: true)
            if let recordingId {
                circleButton(label: t("recAudio")) { app.go(.recording(recordingId)) } content: {
                    KIcon(name: .mic, size: 19, width: 1.8)
                }
            }
            if lesson != nil { shareButton }
            circleButton(label: t("textSize")) { cycleFontSize() } content: {
                Text("Aa").font(KFont.reading(17, .semibold, lang: .en))
            }
            Button { withAnimation(.easeOut(duration: 0.2)) { panelOpen.toggle() } } label: {
                Image("StarButton").resizable().scaledToFit().frame(width: 34, height: 34)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(panelOpen ? Color(hex: 0x9C2F3A) : KRead.chrome))
                    .overlay(Circle().stroke(panelOpen ? .clear : KRead.line, lineWidth: 1))
            }
            .accessibilityLabel(t("panelToggle"))
            .accessibilityAddTraits(panelOpen ? .isSelected : [])
        }
        .padding(.horizontal, 28).padding(.top, KLayout.top(54, minimum: 6) + 10)
    }

    /// The lesson's sections as tabs ("1 · Tanım"), scrolling sideways when there are many.
    private func sectionTabs(_ doc: ReaderDoc) -> some View {
        ScrollViewReader { proxy in
            HStack(spacing: 10) {
            if hasPdf { modeSwitch.padding(.leading, 28) }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(doc.sections.enumerated()), id: \.offset) { i, s in
                        let on = i == sectionIndex
                        Button { goSection(i) } label: {
                            Text("\(Format.num(i + 1, lang)) · \(s.title)").font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                                .foregroundStyle(on ? KPhone.ctaText : KRead.text)
                                .lineLimit(1)
                                .padding(.horizontal, 16).frame(height: 36)
                                .background(on ? Color(hex: 0x9C2F3A) : KRead.chrome, in: Capsule())
                                .overlay(Capsule().stroke(on ? .clear : KRead.line, lineWidth: 1))
                        }
                        .id(i)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.leading, hasPdf ? 0 : 28).padding(.trailing, 28).padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            }
            .padding(.top, 14).padding(.bottom, 4)
            .onChange(of: sectionIndex) { _, i in withAnimation { proxy.scrollTo(i, anchor: .center) } }
            .accessibilityLabel(t("sections"))
        }
    }

    @State private var recordingId: String?
    /// What the lecturer said about each page in the recording ("Hoca burada sınavda çıkar dedi").
    @State private var marks: [RecordingAPI.LectureMark] = []

    private var topBar: some View {
        HStack(spacing: 8) {
            circleButton(label: prefs.t("signup.k1052")) { app.back() } content: {
                KIcon(name: .back, size: 19, width: 1.8, flipsInRTL: true)
            }
            VStack(spacing: 2) {
                Text(lesson?.title ?? "").font(KFont.reading(14, .semibold, lang: doc?.docLang ?? .tr)).foregroundStyle(KRead.text).lineLimit(1)
                Text(pageLabel).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.5).foregroundStyle(KRead.text2).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(KRead.chrome, in: Capsule())
            .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
            // The lesson's lecture recording, when there is one (as the web's "Ses kaydı" button).
            if let recordingId {
                circleButton(label: t("recAudio")) { app.go(.recording(recordingId)) } content: {
                    KIcon(name: .mic, size: 19, width: 1.8)
                }
            }
            if lesson != nil { shareButton }
            circleButton(label: t("textSize")) { cycleFontSize() } content: {
                Text("Aa").font(KFont.reading(16, .bold, lang: .en))
            }
        }
        .padding(.horizontal, 16).padding(.top, KLayout.top(54, minimum: 6) + 6)
    }

    /// Share what the app made of this lesson (design NewIPad "sh.open"); Premium only, else the paywall says why.
    private var shareButton: some View {
        circleButton(label: t("share")) {
            Task {
                // The saved status can be old (Premium bought on another device): ask the server before saying no.
                if trial.lockReason(for: .share) != nil { await trial.refresh() }
                if let key = trial.lockReason(for: .share) { app.go(.paywall(key)) } else { shareOpen = true }
            }
        } content: {
            KIcon(name: .share, size: 19, width: 1.8)
        }
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
        themeSegment(compact: false).padding(.horizontal, 16).padding(.top, 10)
    }

    /// Light / sepia / dark paper. Compact (iPad header): each choice as wide as its words.
    private func themeSegment(compact: Bool) -> some View {
        HStack(spacing: compact ? 4 : 0) {
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
                    .padding(.horizontal, compact ? 14 : 0)
                    .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 38 : 36)
                    .background(on ? KRead.chrome : .clear, in: Capsule())
                    .shadow(color: on ? Color.black.opacity(0.12) : .clear, radius: 2, y: 1)
                }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(KRead.seg, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("readingTheme"))
    }

    // MARK: Sections and page cards

    private func goSection(_ i: Int) {
        if pdfMode, let doc, i < doc.sections.count {
            sectionIndex = i
            speaker.stop()
            showPage(doc.sections[i].pageFrom)
            return
        }
        sectionIndex = i
        openTerm = nil
        speaker.stop()
        topBlock = 0
    }

    private func sectionHeader(_ doc: ReaderDoc) -> some View {
        Menu {
            ForEach(Array(doc.sections.enumerated()), id: \.offset) { i, s in
                Button("\(Format.num(i + 1, lang)) · \(s.title)") { goSection(i) }
            }
        } label: {
            HStack(spacing: 10) {
                KIcon(name: .pill, size: 18, width: 1.7)
                    .foregroundStyle(KRead.chipFg)
                    .frame(width: 36, height: 36)
                    .background(KRead.chip, in: Circle())
                HStack(spacing: 6) {
                    Text("\(t("sectionWord").trimmingCharacters(in: .whitespaces)) \(Format.num(sectionIndex + 1, lang))").font(KFont.ui(18, lang: lang)).foregroundStyle(KRead.text2)
                    Text("·").foregroundStyle(KRead.text2)
                    Text(section?.title ?? "").font(KFont.reading(20, .semibold, lang: doc.docLang)).foregroundStyle(KRead.text)
                        .lineLimit(2).multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, doc.docLang.layoutDirection)
                }
                KIcon(name: .chevronDown, size: 14, width: 2).foregroundStyle(KRead.text2)
            }
        }
        .accessibilityLabel(t("sections"))
    }

    private func pageText(_ block: ReaderBlock) -> String {
        block.pageTo > block.pageFrom
            ? t("pagesLabel", ["a": Format.num(block.pageFrom, lang), "b": Format.num(block.pageTo, lang)])
            : t("pageLabel", ["n": Format.num(block.pageFrom, lang)])
    }

    /// A note from the lecture recording on this page; tapping it opens the recording at that moment.
    private func lectureMark(_ m: RecordingAPI.LectureMark) -> some View {
        let exam = m.kind == "exam"
        let title = exam ? t("markExam") : m.kind == "stress" ? t("markStress") : t("markTime", ["n": Format.num(m.minutes, lang)])
        return Button { app.go(.recording(m.recordingId, at: m.at)) } label: {
            HStack(alignment: .top, spacing: 10) {
                KIcon(name: .mic, size: 15, width: 1.8).foregroundStyle(exam ? KRead.tagRedFg : KRead.chipFg).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KRead.text)
                    if !m.text.isEmpty {
                        Text("\u{201C}\(m.text)\u{201D}").font(KFont.reading(13, .regular, lang: lang)).foregroundStyle(KRead.text2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.clock(Int(m.at))).font(KFont.mono(12, .regular)).foregroundStyle(KRead.text2).padding(.top, 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(exam ? KRead.tagRed : KRead.chip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// The card's number among the cards of its page, over the whole lesson (as the web), so a drawing stays on its card.
    private func inkOrdinal(_ doc: ReaderDoc, block i: Int) -> Int {
        let s = min(sectionIndex, doc.sections.count - 1)
        let page = doc.sections[s].blocks[i].pageFrom
        let before = doc.sections[..<s].flatMap(\.blocks) + doc.sections[s].blocks[..<i]
        return before.filter { $0.pageFrom == page }.count
    }

    private func card(_ block: ReaderBlock, doc: ReaderDoc, ink key: InkKey) -> some View {
        let paper = KPaper.colors(paperChoice)
        let docLang = doc.docLang
        let tag = block.tagLabel
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(pageText(block)).font(KFont.mono(11, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(paper.muted)
                Text(t(tag.key))
                    .font(KFont.ui(11, .semibold, lang: lang))
                    .foregroundStyle(tag.red ? KRead.tagRedFg : KRead.tagVioFg)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(tag.red ? KRead.tagRed : KRead.tagVio, in: Capsule())
                Spacer()
                Button { translateText = block.paragraphs.first?.plain } label: {
                    Text(t("translate")).font(KFont.ui(12, lang: lang)).foregroundStyle(paper.ink)
                        .padding(.horizontal, 14).frame(height: 30)
                        .overlay(Capsule().stroke(paper.line, lineWidth: 1))
                }
            }
            ForEach(marks.filter { $0.page >= block.pageFrom && $0.page <= max(block.pageFrom, block.pageTo) }) { m in lectureMark(m) }
            if let heading = block.heading, !heading.isEmpty {
                Text(heading).font(KFont.reading(CGFloat(fontSize) - 2, .semibold, lang: docLang)).foregroundStyle(paper.ink)
                    .environment(\.layoutDirection, docLang.layoutDirection)
            }
            ForEach(Array(block.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph, paper: paper, docLang: docLang)
            }
            ForEach(MoleculeLibrary.find(in: ([block.heading].compactMap { $0 } + block.paragraphs.map(\.plain)).joined(separator: " ")), id: \.id) { m in
                Button { molecule = (m, block.pageFrom) } label: {
                    HStack(spacing: 8) {
                        KIcon(name: .flask, size: 16, width: 1.7)
                        Text("\(t("molecule").components(separatedBy: " · ")[0]) · \(m.text(m.name, docLang))").font(KFont.ui(13, .medium, lang: lang))
                    }
                    .foregroundStyle(paper.ink)
                    .padding(.horizontal, 14).frame(height: 38)
                    .overlay(Capsule().stroke(paper.line, lineWidth: 1))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paper.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(paper.line, lineWidth: 1))
        .overlay {
            InkCanvas(
                page: ink[key] ?? InkPage(),
                writing: noteMode,
                inkColor: UIColor(paper.ink),
                onChange: { ink[key] = InkPage(strokes: $0); saveInk(key, strokes: $0) }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Saves a page's handwriting a moment after the last stroke.
    private func saveInk(_ key: InkKey, strokes: [InkStroke]) {
        guard let id = lesson?.id else { return }
        inkSaving[key]?.cancel()
        inkSaving[key] = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await InkAPI.save(materialId: id, key: key, strokes: strokes)
        }
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
                if url.scheme == "kavis-term", let key = url.host(percentEncoded: false) {
                    openTerm = key
                    if let id = lesson?.terms[key]?.id { ReaderAPI.tapTerm(id) }
                    return .handled
                }
                return .systemAction
            })
    }

    /// Hard words are tappable (dotted underline, the open one is highlighted); the text itself is never changed.
    private func attributed(_ paragraph: Paragraph, paper: KPaper) -> AttributedString {
        switch paragraph {
        case .selectable(let sentence):
            return marked(AttributedString(sentence))
        case .segments(let segments):
            var out = AttributedString()
            for segment in segments {
                switch segment {
                case .text(let s):
                    out += AttributedString(s)
                case .term(let key, let word):
                    var a = AttributedString(word)
                    // Only words the server explained open a card.
                    if lesson?.terms[key] != nil, let url = termURL(key) {
                        a.link = url
                        a.underlineStyle = Text.LineStyle(pattern: .dot, color: KRead.term)
                        if openTerm == key { a.backgroundColor = KRead.termBg }
                    }
                    out += a
                }
            }
            return marked(out)
        }
    }

    /// The parts the student highlighted (on the PDF or here) marked like a marker pen; a highlight over a line
    /// break of the PDF matches the same words here.
    private func marked(_ text: AttributedString) -> AttributedString {
        guard !highlights.isEmpty else { return text }
        var out = text
        let plain = String(text.characters)
        for h in highlights {
            let words = h.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !words.isEmpty, let re = try? NSRegularExpression(pattern: words.joined(separator: "\\s*"), options: [.caseInsensitive]) else { continue }
            for m in re.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
                guard let r = Range(m.range, in: plain),
                      let lo = AttributedString.Index(r.lowerBound, within: out),
                      let hi = AttributedString.Index(r.upperBound, within: out) else { continue }
                out[lo..<hi].backgroundColor = KRead.marker
            }
        }
        return out
    }

    private func termURL(_ key: String) -> URL? {
        var c = URLComponents()
        c.scheme = "kavis-term"
        c.host = key
        return c.url
    }

    private func sectionEnd(_ doc: ReaderDoc) -> some View {
        let last = sectionIndex >= doc.sections.count - 1
        return VStack(alignment: .leading, spacing: 10) {
            Text(last ? t("s4end") : t("secEnd", ["n": Format.num(sectionIndex + 1, lang)])).font(KFont.ui(14, .medium, lang: lang)).foregroundStyle(KRead.text)
            HStack(spacing: 8) {
                // The short check of this section's pages; the last section opens the whole end-of-lesson exam.
                Button {
                    guard let lesson, let section else { return }
                    app.go(.quiz(QuizTarget(materialId: lesson.id, kind: last ? .final : .check, pageFrom: section.pageFrom, pageTo: section.pageTo, nextSection: last ? nil : sectionIndex + 1)))
                } label: {
                    Text(t("start")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .padding(.horizontal, 18).frame(height: 40).background(KPhone.cta, in: Capsule())
                }
                // After the last section: this lesson's summary ("Ders özeti"), as on the web.
                Button {
                    if last, let lesson { app.go(.lessonSummary(lesson.id)) } else { goSection(sectionIndex + 1) }
                } label: {
                    Text(t(last ? "lessonSummary" : "nextSection")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KRead.text)
                        .padding(.horizontal, 18).frame(height: 40)
                        .overlay(Capsule().stroke(KRead.line, lineWidth: 1))
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
            // iPad (design NewIPad): the bar also opens this lesson's flash cards.
            if wide, let lesson { barIcon(.cards, label: prefs.t("home.tileCards"), on: false) { app.go(.lessonCards(lesson.id)) } }
            if wide, lesson != nil { barIcon(.file, label: t("pdfFull"), on: false) { showPdf = true } }
            if !wide { Spacer(minLength: 0) }
            // On the iPad the header's star opens the assistant panel (design NewIPad), so the bar has none.
            if !wide {
                Button { app.go(.assistant) } label: {
                    Image("StarButton").resizable().scaledToFit().frame(width: 46, height: 46)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color(hex: 0x9C2F3A)))
                }
                .accessibilityLabel(t("assistant"))
            }
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

    /// Reads the open section aloud with the phone's voice, in the language of the PDF. In the PDF: the page on screen.
    private func readAloud() {
        if speaker.speaking { speaker.stop(); return }
        if pdfMode {
            guard let text = pdfDoc?.page(at: pdfPage - 1)?.string, !text.isEmpty else { return }
            speaker.speak(text, language: doc?.language ?? "tr", rate: Float(settings.ttsRate), female: settings.ttsVoice == .female)
            toast.show(t("pageAloud"))
            return
        }
        guard let doc, let section else { return }
        let text = section.blocks.flatMap { block in
            [block.heading].compactMap { $0 } + block.paragraphs.map(\.plain)
        }.joined(separator: " ")
        speaker.speak(text, language: doc.language, rate: Float(settings.ttsRate), female: settings.ttsVoice == .female)
        toast.show(t("pageAloud"))
    }

    // MARK: Term explanation

    private func termPopover(_ term: ReaderTerm) -> some View {
        let ex = term.explanation[lang.rawValue] ?? term.explanation["en"] ?? term.explanation.values.first
        let name = ex?.name ?? term.surface
        let english = term.explanation["en"]?.name
        return ZStack {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { openTerm = nil }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name).font(KFont.ui(18, .semibold, lang: lang))
                    Spacer()
                    if let kind = ex?.kind, !kind.isEmpty {
                        Text(kind.uppercased(with: lang.locale)).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(KRead.popChip, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Text(ex?.text ?? "").font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang)
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    popButton(t("listen"), icon: .play) { speaker.speak("\(name). \(ex?.text ?? "")", language: lang.rawValue) }
                    popButton(t("addToCards")) { Task { await addCard(term, name: name) } }
                    popButton(t("translate"), primary: true) {
                        openTerm = nil
                        if let english, lang != .en { toast.show("\(name) → \(english)") } else { translateText = term.surface }
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

    private func addCard(_ term: ReaderTerm, name: String) async {
        switch await ReaderAPI.addTermCard(term.id) {
        case .added: toast.show("\(name)\(t("addedToCards"))")
        case .already: toast.show("\(name)\(t("cardAlready"))")
        case .failed: toast.show(t("cardFailed"))
        }
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

    private func translationSheet(_ text: String, lesson: Lesson) -> some View {
        TranslationSheet(sentence: text, materialId: lesson.id, docLang: doc?.docLang ?? .tr, style: settings.translationStyle, onClose: { translateText = nil })
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Translation sheet

/// Source text of the lecturer and its translation (language chips, literal / natural wording). A saved translation
/// comes at once; a new one is made by the server's AI (Edge Function translate) and kept.
struct TranslationSheet: View {
    @Environment(AppPrefs.self) private var prefs

    let sentence: String
    let materialId: String
    let docLang: Lang
    var onClose: () -> Void

    @State private var target: Lang
    @State private var natural: Bool
    /// The translation of the chosen language and style (key "lang|style"), never the previous one's text.
    @State private var done: (key: String, text: Result<String, ReaderAPI.TranslateFailure>)?

    /// Every app language except the PDF's own.
    private var targets: [Lang] { Lang.allCases.filter { $0 != docLang } }

    init(sentence: String, materialId: String, docLang: Lang, style: TranslationStyle, onClose: @escaping () -> Void) {
        self.sentence = sentence
        self.materialId = materialId
        self.docLang = docLang
        self.onClose = onClose
        _target = State(initialValue: docLang == .en ? .tr : .en)
        _natural = State(initialValue: style == .natural)
    }

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }
    private var key: String { "\(target.rawValue)|\(natural)" }

    var body: some View {
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
                ScrollView {
                    Text(sentence).font(KFont.reading(17, lang: docLang)).kLineHeight(1.5, size: 17, lang: docLang)
                        .foregroundStyle(KRead.text).environment(\.layoutDirection, docLang.layoutDirection)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                HStack(spacing: 8) {
                    ForEach(targets) { code in chip(code.name, on: target == code) { target = code } }
                }
                HStack(spacing: 8) {
                    chip(t("literal"), on: !natural) { natural = false }
                    chip(t("natural"), on: natural) { natural = true }
                }
                Group {
                    switch done?.key == key ? done?.text : nil {
                    case .success(let text):
                        ScrollView {
                            Text(text).font(KFont.reading(17, lang: target)).kLineHeight(1.5, size: 17, lang: target)
                                .environment(\.layoutDirection, target.layoutDirection)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                    case .failure(let f):
                        Text(t(f == .locked ? "trLocked" : "trFailed")).font(KFont.ui(14, lang: lang)).foregroundStyle(KRead.text2)
                    case nil:
                        Text(t("translating")).font(KFont.ui(14, lang: lang)).foregroundStyle(KRead.text2)
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
        .task(id: key) {
            let k = key
            let r = await ReaderAPI.translate(materialId: materialId, text: sentence, to: target, style: natural ? .natural : .literal)
            if k == key { done = (k, r) }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                .foregroundStyle(on ? KPhone.ctaText : KRead.text)
                .padding(.horizontal, 14).frame(height: 36)
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

    /// `rate` is a speed factor (1 = normal); `female` picks a female voice when the phone has one.
    func speak(_ text: String, language: String, rate: Float = 0.95, female: Bool? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        let tags = ["tr": "tr-TR", "en": "en-US", "fa": "fa-IR", "ar": "ar-SA"]
        let code = tags[language] ?? language
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
        let wanted: AVSpeechSynthesisVoiceGender? = female.map { $0 ? .female : .male }
        utterance.voice = voices.first { wanted != nil && $0.gender == wanted } ?? AVSpeechSynthesisVoice(language: code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
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
    /// A highlight ("Vurgula"), as the web's marker colour.
    static let marker = Color(hex: 0xF2B33D, opacity: 0.45)
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
