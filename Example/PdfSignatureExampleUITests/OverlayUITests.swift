import XCTest

/// Real touches on the demo: items can be dragged and deleted, and the PDF still scrolls
/// underneath the item overlay.
final class OverlayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-psdkDemoPage", "1"]
        app.launch()
    }

    private func logLine(_ prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func testDragMovesTheItem() {
        let signature = app.buttons["psdk-item-signature-1"]
        XCTAssertTrue(signature.waitForExistence(timeout: 10))
        let before = signature.frame
        let start = signature.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 90)))
        XCTAssertTrue(logLine("signatureMoved").waitForExistence(timeout: 5))
        XCTAssertGreaterThan(signature.frame.minX, before.minX + 30)
        XCTAssertGreaterThan(signature.frame.minY, before.minY + 45)
    }

    func testDeleteButtonRemovesTheItem() {
        let stamp = app.buttons["psdk-item-estamp-1"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 10))
        // The delete button sits on the item's top-right corner
        stamp.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0)).tap()
        XCTAssertTrue(logLine("signatureRemoved").waitForExistence(timeout: 5))
        XCTAssertFalse(stamp.exists)
    }

    func testPageScrollsUnderTheOverlay() {
        XCTAssertTrue(app.buttons["psdk-item-signature-1"].waitForExistence(timeout: 10))
        let page = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6))
        page.press(forDuration: 0.05, thenDragTo: page.withOffset(CGVector(dx: 0, dy: -400)))
        // A long drag can skip a page, so any later page counts
        XCTAssertTrue(logLine("pageChanged").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Halaman 1/5 · 2 item"].exists)
    }
}
