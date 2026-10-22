import PDFKit
@testable import PdfSignatureSDK
import XCTest

/// Runs the web SDK parity scenarios (shared with the Android SDK) and checks viewer behaviour.
@MainActor
final class ViewerTests: XCTestCase {
    private func fixture(_ path: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Parity/\(path)", withExtension: nil), path)
        return try Data(contentsOf: url)
    }

    private func json(_ path: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: fixture(path)) as? [String: Any])
    }

    private func loadedViewer(_ pdf: String) async throws -> PdfSignatureView {
        let viewer = PdfSignatureView()
        viewer.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        try await viewer.loadDocument(.data(fixture("pdfs/\(pdf)")))
        XCTAssertTrue(viewer.isLoaded)
        return viewer
    }

    private func placeOptions(_ opts: [String: Any]) -> PlaceOptions {
        PlaceOptions(
            x: opts["x"] as? Double,
            y: opts["y"] as? Double,
            page: opts["page"] as? Int,
            label: opts["label"] as? String,
            width: opts["width"] as? Double,
            height: opts["height"] as? Double,
            disableDrag: opts["disableDrag"] as? Bool ?? false,
            disableDragging: opts["disableDragging"] as? Bool ?? false,
            disableResize: opts["disableResize"] as? Bool ?? false,
            locked: opts["locked"] as? Bool ?? false
        )
    }

    func testDefaultPositionPlacesUiAddedItemsWithoutDragging() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        let size = try XCTUnwrap(viewer.getPageSize(1))
        viewer.updateConfig { $0.defaultPosition = PlacementPosition(x: 10, y: 20) }
        viewer.openSignatureModal()
        viewer.openEStampModal()
        let items = viewer.getSignatures()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].x, 10, accuracy: 0.0001)
        XCTAssertEqual(items[0].y, 20, accuracy: 0.0001)
        XCTAssertEqual(items[1].x, 10, accuracy: 0.0001)
        viewer.updateConfig { $0.defaultPosition = PlacementPosition(x: 9999, y: 9999) }
        viewer.openSignatureModal()
        let clamped = try XCTUnwrap(viewer.getSignatures().last)
        XCTAssertEqual(clamped.x, Double(size.width) - clamped.width, accuracy: 0.0001)
        XCTAssertEqual(clamped.y, Double(size.height) - clamped.height, accuracy: 0.0001)
        viewer.updateConfig { $0.defaultPosition = nil }
        viewer.openSignatureModal()
        let centered = try XCTUnwrap(viewer.getSignatures().last)
        XCTAssertEqual(centered.x, Double(size.width) / 2 - centered.width / 2, accuracy: 0.0001)
    }

    func testWebParityScenarios() async throws {
        let config = try json("scenarios.json")
        let tolerance = try XCTUnwrap(config["tolerance"] as? Double)
        let scenarios = try XCTUnwrap(config["scenarios"] as? [[String: Any]])
        for pdf in try XCTUnwrap(config["pdfs"] as? [String]) {
            let expected = try json("expected/\(pdf.replacingOccurrences(of: ".pdf", with: ".json"))")
            let viewer = try await loadedViewer(pdf)
            try assertPageSizes(viewer, expected: expected, pdf: pdf, tolerance: tolerance)
            let results = try XCTUnwrap(expected["scenarios"] as? [String: [[String: Any]]])
            for scenario in scenarios {
                let name = try XCTUnwrap(scenario["name"] as? String)
                if let only = scenario["only"] as? [String], !only.contains(pdf) { continue }
                try run(scenario, on: viewer)
                let want = try XCTUnwrap(results[name], name)
                try assertItems(viewer.getSignatures(), equal: want, context: "\(pdf) \(name)", tolerance: tolerance)
            }
            viewer.destroy()
        }
    }

    private func assertPageSizes(_ viewer: PdfSignatureView, expected: [String: Any], pdf: String, tolerance: Double) throws {
        let sizes = try XCTUnwrap(expected["pageSizes"] as? [[Double]])
        XCTAssertEqual(viewer.totalPages, sizes.count, pdf)
        for (index, size) in sizes.enumerated() {
            let actual = try XCTUnwrap(viewer.getPageSize(index + 1))
            XCTAssertEqual(Double(actual.width), size[0], accuracy: tolerance, "\(pdf) page \(index + 1) width")
            XCTAssertEqual(Double(actual.height), size[1], accuracy: tolerance, "\(pdf) page \(index + 1) height")
        }
    }

    private func run(_ scenario: [String: Any], on viewer: PdfSignatureView) throws {
        viewer.clearSignatures()
        viewer.goToPage(1)
        for action in try XCTUnwrap(scenario["actions"] as? [[String: Any]]) {
            let opts = action["opts"] as? [String: Any] ?? [:]
            switch action["op"] as? String {
            case "placeSignature": try viewer.placeSignature(placeOptions(opts))
            case "placeEStamp": try viewer.placeEStamp(placeOptions(opts))
            case "goToPage": viewer.goToPage(try XCTUnwrap(action["page"] as? Int))
            default: XCTFail("Unknown action \(action)")
            }
        }
    }

    private func assertItems(_ got: [SignatureItem], equal want: [[String: Any]], context: String, tolerance: Double) throws {
        XCTAssertEqual(got.count, want.count, context)
        for (item, expected) in zip(got, want) {
            XCTAssertEqual(item.type.rawValue, expected["type"] as? String, context)
            XCTAssertEqual(item.page, expected["page"] as? Int, context)
            XCTAssertEqual(item.label, expected["label"] as? String, context)
            for (key, value) in [("x", item.x), ("y", item.y), ("width", item.width), ("height", item.height)] {
                let target = try XCTUnwrap(expected[key] as? Double, "\(context) \(key)")
                XCTAssertEqual(value, target, accuracy: tolerance, "\(context) \(key)")
            }
            let flags = [item.disableDrag, item.disableDragging, item.disableResize, item.locked]
            let wanted = ["disableDrag", "disableDragging", "disableResize", "locked"].map { expected[$0] as? Bool }
            XCTAssertEqual(flags.map(Optional.some), wanted, context)
        }
    }

    /// Our display-to-page mapping must agree with PDFKit's own transform for every /Rotate.
    func testPageRectMatchesPdfKitForEveryRotation() async throws {
        let viewer = try await loadedViewer("geometry.pdf")
        let document = try XCTUnwrap(viewer.document)
        for index in 0..<document.pageCount {
            let page = try XCTUnwrap(document.page(at: index))
            let bounds = page.bounds(for: .cropBox)
            let display = PageGeometry.displaySize(bounds: bounds, rotation: page.rotation)
            let item = CGRect(x: 30, y: 50, width: 120, height: 40)
            let pageRect = PageGeometry.pageRect(item, bounds: bounds, rotation: page.rotation)
            // transform(for:) maps page space to the rotated box with a bottom-left origin.
            let shown = pageRect.applying(page.transform(for: .cropBox))
            let expected = CGRect(x: item.minX, y: display.height - item.maxY, width: item.width, height: item.height)
            let context = "page \(index + 1), /Rotate \(page.rotation)"
            XCTAssertEqual(shown.minX, expected.minX, accuracy: 0.01, context)
            XCTAssertEqual(shown.minY, expected.minY, accuracy: 0.01, context)
            XCTAssertEqual(shown.width, expected.width, accuracy: 0.01, context)
            XCTAssertEqual(shown.height, expected.height, accuracy: 0.01, context)
        }
        viewer.destroy()
    }

    func testRenderPageFollowsRotatedPageSize() async throws {
        let viewer = try await loadedViewer("geometry.pdf")
        for page in 1...viewer.totalPages {
            let size = try XCTUnwrap(viewer.getPageSize(page))
            let rendered = await viewer.renderPage(page, scale: 1)
            let image = try XCTUnwrap(rendered)
            XCTAssertEqual(image.size.width, size.width.rounded(), accuracy: 1, "page \(page)")
            XCTAssertEqual(image.size.height, size.height.rounded(), accuracy: 1, "page \(page)")
        }
        viewer.destroy()
    }

    func testMoveAndResizeStayOnThePage() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        let id = try viewer.placeSignature(PlaceOptions(x: 10, y: 10))
        let page = try XCTUnwrap(viewer.getPageSize(1))
        viewer.moveItem(id: id, x: 10_000, y: -50)
        var item = try XCTUnwrap(viewer.getSignatures().first)
        XCTAssertEqual(item.x, Double(page.width) - item.width, accuracy: 0.001)
        XCTAssertEqual(item.y, 0)
        viewer.resizeItem(id: id, width: 1, height: 10_000)
        item = try XCTUnwrap(viewer.getSignatures().first)
        XCTAssertEqual(item.width, Double(PageGeometry.minSize))
        XCTAssertEqual(item.height, Double(page.height) - item.y, accuracy: 0.001)
        viewer.destroy()
    }

    func testLockRulesMatchTheWebSdk() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        try viewer.placeSignature(PlaceOptions(x: 0, y: 0, disableDrag: true))
        try viewer.placeSignature(PlaceOptions(x: 0, y: 0, disableResize: true))
        try viewer.placeSignature(PlaceOptions(x: 0, y: 0, locked: true))
        let items = viewer.getSignatures()
        XCTAssertEqual(items.map(viewer.canDrag), [false, true, false])
        XCTAssertEqual(items.map(viewer.canResize), [true, false, false])
        viewer.updateConfig { $0.disableDragging = true }
        XCTAssertFalse(items.contains(where: viewer.canDrag))
        XCTAssertFalse(items.contains(where: viewer.canResize))
        viewer.destroy()
    }

    func testIdsUseTheWebSdkFormat() {
        let id = PdfSignatureView.makeID(.estamp)
        XCTAssertNotNil(id.range(of: #"^estamp-\d{13}-[0-9a-z]{5}$"#, options: .regularExpression), id)
    }

    func testOnceListenerFiresOnlyOnce() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        var calls = 0
        viewer.once(.signaturePlaced) { _ in calls += 1 }
        try viewer.placeSignature()
        try viewer.placeSignature()
        XCTAssertEqual(calls, 1)
        viewer.destroy()
    }

    /// Waits on the main actor until `condition` holds (the viewer works through async steps).
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 where !condition() { await Task.yield() }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    /// Like Android, `loadDocument` waits for the password and returns once the document is open.
    func testPasswordFlow() async throws {
        let viewer = PdfSignatureView(config: PsdkConfig(ui: PsdkUiConfig(passwordDialog: false)))
        var requests: [PasswordRequest] = []
        var loaded = 0
        viewer.on(.passwordRequested) { event in
            if case let .passwordRequested(request) = event { requests.append(request) }
        }
        viewer.on(.documentLoaded) { _ in loaded += 1 }
        let data = try fixture("pdfs/password-aes256.pdf")
        let load = Task { try await viewer.loadDocument(.data(data)) }
        await waitUntil { requests.count == 1 }
        XCTAssertFalse(requests[0].isIncorrect)
        XCTAssertFalse(viewer.isLoaded)
        XCTAssertTrue(viewer.isPasswordProtected)
        requests[0].updatePassword("wrong")
        await waitUntil { requests.count == 2 }
        XCTAssertTrue(requests[1].isIncorrect)
        requests[0].updatePassword("test123") // an old prompt cannot answer the new one
        XCTAssertFalse(viewer.isLoaded)
        requests[1].updatePassword("test123")
        try await load.value
        XCTAssertEqual(loaded, 1)
        XCTAssertTrue(viewer.isLoaded)
        XCTAssertEqual(viewer.totalPages, 5)
        XCTAssertTrue(viewer.isPasswordProtected, "the 🔒 badge stays while the encrypted document is open")
        viewer.destroy()
    }

    func testCancelledPasswordThrowsAndShowsTheEmptyState() async throws {
        let viewer = PdfSignatureView(config: PsdkConfig(ui: PsdkUiConfig(passwordDialog: false)))
        var request: PasswordRequest?
        viewer.on(.passwordRequested) { event in
            if case let .passwordRequested(value) = event { request = value }
        }
        let data = try fixture("pdfs/password-aes256.pdf")
        let load = Task { try await viewer.loadDocument(.data(data)) }
        await waitUntil { request != nil }
        request?.cancel()
        do {
            try await load.value
            XCTFail("Cancelling must throw")
        } catch {
            XCTAssertEqual(error as? PsdkError, .passwordCancelled)
        }
        XCTAssertFalse(viewer.isLoaded)
        XCTAssertFalse(viewer.isPasswordProtected)
        viewer.destroy()
    }

    func testEstampKeepsAspectRatioWhenAsked() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        let stamp = try viewer.placeEStamp(PlaceOptions(x: 10, y: 10, width: 80, height: 80))
        viewer.resizeItem(id: stamp, width: 120, height: 60)
        XCTAssertEqual(viewer.getSignatures()[0].height, 60, "free resize by default")
        viewer.updateConfig { $0.estampKeepAspectRatio = true }
        viewer.resizeItem(id: stamp, width: 240, height: 500)
        let item = viewer.getSignatures()[0]
        XCTAssertEqual(item.width, 240, accuracy: 0.001)
        XCTAssertEqual(item.height, 120, accuracy: 0.001)
        viewer.destroy()
    }

    func testChromeRulesMatchAndroid() {
        let labels = PsdkLabels()
        XCTAssertTrue(ChromeRules.isTablet(.auto, width: 600))
        XCTAssertFalse(ChromeRules.isTablet(.auto, width: 599))
        XCTAssertFalse(ChromeRules.isTablet(.phone, width: 1000))
        XCTAssertEqual(ChromeRules.itemCount(0, labels: labels), nil)
        XCTAssertEqual(ChromeRules.itemCount(1, labels: labels), "1 signature")
        XCTAssertEqual(ChromeRules.itemCount(3, labels: labels), "3 signatures")
        XCTAssertEqual(ChromeRules.zoomPercent(1.256), "126%")
        XCTAssertEqual(ChromeRules.parsePage(" 12 "), 12)
        XCTAssertNil(ChromeRules.parsePage("x"))
        let groups = ChromeRules.group(
            [PickerOption(id: "a", group: "B"), PickerOption(id: "b"), PickerOption(id: "c", group: "B")],
            defaultGroup: "Umum"
        )
        XCTAssertEqual(groups.map(\.0), ["B", "Umum"])
        XCTAssertEqual(groups[0].1.map(\.id), ["a", "c"])
        let off = TopBarConfig(upload: false, signature: false, eStamp: false, pagination: false, paginationInput: false,
                               zoom: false, themeToggle: false, brandText: "")
        XCTAssertFalse(ChromeRules.topBarHasContent(off))
        XCTAssertTrue(ChromeRules.topBarHasContent(TopBarConfig()))
    }

    func testThemeToggleAndColors() async throws {
        let viewer = try await loadedViewer("sample.pdf")
        XCTAssertFalse(viewer.isDark)
        viewer.toggleTheme()
        XCTAssertEqual(viewer.config.theme, .dark)
        XCTAssertEqual(viewer.colors.background, PsdkColors.dark.background)
        viewer.destroy()
    }

    func testRemoteSourcesRequireHttps() async {
        let viewer = PdfSignatureView()
        do {
            try await viewer.loadDocument(.remote(URL(string: "http://example.com/a.pdf")!))
            XCTFail("HTTP must be rejected by default")
        } catch {
            XCTAssertEqual(error as? PsdkError, .invalidURL)
        }
        viewer.destroy()
    }
}
