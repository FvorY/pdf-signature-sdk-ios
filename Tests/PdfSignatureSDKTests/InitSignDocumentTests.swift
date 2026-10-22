import Foundation
@testable import PdfSignatureSDK
import XCTest
#if canImport(UIKit) && canImport(PDFKit)
import PDFKit
import UIKit
#endif

final class InitSignDocumentTests: XCTestCase {
    private func item(x: Double = 12, y: Double = 20, width: Double = 80, height: Double = 40) -> SignatureItem {
        SignatureItem(id: "sdk-1", type: .signature, x: x, y: y, page: 1,
            label: "Direktur", width: width, height: height)
    }
    func testMatchesFlutterFormulaAcrossPreviewSizes() throws {
        for pw in [198.0, 390.0, 720.0] {
            let ph = pw * 255.12 / 198
            let i = item()
            let mx = (i.x + i.width / 2 - 198 / 2) * pw / 198
            let my = (i.y + i.height / 2 - 255.12 / 2) * ph / 255.12
            let mw = i.width * pw / 198
            let mh = i.height * ph / 255.12
            let row = try i.toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: "QR_test")
            XCTAssertEqual(row.x, (pw / 2 + mx) * 198 / pw - mw * 198 / pw / 2, accuracy: 1e-9)
            XCTAssertEqual(row.y, 255.12 - (ph / 2 + my) * 255.12 / ph - mh * 255.12 / ph / 2, accuracy: 1e-9)
            XCTAssertEqual(row.width, 80)
            XCTAssertEqual(row.height, 40)
        }
    }
    func testRejectsReportedIncidentAndInvalidRectangles() {
        for i in [item(x: 409.3586120605469, y: 58.96342468261719, width: 160, height: 48),
                  item(x: .nan), item(x: -1), item(width: 0), item(y: 240)] {
            XCTAssertThrowsError(try i.toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: "QR_test"))
        }
        XCTAssertThrowsError(try item().toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: ""))
    }
    func testAcceptsProportionalCorrectionWithinActualPage() throws {
        // Corrected payload from initsign-corrected-198x255.json:
        // x=160.0136650373956, y=218.2062487701647, w=37.986334962604396, h=36.9137512298353
        // on page 198 x 255.12. In SDK (top-left):
        // sdkY = pageHeight - backendY - height = 255.12 - 218.2062487701647 - 36.9137512298353 = 0.0
        let stamp = SignatureItem(id: "sdk-corrected", type: .signature,
            x: 160.0136650373956, y: 0.0, page: 1,
            label: "Signature", width: 37.986334962604396, height: 36.9137512298353)
        let row = try stamp.toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: "QR_8668c804-b5f9-4e1a-962d-a6afedad9ec1")
        XCTAssertEqual(row.x, 160.0136650373956, accuracy: 1e-6)
        XCTAssertEqual(row.y, 218.2062487701647, accuracy: 1e-6)
        XCTAssertEqual(row.width, 37.986334962604396, accuracy: 1e-6)
        XCTAssertEqual(row.height, 36.9137512298353, accuracy: 1e-6)
        XCTAssertEqual(row.docWidth, 198)
        XCTAssertEqual(row.docHeight, 255.12)
        XCTAssertEqual(row.specimenId, "QR_8668c804-b5f9-4e1a-962d-a6afedad9ec1")
    }
    func testConvertsSdkEstampToFlutterEmeteraiType() throws {
        let stamp = SignatureItem(id: "sdk-2", type: .estamp, x: 12, y: 20, page: 1,
            label: "E-Materai", width: 80, height: 80)
        let row = try stamp.toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: "materai-id")
        XCTAssertEqual(row.specimenType, "emeterai")
    }
    func testEncodingIncludesApiNullAndOmitsLocalHash() throws {
        let row = try item().toInitSignData(pageWidth: 198, pageHeight: 255.12, specimenId: "QR_test")
        let export = InitSignDocument(base64Pdf: "same-source-base64", documentSha256: "local-hash", signatureData: [row])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(export)) as? [String: Any])
        XCTAssertNil(json["documentSha256"])
        let rows = try XCTUnwrap(json["signatureData"] as? [[String: Any]])
        XCTAssertTrue(rows[0]["jenisDocument"] is NSNull)
        XCTAssertEqual(rows[0]["specimenId"] as? String, "QR_test")
    }
    #if canImport(UIKit) && canImport(PDFKit)
    @MainActor
    func testViewerExportsOriginalBytesAndExactFractionalPageSize() async throws {
        let size = CGSize(width: 198, height: 255.12)
        let data = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).pdfData { $0.beginPage() }
        let viewer = PdfSignatureView()
        defer { viewer.destroy() }
        try await viewer.loadDocument(.data(data))
        try viewer.placeSignature(PlaceOptions(x: 12, y: 20, page: 1, width: 80, height: 40))
        let id = try XCTUnwrap(viewer.getSignatures().first?.id)
        let export = try viewer.exportInitSignDocument(specimenIds: [id: "QR_test"])
        XCTAssertEqual(Data(base64Encoded: export.base64Pdf), data)
        XCTAssertEqual(export.documentSha256.count, 64)
        XCTAssertEqual(export.signatureData[0].docHeight, 255.12, accuracy: 0.00001)
        XCTAssertEqual(export.signatureData[0].y, 195.12, accuracy: 0.00001)
        viewer.destroy()
        XCTAssertThrowsError(try viewer.exportInitSignDocument(specimenIds: [id: "QR_test"]))
    }
    @MainActor
    func testFailedReplacementCannotExportPreviousDocument() async throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 198, height: 255.12))
            .pdfData { $0.beginPage() }
        let viewer = PdfSignatureView()
        defer { viewer.destroy() }
        try await viewer.loadDocument(.data(data))
        try viewer.placeSignature(PlaceOptions(x: 12, y: 20, page: 1, width: 80, height: 40))
        let id = try XCTUnwrap(viewer.getSignatures().first?.id)
        do {
            try await viewer.loadDocument(.data(Data("invalid PDF".utf8)))
            XCTFail("Invalid PDF must fail")
        } catch { }
        XCTAssertThrowsError(try viewer.exportInitSignDocument(specimenIds: [id: "QR_test"]))
    }
    #endif
}
