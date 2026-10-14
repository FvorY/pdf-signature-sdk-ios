@testable import PdfSignatureSDK
import XCTest

final class PdfSignatureSDKTests: XCTestCase {
    func testVersionIsSemver() {
        let parts = PdfSignatureSDK.version.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        XCTAssertTrue(parts.allSatisfy { Int($0) != nil })
    }

    func testMirrorsWebSdk112() {
        XCTAssertEqual(PdfSignatureSDK.webParityVersion, "1.1.2")
    }

    func testPrivacyManifestIsBundled() {
        XCTAssertNotNil(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }
}
