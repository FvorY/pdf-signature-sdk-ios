#if canImport(UIKit) && canImport(PDFKit)
import CryptoKit
import Foundation
import PDFKit
@testable import PdfSignatureSDK
import XCTest

@MainActor
final class ProvidedDocumentGeometryTests: XCTestCase {
    func testLocalRegressionPdfKeepsOriginalPageSizeAndBytes() async throws {
        guard let url = Bundle.module.url(forResource: "Parity/provided-local.pdf", withExtension: nil) else {
            throw XCTSkip("Private local regression fixture is not distributed with the SDK")
        }
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 16)
        let viewer = PdfSignatureView()
        defer { viewer.destroy() }
        try await viewer.loadDocument(.data(data))
        var ids: [String: String] = [:]
        for index in 0..<16 {
            let page = try XCTUnwrap(document.page(at: index))
            XCTAssertEqual(page.bounds(for: .cropBox).width, 198, accuracy: 0.0001)
            XCTAssertEqual(page.bounds(for: .cropBox).height, 255.12, accuracy: 0.0001)
            try viewer.placeSignature(PlaceOptions(x: 0, y: 0, page: index + 1,
                width: 25.00148397493763, height: 46.08857727510421))
            let item = try XCTUnwrap(viewer.getSignatures().last)
            ids[item.id] = "test-\(index)"
        }
        let exported = try viewer.exportInitSignDocument(specimenIds: ids)
        XCTAssertEqual(Data(base64Encoded: exported.base64Pdf), data)
        XCTAssertEqual(exported.signatureData.count, 16)
        for row in exported.signatureData {
            XCTAssertEqual(row.docWidth, 198, accuracy: 0.0001)
            XCTAssertEqual(row.docHeight, 255.12, accuracy: 0.0001)
            XCTAssertEqual(row.x, 0, accuracy: 0.0001)
            XCTAssertEqual(row.y, 209.03142272489578, accuracy: 0.0001)
            XCTAssertEqual(row.y + row.height, 255.12, accuracy: 0.0001)
        }
        print("REGRESSION PDF: \(exported.documentSha256); 16 native iOS top-left placements verified")
    }
}
#endif
