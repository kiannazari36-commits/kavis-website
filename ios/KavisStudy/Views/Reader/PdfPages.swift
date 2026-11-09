import PDFKit
import PencilKit
import SwiftUI

/// Text the student selected on a PDF page (its menu: Çevir / Kopyala / Vurgula / Asistana sor).
struct PdfSelection: Equatable {
    let text: String
    let page: Int
}

/// A request to show a page (section menu, page search); `n` makes the same page asked twice a new request.
struct PdfJump: Equatable {
    let page: Int
    let n: Int
}

/// The reader's "Orijinal PDF" (and the iPad's "tam ekran PDF"): the teacher's pages exactly as they are, one under
/// the other (PDFKit), with a PencilKit layer over every page (drawn in page coordinates, so the notes follow the page
/// when it scales). The lesson's hard words are underlined in amber (a tap opens their meaning), the student's
/// highlights are marked like a marker pen, and selected text goes to `onSelect`. The marks live only on screen: the
/// PDF file itself is never changed. Reports the page in the middle of the screen.
struct PdfPagesView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var page: Int
    let startPage: Int
    var jump: PdfJump?
    let writing: Bool
    @Binding var ink: [Int: InkPage]
    /// The lesson's hard words, by term key.
    let terms: [String: ReaderTerm]
    /// The open word (term key), painted amber.
    let selectedTerm: String?
    let highlights: [String]
    /// Room under the last page (the reader's bottom bar lies over it).
    var bottomInset: CGFloat = 0
    let onInk: (Int, [InkStroke]) -> Void
    let onTerm: (String?) -> Void
    var onSelect: (PdfSelection?) -> Void = { _ in }
    /// A new number takes the selection off (after a menu action).
    var clearSelection = 0

    static let amber = UIColor(red: 0.95, green: 0.70, blue: 0.24, alpha: 1)
    static let marker = UIColor(red: 0.95, green: 0.70, blue: 0.24, alpha: 0.45)

    func makeUIView(context: Context) -> PDFView {
        let v = QuietPDFView()
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
        context.coordinator.view = v
        context.coordinator.lastJump = jump
        context.coordinator.lastClear = clearSelection
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)),
                                               name: .PDFViewPageChanged, object: v)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.selected(_:)),
                                               name: .PDFViewSelectionChanged, object: v)
        context.coordinator.markTerms(in: document)
        context.coordinator.mark(highlights, in: document)
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
        c.mark(highlights, in: document)
        // Notes that arrive after the PDF (loaded from the server) fill the pages that are already on screen.
        for (canvas, pg) in c.pageOf { canvas.show(ink[pg] ?? InkPage()) }
        if clearSelection != c.lastClear {
            c.lastClear = clearSelection
            uiView.clearSelection()
        }
        if jump != c.lastJump {
            c.lastJump = jump
            if let jump, let p = document.page(at: max(0, min(jump.page, document.pageCount) - 1)) { uiView.go(to: p) }
        }
        if let scroll = uiView.subviews.compactMap({ $0 as? UIScrollView }).first {
            if scroll.contentInset.bottom != bottomInset {
                scroll.contentInsetAdjustmentBehavior = .never
                scroll.contentInset.bottom = bottomInset
            }
            c.watch(scroll, in: uiView)
            // With the pen on a finger draws instead of scrolling or selecting (the pen button again: scroll).
            if c.lastWriting != writing {
                c.lastWriting = writing
                scroll.isScrollEnabled = !writing
                Coordinator.gestures(in: uiView, on: !writing)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// The document stays with the reader (switching the view back shows it again): take this view's marks off it.
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.stop()
        coordinator.unmark()
        coordinator.hidePicker()
    }

    /// The system's own menu on selected text is left out: the reader shows its own (Çevir / Kopyala / Vurgula / Sor).
    final class QuietPDFView: PDFView {
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
        override func buildMenu(with builder: UIMenuBuilder) {
            super.buildMenu(with: builder)
            for menu in [UIMenu.Identifier.standardEdit, .lookup, .share, .learn, .replace, .speech, .format] { builder.remove(menu: menu) }
        }
    }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var parent: PdfPagesView
        var pageOf: [InkCanvasView: Int] = [:]
        var lastJump: PdfJump?
        var lastClear = 0
        var lastWriting = false

        /// PDFKit's own touches (scroll, select, zoom), not the pen layers' ones.
        static func gestures(in view: UIView, on: Bool) {
            guard !(view is PKCanvasView) else { return }
            for g in view.gestureRecognizers ?? [] where !(g is UITapGestureRecognizer && g.delegate is Coordinator) { g.isEnabled = on }
            for v in view.subviews { gestures(in: v, on: on) }
        }
        weak var view: PDFView?
        private var scrolling: NSKeyValueObservation?
        private let picker = PKToolPicker()
        /// Where each hard word stands on its page (one box per line), and the amber mark of the open one.
        private var hits: [(term: String, page: PDFPage, box: CGRect)] = []
        private var marked: (term: String, notes: [PDFAnnotation])?
        /// The highlights already marked on the pages.
        private var highlighted: Set<String> = []
        /// Every mark this view put on the pages.
        private var added: [PDFAnnotation] = []
        init(_ parent: PdfPagesView) { self.parent = parent }

        private func add(_ a: PDFAnnotation, to page: PDFPage) {
            page.addAnnotation(a)
            view?.annotationsChanged(on: page)
            added.append(a)
        }

        /// Leaving the PDF view with the pen on: the tool picker must not stay over the reader bar.
        func hidePicker() {
            for canvas in pageOf.keys {
                picker.setVisible(false, forFirstResponder: canvas)
                picker.removeObserver(canvas)
                canvas.resignFirstResponder()
            }
        }

        func stop() {
            scrolling?.invalidate()
            scrolling = nil
        }

        func unmark() {
            select(nil)
            for a in added { a.page?.removeAnnotation(a) }
            added = []
        }

        /// Finds every hard word in the PDF's text (ignoring case and accents) and underlines it in amber, so the
        /// student sees what can be tapped.
        func markTerms(in document: PDFDocument) {
            let words = parent.terms.filter { $0.value.surface.count >= 3 }
            guard !words.isEmpty else { return }
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i), let text = page.string as NSString?, text.length > 0 else { continue }
                for (key, term) in words {
                    var from = 0
                    while from < text.length {
                        let r = text.range(of: term.surface, options: [.caseInsensitive, .diacriticInsensitive],
                                           range: NSRange(location: from, length: text.length - from), locale: Locale(identifier: "tr"))
                        guard r.location != NSNotFound, r.length > 0 else { break }
                        from = r.location + r.length
                        for box in boxes(page, r) {
                            hits.append((key, page, box))
                            let u = PDFAnnotation(bounds: box, forType: .underline, withProperties: nil)
                            u.color = PdfPagesView.amber
                            add(u, to: page)
                        }
                    }
                }
            }
        }

        /// Marks the student's highlights where their text stands (line breaks and spaces may differ from the
        /// selection, as on the web, so any run of white space matches).
        func mark(_ texts: [String], in document: PDFDocument) {
            for text in texts where !highlighted.contains(text) {
                highlighted.insert(text)
                let words = text.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
                guard !words.isEmpty, let re = try? NSRegularExpression(pattern: words.joined(separator: "\\s*"), options: [.caseInsensitive]) else { continue }
                for i in 0..<document.pageCount {
                    guard let page = document.page(at: i), let s = page.string, !s.isEmpty else { continue }
                    for m in re.matches(in: s, range: NSRange(location: 0, length: (s as NSString).length)) {
                        for box in boxes(page, m.range) {
                            let a = PDFAnnotation(bounds: box, forType: .highlight, withProperties: nil)
                            a.color = PdfPagesView.marker
                            add(a, to: page)
                        }
                    }
                }
            }
        }

        private func boxes(_ page: PDFPage, _ range: NSRange) -> [CGRect] {
            guard let sel = page.selection(for: range) else { return [] }
            return sel.selectionsByLine().map { $0.bounds(for: page) }.filter { $0.width > 1 }
        }

        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard !parent.writing, let v = g.view as? PDFView else { return }
            let point = g.location(in: v)
            guard let page = v.page(for: point, nearest: false) else { parent.onTerm(nil); return }
            let p = v.convert(point, to: page)
            // A tap elsewhere closes the open word and takes the selection off.
            let term = hits.first { $0.page == page && $0.box.insetBy(dx: -2, dy: -4).contains(p) }?.term
            if term == nil, v.currentSelection != nil { v.clearSelection() }
            parent.onTerm(term)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        /// Paints the open word amber (as the design), and takes the paint off when it closes.
        func select(_ term: String?) {
            guard marked?.term != term else { return }
            for n in marked?.notes ?? [] {
                guard let page = n.page else { continue }
                page.removeAnnotation(n)
                view?.annotationsChanged(on: page)   // or PDFKit may keep the old paint on screen
            }
            marked = nil
            guard let term else { return }
            var notes: [PDFAnnotation] = []
            for h in hits where h.term == term {
                let a = PDFAnnotation(bounds: h.box, forType: .highlight, withProperties: nil)
                a.color = PdfPagesView.marker
                h.page.addAnnotation(a)
                view?.annotationsChanged(on: h.page)
                notes.append(a)
            }
            marked = (term, notes)
        }

        @objc func changed(_ note: Notification) {
            guard let v = note.object as? PDFView else { return }
            report(v)
        }

        /// PDFKit's own "page changed" can stay behind while scrolling: the page is also read from the scroll.
        func watch(_ scroll: UIScrollView, in v: PDFView) {
            guard scrolling == nil else { return }
            scrolling = scroll.observe(\.contentOffset) { [weak self, weak v] _, _ in
                guard let v else { return }
                DispatchQueue.main.async { self?.report(v) }
            }
        }

        /// The page at the upper third of the screen (where the student reads).
        private func report(_ v: PDFView) {
            guard let doc = v.document, let p = v.page(for: CGPoint(x: v.bounds.midX, y: v.bounds.height / 3), nearest: true) else { return }
            let n = doc.index(for: p) + 1
            if parent.page != n { parent.page = n }
        }

        @objc func selected(_ note: Notification) {
            guard let v = note.object as? PDFView else { return }
            let text = (v.currentSelection?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count > 1, let p = v.currentSelection?.pages.first, let doc = v.document else { parent.onSelect(nil); return }
            parent.onSelect(PdfSelection(text: text, page: doc.index(for: p) + 1))
        }

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let canvas = InkCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.drawingPolicy = .anyInput
            canvas.isScrollEnabled = false
            canvas.delegate = self
            canvas.isUserInteractionEnabled = parent.writing
            let number = (view.document?.index(for: page) ?? 0) + 1
            canvas.show(parent.ink[number] ?? InkPage())
            canvas.onStrokes = { [weak self] strokes in
                self?.parent.ink[number] = InkPage(strokes: strokes)
                self?.parent.onInk(number, strokes)
            }
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
            (canvasView as? InkCanvasView)?.drawingNow = true
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            (canvasView as? InkCanvasView)?.drawingNow = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            (canvasView as? InkCanvasView)?.changed()
        }
    }
}

