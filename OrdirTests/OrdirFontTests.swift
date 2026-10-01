//
//  OrdirFontTests.swift
//  OrdirTests
//
//  The bundled typeface must register, or every Text silently falls back to the system font.
//

import UIKit
import XCTest
@testable import Ordir

final class OrdirFontTests: XCTestCase {
    func testGoogleSansFlexRegistersWithItsWeights() {
        OrdirFont.register()  // already done at launch; registering again is harmless
        XCTAssertTrue(UIFont.familyNames.contains(OrdirFont.family), "Google Sans Flex is not registered")
        for name in ["GoogleSansFlex-Regular", "GoogleSansFlex-SemiBold", "GoogleSansFlex-Bold"] {
            XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) is missing")
        }
    }
}
