import Foundation
import PencilKit
import Supabase
import UIKit

/// One line of the shared pen format (the web, iPhone and iPad all read and write it, `annotations.anchor.strokes`).
/// Points are parts of the page's (or card's) width and height (0–1); `w` is the line width as a part of the width
/// (old web lines have none: 3 pt); `tool` "marker" is see-through, "pencil" a little; no tool = pen.
struct InkStroke: Codable, Equatable {
    var color: String
    var w: Double?
    var tool: String?
    var points: [[Double]]
}

/// A page's (or card's) drawing. `legacy`: a drawing saved before 6 Nov 2026 as a PencilKit file; it is shown as it
/// was and turned into the shared format (and saved so) as soon as its page is on screen.
struct InkPage: Equatable {
    var strokes: [InkStroke] = []
    var legacy: PKDrawing?
    var isEmpty: Bool { strokes.isEmpty && (legacy?.strokes.isEmpty ?? true) }
}

/// Which drawing: the page, and for a reading card its number among the cards of that page (exam summaries put
/// several cards on one page). The original PDF's pages always have block 0.
struct InkKey: Hashable, Codable {
    let page: Int
    var block = 0
}

/// Handwritten notes (Apple Pencil or finger): one drawing per page, an `annotations` row of kind `ink` with its lines
/// in `anchor.strokes`. Two surfaces with different page shapes, kept apart: the reading cards (no `anchor.surface`,
/// `anchor.block` = the card's number on its page) and the original PDF pages (`anchor.surface = "pdf"`; the web
/// used "web_pdf" before, read as the same).
enum InkAPI {
    enum Surface { case card, pdf }

    private struct Anchor: Decodable { let surface: String?; let block: Int?; let strokes: [InkStroke]? }

    private struct Row: Decodable {
        let id: String; let page: Int; let ink_path: String?; let anchor: Anchor?

        init(from decoder: Decoder) throws {
            enum Key: String, CodingKey { case id, page, ink_path, anchor }
            let c = try decoder.container(keyedBy: Key.self)
            id = try c.decode(String.self, forKey: .id)
            page = try c.decode(Int.self, forKey: .page)
            ink_path = try c.decodeIfPresent(String.self, forKey: .ink_path)
            anchor = try? c.decodeIfPresent(Anchor.self, forKey: .anchor)
        }

        func on(_ surface: Surface) -> Bool {
            let s = anchor?.surface
            switch surface {
            case .pdf: return s == "pdf" || s == "web_pdf"
            case .card: return s == nil || s == "card"
            }
        }

        func key(_ surface: Surface) -> InkKey { InkKey(page: page, block: surface == .card ? (anchor?.block ?? 0) : 0) }
    }
    /// The old PencilKit file in the bucket `ink`.
    private struct File: Codable { let drawing: Data }

    /// Every saved drawing of a lesson on one surface.
    /// Without internet: the phone's copy (OfflineStore), kept up to date by every load and save.
    static func load(materialId: String, surface: Surface = .card) async -> [InkKey: InkPage] {
        let hasCopy = OfflineStore.read(keptFile(materialId, surface)) != nil
        guard let rows: [Row] = await OfflineStore.fromServer(hasCopy: hasCopy, { retry in
            try await supabase.from("annotations").select("id, page, ink_path, anchor")
                .eq("material_id", value: materialId).eq("kind", value: "ink").retry(enabled: retry).execute().value
        }) else { return kept(materialId, surface) }
        var result: [InkKey: InkPage] = [:]
        for row in rows where row.on(surface) {
            var page = result[row.key(surface)] ?? InkPage()
            if let strokes = row.anchor?.strokes {
                page.strokes += strokes
            } else if let path = row.ink_path,
                      let data = try? await supabase.storage.from("ink").download(path: path),
                      let file = try? JSONDecoder().decode(File.self, from: data),
                      let drawing = try? PKDrawing(data: file.drawing) {
                page.legacy = drawing
            }
            if !page.isEmpty { result[row.key(surface)] = page }
        }
        keep(result, materialId, surface)
        return result
    }