/// The menu over selected PDF text (as the web): Çevir / Kopyala / Vurgula / Asistana sor.
struct PdfSelectionBar: View {
    @Environment(AppPrefs.self) private var prefs
    let onTranslate: () -> Void
    let onCopy: () -> Void
    let onHighlight: () -> Void
    let onAsk: () -> Void

    var body: some View {
        // Wide enough: one row; a narrow phone scrolls it sideways.
        ViewThatFits(in: .horizontal) {
            row.fixedSize()
            ScrollView(.horizontal) { row }.scrollIndicators(.hidden)
        }
        .background(KRead.pop, in: Capsule())
        .overlay(Capsule().stroke(KRead.popBorder, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.22), radius: 15, y: 10)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var row: some View {
        HStack(spacing: 6) {
            item(prefs.t("actTranslate"), onTranslate)
            item(prefs.t("actCopy"), onCopy)
            item(prefs.t("actHighlight"), onHighlight)
            Button(action: onAsk) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x9C2F3A)).frame(width: 8, height: 8)
                    Text(prefs.t("actAsk")).font(KFont.ui(13, .semibold, lang: prefs.lang))
                }
                .foregroundStyle(Color(hex: 0x2A2420))
                .padding(.horizontal, 16).frame(height: 40).background(KColor.amb, in: Capsule())
            }
        }
        .padding(6)
    }

    private func item(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(13, lang: prefs.lang)).foregroundStyle(Color(hex: 0x2A2420))
                .padding(.horizontal, 14).frame(height: 40).background(KRead.popChip, in: Capsule())
        }
    }
}
