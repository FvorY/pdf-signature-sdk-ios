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
        XCTAssertNotNil(PdfSignatureSDK.resourceBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }

    func testRemoteTransportIsSecureByDefault() {
        let config = PsdkConfig()
        XCTAssertFalse(config.allowInsecureHttp)
        XCTAssertEqual(config.theme, .light)
        XCTAssertNil(config.scale)
        XCTAssertFalse(config.disabled)
    }

    func testWebParityConfigurationSurface() {
        let option = PickerOption(id: "director", label: "Director", group: "Internal")
        let config = PsdkConfig(
            disabled: true,
            disableDragging: true,
            signatureOptions: [option],
            estampOptions: [PickerOption(id: "stamp")],
            groupByCategory: true,
            labels: .indonesian,
            ui: PsdkUiConfig(topbar: TopBarConfig(upload: false, brandText: ""), sidebar: SidebarConfig(thumbnails: false))
        )

        XCTAssertEqual(config.labels.signatureBtn, "Tambah Tanda Tangan")
        XCTAssertEqual(config.signatureOptions.first?.group, "Internal")
        XCTAssertTrue(config.groupByCategory)
        XCTAssertTrue(config.disabled)
        XCTAssertTrue(config.disableDragging)
        XCTAssertFalse(config.ui.sidebar.thumbnails)
        XCTAssertFalse(config.ui.topbar.upload)
        XCTAssertNil(ChromeRules.brandText(config.ui.topbar, labels: config.labels))
    }

    func testSignatureItemCoordinatesRemainTopLeftPdfPoints() throws {
        let item = SignatureItem(
            id: "sig-1",
            type: .signature,
            x: 12,
            y: 34,
            page: 2,
            label: "Director",
            width: 160,
            height: 48
        )
        XCTAssertEqual(item.yFromBottom(pageHeight: 800), 718)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SignatureItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
