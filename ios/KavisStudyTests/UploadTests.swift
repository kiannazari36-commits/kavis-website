import PDFKit
import UIKit
import XCTest
@testable import KavisStudy

final class UploadTests: XCTestCase {
    private func makePDF(pages: Int, withText: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        try renderer.writePDF(to: url) { context in
            for i in 0..<pages {
                context.beginPage()
                if withText {
                    ("Hypertension is defined as a systolic blood pressure of 140 mmHg or higher, page \(i + 1)" as NSString)
                        .draw(in: CGRect(x: 20, y: 20, width: 260, height: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
                } else {
                    UIColor.gray.setFill()
                    UIRectFill(CGRect(x: 20, y: 20, width: 200, height: 200)) // like a scanned page: only an image, no text
                }
            }
        }
        return url
    }

    func testInspectorReadsPagesAndText() throws {
        let text = try XCTUnwrap(PDFInspector.inspect(try makePDF(pages: 3, withText: true)))
        XCTAssertEqual(text.pages, 3)
        XCTAssertTrue(text.hasText)
        XCTAssertGreaterThan(text.megabytes, 0)
    }

    func testScannedPagesHaveNoText() throws {
        let scanned = try XCTUnwrap(PDFInspector.inspect(try makePDF(pages: 2, withText: false)))
        XCTAssertFalse(scanned.hasText, "a PDF without text must lead to the OCR error screen")
    }

    func testNotAPdfIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("x-\(UUID().uuidString).pdf")
        try Data("not a pdf".utf8).write(to: url)
        XCTAssertNil(PDFInspector.inspect(url))
    }

    func testFileMetaFormats() {
        XCTAssertEqual(Format.fileMeta(pages: 48, megabytes: 6.2, .tr), "48 sayfa · 6,2 MB")
        XCTAssertEqual(Format.fileMeta(pages: 48, megabytes: 6.2, .en), "48 pages · 6.2 MB")
    }

    func testHundredPageRule() {
        XCTAssertEqual(TrialLimits.pagesPerPdf, 100, "CLAUDE.md: each PDF max 100 pages")
    }

    /// Recognized words become lines at pauses, sentence ends and every 15 seconds (process-recording's segments).
    func testTranscriptLines() {
        typealias W = Transcriber.Word
        let words = [W(start: 0, end: 0.5, text: "Bugün"), W(start: 0.6, end: 1, text: "hipertansiyon."),
                     W(start: 4, end: 4.4, text: "Sınavda"), W(start: 4.5, end: 5, text: "soruyorum")]
        let lines = Transcriber.lines(words)
        XCTAssertEqual(lines.map(\.text), ["Bugün hipertansiyon.", "Sınavda soruyorum"])
        XCTAssertEqual(lines[1].start, 4)
        let long = (0..<40).map { W(start: Double($0), end: Double($0) + 0.8, text: "a") }
        XCTAssertTrue(Transcriber.lines(long).allSatisfy { $0.end - $0.start <= 15 })
        XCTAssertEqual(Format.clock(754), "12:34")
        XCTAssertEqual(Format.clock(3754), "1:02:34")
        XCTAssertEqual(RecordingAPI.mimeType("M4A"), "audio/mp4")
        XCTAssertNil(RecordingAPI.mimeType("webm"))
    }

    /// Photos are made at most 2000 px on the long side, as JPEG.
    func testShrinkPhoto() {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000)) }
        let data = UploadAPI.shrinkPhoto(big)
        let out = data.flatMap(UIImage.init(data:))
        XCTAssertEqual(out?.size.width, 2000)
        XCTAssertEqual(out?.size.height, 1500)
        XCTAssertEqual(data?.prefix(2), Data([0xFF, 0xD8]))
    }
}
