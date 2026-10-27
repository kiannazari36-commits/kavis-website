import PDFKit
import PencilKit
import SwiftUI

/// iPad (design NewIPad, "tam ekran PDF"): the teacher's original PDF pages, full screen, with the page number and
/// a pen (Apple Pencil or finger, system tool picker like the reader's notes) and a button back to the reader.
/// The term pop-up and the draggable assistant star of the design are not built yet.
struct PdfFullView: View {
    @Environment(AppPrefs.self) private var prefs

    let materialId: String
    var startPage = 1
    var onAsk: () -> Void
    var onClose: () -> Void

    @State private var document: PDFDocument?
    @State private var failed = false
    @State private var page = 1
    @State private var writing = false
    @State private var ink: [Int: PKDrawing] = [:]
    @State private var saving: [Int: Task<Void, Never>] = [:]

    var body: some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            if let document {
                PdfKitView(document: document, page: $page, startPage: startPage, writing: writing, ink: $ink,
                           onInk: { pg, drawing in saveInk(page: pg, drawing: drawing) })
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
                round(.sparkle, prefs.t("panelToggle"), fill: Color(hex: 0x9C2F3A), fg: Color(hex: 0xFFFCF6)) { onAsk() }
                round(.close, prefs.t("pdfClose"), fill: Color(hex: 0x14100D, opacity: 0.78), fg: Color(hex: 0xFFFCF6)) { onClose() }
            }
            .padding(.horizontal, 14).padding(.top, 16)
        }
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
    let onInk: (Int, PKDrawing) -> Void

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
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        let c = context.coordinator
        c.parent = self
        for (canvas, _) in c.pageOf {
            canvas.isUserInteractionEnabled = writing
            if !writing { canvas.resignFirstResponder() }
        }
        // Notes that arrive after the PDF (loaded from the server) fill the pages that are already on screen.
        for (canvas, pg) in c.pageOf where canvas.drawing.strokes.isEmpty {
            if let d = ink[pg], !d.strokes.isEmpty { canvas.drawing = d }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate {
        var parent: PdfKitView
        var pageOf: [PKCanvasView: Int] = [:]
        private let picker = PKToolPicker()
        init(_ parent: PdfKitView) { self.parent = parent }

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
