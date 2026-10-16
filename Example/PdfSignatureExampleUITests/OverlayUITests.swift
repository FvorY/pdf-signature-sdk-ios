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

    /// Repeats `gesture` until `done` appears: a simulator that has just booted can drop a touch.
    private func perform(_ gesture: () -> Void, until done: XCUIElement, attempts: Int = 3) {
        for _ in 0..<attempts {
            gesture()
            if done.waitForExistence(timeout: 10) { return }
        }
        XCTFail("\(done) did not appear")
    }

    private func logLine(_ prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func testDragMovesTheItem() {
        let signature = app.buttons["psdk-item-signature-1"]
        XCTAssertTrue(signature.waitForExistence(timeout: 30))
        let before = signature.frame
        perform({
            let start = signature.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 90)))
        }, until: logLine("signatureMoved"))
        XCTAssertGreaterThan(signature.frame.minX, before.minX + 30)
        XCTAssertGreaterThan(signature.frame.minY, before.minY + 45)
    }

    func testDeleteButtonRemovesTheItem() {
        let stamp = app.buttons["psdk-item-estamp-1"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 30))
        // The delete button sits on the item's top-right corner
        perform({ stamp.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0)).tap() }, until: logLine("signatureRemoved"))
        XCTAssertFalse(stamp.exists)
    }

    func testPageScrollsUnderTheOverlay() {
        XCTAssertTrue(app.buttons["psdk-item-signature-1"].waitForExistence(timeout: 30))
        // Drag on the pages area, left of the items, so the touch is not on an item
        let pages = app.otherElements["psdk-pages"]
        let start = pages.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.9))
        // A long drag can skip a page, so any later page counts
        perform({
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -pages.frame.height * 0.8)))
        }, until: logLine("pageChanged"))
        XCTAssertFalse(app.staticTexts["Halaman 1/5 · 2 item"].exists)
    }

    /// SDK toolbar: the add button opens the grouped picker and places the chosen role.
    func testToolbarPickerPlacesASignature() {
        XCTAssertTrue(app.buttons["psdk-item-signature-1"].waitForExistence(timeout: 30))
        let option = app.buttons["Eksternal · Klien"]
        perform({ app.buttons["Tambah Tanda Tangan"].firstMatch.tap() }, until: option)
        option.tap()
        XCTAssertTrue(logLine("signaturePlaced Klien").waitForExistence(timeout: 15))
    }

    /// Phone ⋯ menu: zoom in changes the zoom shown in the status line.
    func testMoreMenuZooms() {
        XCTAssertTrue(app.buttons["psdk-item-signature-1"].waitForExistence(timeout: 30))
        let zoom = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "%")).firstMatch
        let before = zoom.label
        perform({ app.buttons["Lainnya"].tap() }, until: app.buttons["Perbesar"])
        app.buttons["Perbesar"].tap()
        let changed = expectation(for: NSPredicate(format: "label != %@", before), evaluatedWith: zoom)
        wait(for: [changed], timeout: 15)
    }
}
