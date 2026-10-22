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
}
