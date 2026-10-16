import PdfSignatureSDK
import UIKit
import XCTest

/// The code samples of DOCUMENTATION.en.md / .id.md. If these stop compiling, update the guide too.
@MainActor
final class DocSnippetTests: XCTestCase {
    // One function keeps the samples in the guide's order
    // swiftlint:disable:next function_body_length
    func testGuideSamplesCompile() async throws {
        let pdfURL = URL(fileURLWithPath: "/tmp/example.pdf")

        // §2, §3
        let viewer = PdfSignatureView(config: PsdkConfig(file: .file(pdfURL)))
        let sources: [PdfSource] = [
            .file(pdfURL), .data(Data()), .bundle(name: "example.pdf"),
            .remote(URL(string: "https://example.com/a.pdf")!, headers: ["Authorization": "Bearer x"])
        ]
        XCTAssertEqual(sources.count, 4)

        // §4
        _ = PlaceOptions(
            x: 72, y: 680, page: 1, label: "Director",
            image: .url(URL(string: "https://example.com/signature.png")!), width: 140
        )

        // §7
        let subscription = viewer.on(.signaturePlaced) { event in
            if case let .signaturePlaced(item) = event { _ = item }
        }
        viewer.once(.documentLoaded) { _ in }
        viewer.off(subscription)

        // §9
        var ui = PsdkUiConfig()
        ui.passwordDialog = false
        viewer.on(.passwordRequested) { event in
            guard case let .passwordRequested(request) = event else { return }
            _ = request.isIncorrect
            request.updatePassword("test123") // the text the user typed
            // request.cancel()               // or the user gave up
        }

        // §10
        _ = PsdkConfig(
            ui: PsdkUiConfig(
                topbar: TopBarConfig(upload: false, themeToggle: false, brandText: "My App"),
                sidebar: SidebarConfig(thumbnails: false),
                statusbar: false
            )
        )
        _ = PsdkConfig(
            signatureOptions: [
                PickerOption(id: "director", label: "Director", image: .image(UIImage()), group: "Internal"),
                PickerOption(id: "client", label: "Client", group: "External")
            ],
            estampOptions: [PickerOption(id: "stamp-10000", label: "E-Materai 10,000")],
            groupByCategory: true
        )

        // §11
        var colors = PsdkColors.light
        colors.accent = UIColor(red: 0, green: 0.34, blue: 0.72, alpha: 1)
        var labels = PsdkLabels.indonesian
        labels.uploadBtn = "Pilih PDF"
        _ = PsdkConfig(
            theme: .system,
            lightColors: colors,
            darkColors: .dark,
            typography: PsdkTypography(fontName: "Inter-Regular", baseFontSize: 16),
            labels: labels
        )
        _ = [PsdkColors.webLight, PsdkColors.webDark]

        // §12
        _ = PsdkConfig(onUpload: { picked in
            guard case let .file(url) = picked,
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 20_000_000 else { return .cancel }
            return .proceed // or open another document instead: .replace(.bundle(name: "other.pdf"))
        })

        // §13, §14
        viewer.showSkeleton(true, options: SkeletonOptions(backgroundOpacity: 0.3, blurRadius: 8))
        viewer.showSkeleton(false)
        let page: UIImage? = await viewer.renderPage(1, scale: 2)
        let withItems: UIImage? = await viewer.renderPageWithOverlay(1, scale: 2)
        XCTAssertNil(page)
        XCTAssertNil(withItems)

        // §18
        viewer.updateConfig { $0.disabled = true }
        viewer.destroy()
    }
}
