import UIKit
import XCTest
@testable import KavisStudy

final class FontsTests: XCTestCase {
    func testBrandFontsAreBundled() {
        for name in ["Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold", "Poppins-Bold"] {
            XCTAssertNotNil(UIFont(name: name, size: 12), "\(name) is missing")
        }
        for family in ["Lora", "JetBrains Mono", "Vazirmatn"] {
            XCTAssertFalse(UIFont.fontNames(forFamilyName: family).isEmpty, "\(family) is missing")
        }
    }

    func testPersianAndArabicAreRightToLeft() {
        XCTAssertEqual(Lang.allCases.filter(\.isRTL), [.fa, .ar])
    }
}
