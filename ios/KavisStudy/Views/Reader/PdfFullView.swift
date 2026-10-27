import PDFKit
import SwiftUI

/// iPad (design NewIPad, "tam ekran PDF"): the teacher's original PDF pages, full screen, with the page number and
/// a button back to the reader. Pen, term pop-up and the draggable assistant star of the design are not built yet.
struct PdfFullView: View {
    @Environment(AppPrefs.self) private var prefs

    let materialId: String
    var onAsk: () -> Void
    var onClose: () -> Void

    @State private var document: PDFDocument?
    @State private var failed = false
    @State private var page = 1

    var body: some View {
        ZStack {
            KRead.bg.ignoresSafeArea()
            if let document {
                PdfKitView(document: document, page: $page).ignoresSafeArea()
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
        }
    }

    private func round(_ icon: KIconName, _ label: String, fill: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 19, width: 1.8).foregroundStyle(fg).frame(width: 46, height: 46).background(fill, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

/// PDFKit's scrolling page view; reports the page that is in the middle of the screen.
private struct PdfKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var page: Int

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        v.backgroundColor = UIColor(KRead.bg)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)),
                                               name: .PDFViewPageChanged, object: v)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    final class Coordinator: NSObject {
        let page: Binding<Int>
        init(page: Binding<Int>) { self.page = page }
        @objc func changed(_ note: Notification) {
            guard let v = note.object as? PDFView, let p = v.currentPage, let doc = v.document else { return }
            page.wrappedValue = doc.index(for: p) + 1
        }
    }
}
