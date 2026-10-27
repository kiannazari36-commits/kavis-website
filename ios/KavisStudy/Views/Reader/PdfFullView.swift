import PDFKit
import PencilKit
import SwiftUI

/// iPad (design NewIPad, "tam ekran PDF"): the teacher's original PDF pages, full screen, with the page number and
/// a pen (Apple Pencil or finger, system tool picker like the reader's notes) and a button back to the reader.
/// The lesson's hard words are underlined in amber; a tap opens their meaning ("Kartlara ekle", "Asistana sor").
/// The assistant star sits bottom right and can be dragged anywhere (its place is kept).
struct PdfFullView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast

    let materialId: String
    var startPage = 1
    /// The lesson's hard words (`material_terms`), by key.
    var terms: [String: ReaderTerm] = [:]
    var onAsk: () -> Void
    var onClose: () -> Void

    @State private var document: PDFDocument?
    @State private var failed = false
    @State private var page = 1
    @State private var writing = false
    @State private var ink: [Int: PKDrawing] = [:]
    @State private var saving: [Int: Task<Void, Never>] = [:]
    @State private var openTerm: ReaderTerm?
    /// The star's place, as a move from its home corner (bottom right); kept between openings.
    @AppStorage("kavis.pdfStarX") private var starX = 0.0
    @AppStorage("kavis.pdfStarY") private var starY = 0.0
    @State private var starDrag: CGSize = .zero

    private var lang: Lang { prefs.lang }

    var body: some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            if let document {
                PdfKitView(document: document, page: $page, startPage: startPage, writing: writing, ink: $ink,
                           terms: Array(terms.values), selectedTerm: openTerm?.id,
                           onInk: { pg, drawing in saveInk(page: pg, drawing: drawing) },
                           onTerm: { id in withAnimation(.easeOut(duration: 0.2)) { openTerm = id.flatMap { id in terms.values.first { $0.id == id } } } })
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
        .overlay(alignment: .bottom) { if let openTerm { termCard(openTerm) } }
        .toastOverlay(toast, lang: lang)
        .task {
            guard let url = await ReaderAPI.pdfURL(materialId: materialId),
                  let data = try? await URLSession.shared.data(from: url).0,
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
                Button { openTerm = nil; onAsk() } label: {
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
                .onTapGesture { onAsk() }
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
                .accessibilityAction { onAsk() }
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

/// PDFKit's scrolling page view with a PencilKit layer over every page (drawn in page coordinates, so the notes
/// follow the page when it scales); reports the page in the middle of the screen.
private struct PdfKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var page: Int
    let startPage: Int
    let writing: Bool
    @Binding var ink: [Int: PKDrawing]
    let terms: [ReaderTerm]
    let selectedTerm: String?
    let onInk: (Int, PKDrawing) -> Void
    let onTerm: (String?) -> Void

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.pageOverlayViewProvider = context.coordinator   // before the document, or no page asks for its layer
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        v.backgroundColor = UIColor(KRead.bg)
        if let p = document.page(at: max(0, min(startPage, document.pageCount) - 1)) {
            DispatchQueue.main.async { v.go(to: p) }
        }
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)),
                                               name: .PDFViewPageChanged, object: v)
        context.coordinator.markTerms(in: document)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        let c = context.coordinator
        c.parent = self
        for (canvas, _) in c.pageOf {
            canvas.isUserInteractionEnabled = writing
            if !writing { canvas.resignFirstResponder() }
        }
        c.select(selectedTerm)
        // Notes that arrive after the PDF (loaded from the server) fill the pages that are already on screen.
        for (canvas, pg) in c.pageOf where canvas.drawing.strokes.isEmpty {
            if let d = ink[pg], !d.strokes.isEmpty { canvas.drawing = d }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var parent: PdfKitView
        var pageOf: [PKCanvasView: Int] = [:]
        private let picker = PKToolPicker()
        /// Where each hard word stands on its page (one box per line), and the amber mark of the open one.
        private var hits: [(term: String, page: PDFPage, box: CGRect)] = []
        private var marked: (term: String, notes: [PDFAnnotation])?
        init(_ parent: PdfKitView) { self.parent = parent }

        /// Finds every hard word in the PDF's text (ignoring case and accents) and underlines it in amber, so the
        /// student sees what can be tapped. The PDF file itself is not changed (the marks live only on screen).
        func markTerms(in document: PDFDocument) {
            let words = parent.terms.filter { $0.surface.count >= 3 }
            guard !words.isEmpty else { return }
            let amber = UIColor(red: 0.95, green: 0.70, blue: 0.24, alpha: 1)
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i), let text = page.string as NSString?, text.length > 0 else { continue }
                for term in words {
                    var from = 0
                    while from < text.length {
                        let r = text.range(of: term.surface, options: [.caseInsensitive, .diacriticInsensitive],
                                           range: NSRange(location: from, length: text.length - from), locale: Locale(identifier: "tr"))
                        guard r.location != NSNotFound, r.length > 0 else { break }
                        from = r.location + r.length
                        guard let sel = page.selection(for: r) else { continue }
                        for line in sel.selectionsByLine() {
                            let box = line.bounds(for: page)
                            guard box.width > 1 else { continue }
                            hits.append((term.id, page, box))
                            let u = PDFAnnotation(bounds: box, forType: .underline, withProperties: nil)
                            u.color = amber
                            page.addAnnotation(u)
                        }
                    }
                }
            }
        }

        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard !parent.writing, let v = g.view as? PDFView else { return }
            let point = g.location(in: v)
            guard let page = v.page(for: point, nearest: false) else { parent.onTerm(nil); return }
            let p = v.convert(point, to: page)
            // A tap elsewhere closes the open word.
            parent.onTerm(hits.first { $0.page == page && $0.box.insetBy(dx: -2, dy: -4).contains(p) }?.term)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        /// Paints the open word amber (as the design), and takes the paint off when it closes.
        func select(_ term: String?) {
            guard marked?.term != term else { return }
            for n in marked?.notes ?? [] { n.page?.removeAnnotation(n) }
            marked = nil
            guard let term else { return }
            var notes: [PDFAnnotation] = []
            for h in hits where h.term == term {
                let a = PDFAnnotation(bounds: h.box, forType: .highlight, withProperties: nil)
                a.color = UIColor(red: 0.95, green: 0.70, blue: 0.24, alpha: 0.45)
                h.page.addAnnotation(a)
                notes.append(a)
            }
            marked = (term, notes)
        }

        @objc func changed(_ note: Notification) {
            guard let v = note.object as? PDFView, let p = v.currentPage, let doc = v.document else { return }
            parent.page = doc.index(for: p) + 1
        }

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let canvas = PKCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.drawingPolicy = .anyInput
            canvas.isScrollEnabled = false
            canvas.delegate = self
            canvas.isUserInteractionEnabled = parent.writing
            let number = (view.document?.index(for: page) ?? 0) + 1
            if let d = parent.ink[number] { canvas.drawing = d }
            pageOf[canvas] = number
            return canvas
        }

        func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PKCanvasView else { return }
            picker.addObserver(canvas)
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PKCanvasView else { return }
            picker.removeObserver(canvas)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let number = pageOf[canvasView] else { return }
            parent.ink[number] = canvasView.drawing
            parent.onInk(number, canvasView.drawing)
        }
    }
}
