import PDFKit
import PencilKit
import SwiftUI

/// iPad (design NewIPad, "tam ekran PDF"): the teacher's original PDF pages, full screen, with the page number and
/// a pen (Apple Pencil or finger, system tool picker like the reader's notes) and a button back to the reader.
/// The lesson's hard words are underlined in amber; a tap opens their meaning ("Kartlara ekle", "Asistana sor").
/// Selected text has the reader's menu (Çevir / Kopyala / Vurgula / Asistana sor) and highlights are marked.
/// The assistant star sits bottom right and can be dragged anywhere (its place is kept).
struct PdfFullView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast

    let materialId: String
    var startPage = 1
    /// The lesson's hard words (`material_terms`), by key.
    var terms: [String: ReaderTerm] = [:]
    /// The student's highlights (shared with the reader, which saves new ones).
    var highlights: [String] = []
    /// The language of the PDF (for the translation).
    var docLang: Lang = .tr
    var onHighlight: (PdfSelection) -> Void = { _ in }
    /// Opens the assistant; with a question when asked about selected text.
    var onAsk: (String?) -> Void
    var onClose: () -> Void

    @State private var document: PDFDocument?
    @State private var failed = false
    @State private var page = 1
    @State private var writing = false
    @State private var ink: [Int: PKDrawing] = [:]
    @State private var saving: [Int: Task<Void, Never>] = [:]
    @State private var openTerm: ReaderTerm?
    @State private var selection: PdfSelection?
    @State private var clearSel = 0
    @State private var translateText: String?
    @State private var marks: [String] = []
    /// The star's place, as a move from its home corner (bottom right); kept between openings.
    @AppStorage("kavis.pdfStarX") private var starX = 0.0
    @AppStorage("kavis.pdfStarY") private var starY = 0.0
    @State private var starDrag: CGSize = .zero

    private var lang: Lang { prefs.lang }

    var body: some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            if let document {
                PdfPagesView(document: document, page: $page, startPage: startPage, writing: writing, ink: $ink,
                             terms: terms, selectedTerm: openTerm.flatMap { t in terms.first { $0.value.id == t.id }?.key },
                             highlights: highlights + marks,
                             onInk: { pg, drawing in saveInk(page: pg, drawing: drawing) },
                             onTerm: { key in
                                 if let key, let id = terms[key]?.id, openTerm?.id != id { ReaderAPI.tapTerm(id) }
                                 withAnimation(.easeOut(duration: 0.2)) { openTerm = key.flatMap { terms[$0] } }
                             },
                             onSelect: { sel in withAnimation(.easeOut(duration: 0.15)) { selection = sel } },
                             clearSelection: clearSel)
                    .ignoresSafeArea()
            } else if failed {
                Text(prefs.t("pdfLoadFail")).font(KFont.ui(15, lang: prefs.lang)).foregroundStyle(KRead.text2).padding(32)
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .top) {
            HStack {
                if let document {
                    Text(prefs.t("pdfPage", ["a": Format.num(page, prefs.lang), "b": Format.num(document.pageCount, prefs.lang)]))
                        .font(KFont.mono(13, .medium)).foregroundStyle(Color(hex: 0xFFFCF6))
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Color(hex: 0x14100D, opacity: 0.78), in: Capsule())
                }
                Spacer()
                round(.pen, prefs.t("pen"), fill: writing ? Color(hex: 0xF2B33D) : Color(hex: 0x14100D, opacity: 0.78),
                      fg: writing ? Color(hex: 0x2A2420) : Color(hex: 0xFFFCF6)) { writing.toggle() }
                    .accessibilityAddTraits(writing ? .isSelected : [])
                round(.close, prefs.t("pdfClose"), fill: Color(hex: 0x14100D, opacity: 0.78), fg: Color(hex: 0xFFFCF6)) { onClose() }
            }
            .padding(.horizontal, 14).padding(.top, 16)
        }
        .overlay { if document != nil { star } }
        .overlay(alignment: .bottom) {
            if let openTerm { termCard(openTerm) } else if let selection { selectionBar(selection).padding(.bottom, 104) }
        }
        .overlay {
            if let translateText {
                TranslationSheet(sentence: translateText, materialId: materialId, docLang: docLang,
                                 style: SettingsAPI.loadNow().translationStyle, onClose: { self.translateText = nil })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: translateText)
        .toastOverlay(toast, lang: lang)
        .task {
            guard let data = await ReaderAPI.pdfData(materialId: materialId),
                  let doc = PDFDocument(data: data) else { failed = true; return }
            document = doc
            ink = await InkAPI.load(materialId: materialId, surface: .pdf)
        }
    }

    /// Saves a page's handwriting a moment after the last stroke.
    private func saveInk(page: Int, drawing: PKDrawing) {
        saving[page]?.cancel()
        let id = materialId
        saving[page] = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await InkAPI.save(materialId: id, page: page, drawing: drawing, surface: .pdf)
        }
    }

    // MARK: Selected text

    private func selectionBar(_ sel: PdfSelection) -> some View {
        PdfSelectionBar(
            onTranslate: { done(); translateText = sel.text },
            onCopy: { done(); UIPasteboard.general.string = sel.text; toast.show(prefs.t("copied")) },
            onHighlight: {
                done()
                if !(highlights + marks).contains(sel.text) { marks.append(sel.text); onHighlight(sel) }
                toast.show(prefs.t("highlighted"))
            },
            onAsk: { done(); onAsk(prefs.t("askSentence") + sel.text) }
        )
        .padding(.horizontal, 16)
    }

    private func done() {
        selection = nil
        clearSel += 1
    }

    // MARK: Term pop-up (design NewIPad pdf.term)

    private func termCard(_ term: ReaderTerm) -> some View {
        let ex = term.explanation[lang.rawValue] ?? term.explanation["en"] ?? term.explanation.values.first
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(term.surface).font(KFont.ui(18, .semibold, lang: .tr)).foregroundStyle(KRead.popFg)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { openTerm = nil } } label: {
                    KIcon(name: .close, size: 13, width: 2).foregroundStyle(KRead.popFg)
                        .frame(width: 30, height: 30).background(KRead.popChip, in: Circle())
                }
                .accessibilityLabel(prefs.t("close"))
            }
            Text(prefs.t("pdfMeaning")).font(KFont.mono(10, .medium)).tracking(lang.isRTL ? 0 : 0.8).foregroundStyle(KRead.popFg.opacity(0.7))
            Text(ex?.text ?? "").font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).foregroundStyle(KRead.popFg)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { Task { await addCard(term) } } label: {
                    Text(prefs.t("addToCards")).font(KFont.ui(13, lang: lang)).foregroundStyle(Color(hex: 0x2A2420))
                        .padding(.horizontal, 16).frame(height: 40).background(KRead.popChip, in: Capsule())
                }
                Button { openTerm = nil; onAsk(nil) } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: 0x9C2F3A)).frame(width: 8, height: 8)
                        Text(prefs.t("askAssistant")).font(KFont.ui(13, .semibold, lang: lang))
                    }
                    .foregroundStyle(Color(hex: 0x2A2420))
                    .padding(.horizontal, 16).frame(height: 40).background(KColor.amb, in: Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: 420)
        .background(KRead.pop, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KRead.popBorder, lineWidth: 1))
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.25), radius: 18, y: 12)
        .padding(.horizontal, 22).padding(.bottom, 110)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(prefs.t("termExpl"))
    }

    private func addCard(_ term: ReaderTerm) async {
        let name = term.surface
        switch await ReaderAPI.addTermCard(term.id) {
        case .added: toast.show("\(name)\(prefs.t("addedToCards"))"); openTerm = nil
        case .already: toast.show("\(name)\(prefs.t("cardAlready"))")
        case .failed: toast.show(prefs.t("cardFailed"))
        }
    }

    // MARK: Assistant star (design NewIPad pdf.sDown: press and drag to move)

    private var star: some View {
        GeometryReader { geo in
            let size: CGFloat = 64
            // Home corner: 16 pt from the trailing edge, 24 pt from the bottom; kept inside the screen.
            let home = CGPoint(x: geo.size.width - 16 - size / 2, y: geo.size.height - 24 - size / 2)
            let x = min(max(home.x + starX + starDrag.width, size / 2 + 8), geo.size.width - size / 2 - 8)
            let y = min(max(home.y + starY + starDrag.height, size / 2 + 70), geo.size.height - size / 2 - 8)
            Image("StarButton").resizable().scaledToFit().frame(width: 46, height: 46)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(hex: 0x9C2F3A)))
                .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.4), radius: 14, y: 10)
                .contentShape(Circle())
                .position(x: x, y: y)
                .onTapGesture { onAsk(nil) }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { starDrag = $0.translation }
                        .onEnded { _ in
                            starX = x - home.x
                            starY = y - home.y
                            starDrag = .zero
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(prefs.t("askAssistant"))
                .accessibilityHint(prefs.t("pdfStarMove"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onAsk(nil) }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func round(_ icon: KIconName, _ label: String, fill: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 19, width: 1.8).foregroundStyle(fg).frame(width: 46, height: 46).background(fill, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