    /// The PDF surface by page number.
    static func loadPdf(materialId: String) async -> [Int: InkPage] {
        Dictionary(await load(materialId: materialId, surface: .pdf).map { ($0.key.page, $0.value) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: The phone's copy

    private struct Kept: Codable { let key: InkKey; let strokes: [InkStroke]; let legacy: Data? }

    private static func keptFile(_ materialId: String, _ surface: Surface) -> String {
        "ink2-\(materialId)\(surface == .pdf ? "-pdf" : "").json"
    }

    private static func kept(_ materialId: String, _ surface: Surface) -> [InkKey: InkPage] {
        if let data = OfflineStore.read(keptFile(materialId, surface)), let list = try? JSONDecoder().decode([Kept].self, from: data) {
            return Dictionary(list.map { ($0.key, InkPage(strokes: $0.strokes, legacy: $0.legacy.flatMap { try? PKDrawing(data: $0) })) },
                              uniquingKeysWith: { a, _ in a })
        }
        // The copy written before 6 Nov 2026: PencilKit drawings by page.
        guard let data = OfflineStore.read("ink-\(materialId)\(surface == .pdf ? "-pdf" : "").json"),
              let pages = try? JSONDecoder().decode([Int: Data].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: pages.compactMap { p, d in (try? PKDrawing(data: d)).map { (InkKey(page: p), InkPage(legacy: $0)) } })
    }

    private static func keep(_ pages: [InkKey: InkPage], _ materialId: String, _ surface: Surface) {
        let list = pages.map { Kept(key: $0.key, strokes: $0.value.strokes, legacy: $0.value.legacy?.dataRepresentation()) }
        guard let data = try? JSONEncoder().encode(list) else { return }
        OfflineStore.write(data, keptFile(materialId, surface))
    }

    // MARK: Saving

    private struct AnchorOut: Encodable { let surface: String?; let block: Int?; let strokes: [InkStroke] }
    /// The new lines; `ink_path` is written as null (an old PencilKit row turns into the shared format).
    private struct Update: Encodable {
        let anchor: AnchorOut
        func encode(to encoder: Encoder) throws {
            enum Key: String, CodingKey { case anchor, ink_path }
            var c = encoder.container(keyedBy: Key.self)
            try c.encode(anchor, forKey: .anchor)
            try c.encodeNil(forKey: .ink_path)
        }
    }

    /// Saves (or replaces) the drawing of one page or card; no lines removes the row. Old rows of the same page (an old
    /// PencilKit row, a web "web_pdf" row next to a "pdf" one) end as one row; their PencilKit files are removed.
    static func save(materialId: String, key: InkKey, strokes: [InkStroke], surface: Surface = .card) async {
        guard let uid = supabase.auth.currentUser?.id.uuidString.lowercased() else { return }
        // The phone's copy first, so a note written without internet is still there next time.
        var copy = kept(materialId, surface)
        copy[key] = strokes.isEmpty ? nil : InkPage(strokes: strokes)
        keep(copy, materialId, surface)
        guard let existing: [Row] = try? await supabase.from("annotations").select("id, page, ink_path, anchor")
            .eq("material_id", value: materialId).eq("kind", value: "ink").eq("page", value: key.page).execute().value else { return }
        let mine = existing.filter { $0.on(surface) && $0.key(surface) == key }
        let keepRow = strokes.isEmpty ? nil : mine.first
        let gone = mine.filter { $0.id != keepRow?.id }
        if !gone.isEmpty {
            _ = try? await supabase.from("annotations").delete().in("id", values: gone.map(\.id)).execute()
        }
        let files = mine.compactMap(\.ink_path)
        let anchor = AnchorOut(surface: surface == .pdf ? "pdf" : nil, block: surface == .card ? key.block : nil, strokes: strokes.map(rounded))
        if let keepRow {
            guard (try? await supabase.from("annotations").update(Update(anchor: anchor)).eq("id", value: keepRow.id).execute()) != nil else { return }
        } else if !strokes.isEmpty {
            struct New: Encodable { let user_id: String; let material_id: String; let page: Int; let kind = "ink"; let anchor: AnchorOut }
            guard (try? await supabase.from("annotations").insert(New(user_id: uid, material_id: materialId, page: key.page, anchor: anchor)).execute()) != nil else { return }
        }
        if !files.isEmpty { _ = try? await supabase.storage.from("ink").remove(paths: files) }
    }

    /// Numbers to 4 decimals: small rows, no visible difference (as the web).
    private static func rounded(_ s: InkStroke) -> InkStroke {
        let r = { (v: Double) in (v * 1e4).rounded() / 1e4 }
        var out = s
        out.w = s.w.map(r)
        out.points = s.points.map { $0.map(r) }
        return out
    }
}

/// PencilKit ⇄ the shared format, for a canvas of the given size.
enum InkFormat {
    /// Line width when a line has none (old web lines: 3 px).
    static let defaultWidth: CGFloat = 3

    /// The pen a card starts with: bordo, the web's pen too. One colour that reads on every paper and theme; the
    /// paper's own ink (dark brown) was unreadable on the web's dark theme. The student can pick any colour.
    static let cardPen = UIColor(red: 0x9C / 255, green: 0x2F / 255, blue: 0x3A / 255, alpha: 1)

    static func drawing(_ strokes: [InkStroke], size: CGSize) -> PKDrawing {
        guard size.width > 0, size.height > 0 else { return PKDrawing() }
        return PKDrawing(strokes: strokes.compactMap { s in
            guard !s.points.isEmpty else { return nil }
            let width = s.w.map { CGFloat($0) * size.width } ?? defaultWidth
            let type: PKInk.InkType = s.tool == "marker" ? .marker : s.tool == "pencil" ? .pencil : .pen
            let points = s.points.enumerated().map { i, p in
                PKStrokePoint(location: CGPoint(x: (p.first ?? 0) * size.width, y: (p.count > 1 ? p[1] : 0) * size.height),
                              timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: width, height: width),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(type, color: color(s.color)), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        })
    }

    static func strokes(_ drawing: PKDrawing, size: CGSize) -> [InkStroke] {
        guard size.width > 0, size.height > 0 else { return [] }
        return drawing.strokes.compactMap { s in
            let pts = Array(s.path.interpolatedPoints(by: .distance(3)))
            guard !pts.isEmpty else { return nil }
            let width = pts.map(\.size.width).reduce(0, +) / CGFloat(pts.count)
            let tool: String? = s.ink.inkType == .marker ? "marker" : s.ink.inkType == .pencil ? "pencil" : nil
            return InkStroke(color: hex(s.ink.color), w: Double(width / size.width), tool: tool,
                             points: pts.map { p in
                                 let at = p.location.applying(s.transform)
                                 return [Double(at.x / size.width), Double(at.y / size.height)]
                             })
        }
    }

    private static func color(_ hex: String) -> UIColor {
        let v = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).prefix(6), radix: 16) ?? 0x9C2F3A
        return UIColor(red: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    private static func hex(_ c: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: &a)
        let n = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", n(r), n(g), n(b))
    }
}

/// A PencilKit canvas that shows a drawing in the shared format: it draws it again whenever its size changes, and
/// reports each change in the shared format. An old PencilKit drawing is shown as it was and reported once, turned.
final class InkCanvasView: PKCanvasView {
    private(set) var page = InkPage()
    var onStrokes: ([InkStroke]) -> Void = { _ in }
    private var shownSize: CGSize = .zero
    private var applied: PKDrawing?
    /// A line is being drawn: a drawing set now would cancel it, so a new size waits until the line ends.
    var drawingNow = false {
        didSet { if !drawingNow { setNeedsLayout() } }
    }

    func show(_ p: InkPage) {
        guard p != page else { return }
        page = p
        shownSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !drawingNow, bounds.width > 0, bounds.height > 0, bounds.size != shownSize else { return }
        shownSize = bounds.size
        // An old PencilKit drawing as it was, with the page's lines in the shared format (from the web) on top.
        let lines = InkFormat.drawing(page.strokes, size: bounds.size)
        let d = page.legacy.map { $0.appending(lines) } ?? lines
        applied = d
        drawing = d
        if page.legacy != nil {
            let turned = InkFormat.strokes(d, size: bounds.size)
            page = InkPage(strokes: turned)
            DispatchQueue.main.async { self.onStrokes(turned) }
        }
    }

    /// Call from `canvasViewDrawingDidChange`: the student's change (a drawing set by `show` is not one).
    func changed() {
        guard drawing != applied, bounds.width > 0 else { return }
        applied = drawing
        let strokes = InkFormat.strokes(drawing, size: bounds.size)
        page = InkPage(strokes: strokes)
        onStrokes(strokes)
    }
}
