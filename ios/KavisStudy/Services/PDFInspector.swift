import Foundation
import PDFKit

/// What the upload screen needs to know about a PDF the student picked.
struct PickedPDF: Equatable {
    var name: String
    var pages: Int
    var megabytes: Double
    /// False for scanned pages: no text can be read, so the student must try text recognition (OCR).
    var hasText: Bool
}

enum PDFInspector {
    /// Reads page count, size and whether there is selectable text. The picker gives a security-scoped URL.
    static func inspect(_ url: URL) -> PickedPDF? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else { return nil }
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let sample = (0..<min(document.pageCount, 5)).compactMap { document.page(at: $0)?.string }
        let letters = sample.joined().filter { !$0.isWhitespace }.count
        return PickedPDF(name: url.lastPathComponent, pages: document.pageCount, megabytes: Double(bytes) / 1_048_576, hasText: letters > 20)
    }
}
