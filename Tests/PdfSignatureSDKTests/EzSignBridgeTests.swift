import CoreGraphics
import PDFKit
@testable import PdfSignatureSDK
import UIKit
import XCTest

struct PdfPageImage {
    let pageSize: CGSize
}

@MainActor
final class EzSignBridgeTests: XCTestCase {
    func testSdkCoordinatesRoundTripThroughOriginalEzSignFormula() async throws {
        let size = CGSize(width: 600, height: 800)
        let data = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).pdfData { $0.beginPage() }
        let viewer = PdfSignatureView()
        viewer.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        try await viewer.loadDocument(.data(data))
        defer { viewer.destroy() }
        try viewer.placeSignature(PlaceOptions(x: 100, y: 200, page: 1, width: 140, height: 60))
        try viewer.placeEStamp(PlaceOptions(x: 420, y: 650, page: 1))
        for item in viewer.getSignatures() {
            let preview = CGSize(width: 300, height: 400)
            let sx = preview.width / size.width
            let sy = preview.height / size.height
            let mobile = SpecimenRect(docWidth: preview.width, docHeight: preview.height,
                x: (item.x + item.width / 2 - size.width / 2) * sx,
                y: (item.y + item.height / 2 - size.height / 2) * sy,
                width: item.width * sx, height: item.height * sy)
            let backend = SpecimenCoordinate.previewSpecimenToPage(page: size, item: mobile)
            XCTAssertEqual(backend.x, item.x, accuracy: 0.0001)
            XCTAssertEqual(backend.y, item.yFromBottom(pageHeight: size.height), accuracy: 0.0001)
            XCTAssertEqual(backend.width, item.width, accuracy: 0.0001)
            XCTAssertEqual(backend.height, item.height, accuracy: 0.0001)
        }
    }

    func testSdkPageMetricsRoundingDoesNotChangeItemPointUnits() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Parity/pdfs/sample.pdf", withExtension: nil))
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        let exact = page.bounds(for: .cropBox).size
        let viewer = PdfSignatureView()
        viewer.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        try await viewer.loadDocument(.data(data))
        defer { viewer.destroy() }
        let reported = try XCTUnwrap(viewer.getPageSize(1))
        XCTAssertEqual(reported.width, floor(exact.width * 1.5) / 1.5, accuracy: 0.0001)
        XCTAssertEqual(reported.height, floor(exact.height * 1.5) / 1.5, accuracy: 0.0001)
        XCTAssertNotEqual(reported, exact)
        XCTAssertLessThan(exact.width - reported.width, 1)
        XCTAssertLessThan(exact.height - reported.height, 1)
    }
    func testAdapterMatchesVendorPdfSpaceForGeometryAndFractionalFixtures() async throws {
        for filename in ["geometry.pdf", "sample.pdf"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "Parity/pdfs/" + filename, withExtension: nil))
            let data = try Data(contentsOf: url)
            let document = try XCTUnwrap(PDFDocument(data: data))
            let viewer = PdfSignatureView()
            viewer.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
            try await viewer.loadDocument(.data(data))
            defer { viewer.destroy() }
            for index in 0..<document.pageCount {
                let page = try XCTUnwrap(document.page(at: index))
                if filename == "geometry.pdf", index == 4 {
                    let rendered = await viewer.renderPage(5, scale: 1)
                    let image = try XCTUnwrap(rendered)
                    XCTAssertEqual(image.cgImage?.width, 600)
                    XCTAssertEqual(image.cgImage?.height, 800)
                    let goldenURL = try XCTUnwrap(Bundle.module.url(forResource: "Parity/flutter-crop.png", withExtension: nil))
                    let goldenImage = try XCTUnwrap(UIImage(data: Data(contentsOf: goldenURL)))
                    XCTAssertEqual(try pixels(image), try pixels(goldenImage))
                    try image.pngData()?.write(to: URL(fileURLWithPath:
                        "/Users/developersign/Downloads/ezSign-sdk-evaluation/sdk-crop.png"))
                }
                let adapter = try XCTUnwrap(PdfSdkCoordinateAdapter(page: page))
                try viewer.placeSignature(PlaceOptions(x: 51.125, y: 83.375, page: index + 1, width: 143.625, height: 57.875))
                let item = try XCTUnwrap(viewer.getSignatures().last)
                let sdk = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
                let backend = try XCTUnwrap(adapter.backendRect(from: sdk))
                let original = PageGeometry.pageRect(sdk, bounds: page.bounds(for: .cropBox), rotation: page.rotation)
                let cropTopLeft = CGRect(x: backend.x, y: adapter.pageSize.height - backend.y - backend.height,
                    width: backend.width, height: backend.height)
                let mapped = PageGeometry.pageRect(cropTopLeft, bounds: page.bounds(for: .cropBox), rotation: page.rotation)
                XCTAssertEqual(mapped.minX, original.minX, accuracy: 0.000001)
                XCTAssertEqual(mapped.minY, original.minY, accuracy: 0.000001)
                XCTAssertEqual(mapped.width, original.width, accuracy: 0.000001)
                XCTAssertEqual(mapped.height, original.height, accuracy: 0.000001)
                let restored = try XCTUnwrap(adapter.sdkRect(from: backend))
                XCTAssertEqual(restored.minX, sdk.minX, accuracy: 0.000001)
                XCTAssertEqual(restored.minY, sdk.minY, accuracy: 0.000001)
            }
        }
    }

    func testActualSdkPlacementMatchesFlutterRuntimePayloadGolden() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Parity/flutter-runtime.json", withExtension: nil))
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let rows = try XCTUnwrap(report["cases"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 24)
        for row in rows {
            let fixture = try XCTUnwrap(row["fixture"] as? String)
            let file = try XCTUnwrap(Bundle.module.url(forResource: "Parity/pdfs/" + fixture, withExtension: nil))
            let data = try Data(contentsOf: file)
            let document = try XCTUnwrap(PDFDocument(data: data))
            let number = try XCTUnwrap(row["page"] as? Int)
            let page = try XCTUnwrap(document.page(at: number - 1))
            let adapter = try XCTUnwrap(PdfSdkCoordinateAdapter(page: page))
            let mobile = try XCTUnwrap(row["mobile"] as? [String: Double])
            let payload = try XCTUnwrap(row["payload"] as? [String: Double])
            let width = try XCTUnwrap(row["pageWidth"] as? Double)
            let height = try XCTUnwrap(row["pageHeight"] as? Double)
            let dw = try XCTUnwrap(mobile["docWidth"])
            let dh = try XCTUnwrap(mobile["docHeight"])
            let sx = width / dw
            let sy = height / dh
            let x = (dw / 2 + mobile["x"]! - mobile["width"]! / 2) * sx
            let y = (dh / 2 + mobile["y"]! - mobile["height"]! / 2) * sy
            let viewer = PdfSignatureView()
            viewer.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
            try await viewer.loadDocument(.data(data))
            defer { viewer.destroy() }
            try viewer.placeSignature(PlaceOptions(x: x, y: y, page: number,
                width: mobile["width"]! * sx, height: mobile["height"]! * sy))
            let item = try XCTUnwrap(viewer.getSignatures().last)
            let result = try XCTUnwrap(adapter.backendRect(from:
                CGRect(x: item.x, y: item.y, width: item.width, height: item.height)))
            XCTAssertEqual(result.x, try XCTUnwrap(payload["x"]), accuracy: 0.0001)
            XCTAssertEqual(result.y, try XCTUnwrap(payload["y"]), accuracy: 0.0001)
            XCTAssertEqual(result.width, try XCTUnwrap(payload["width"]), accuracy: 0.0001)
            XCTAssertEqual(result.height, try XCTUnwrap(payload["height"]), accuracy: 0.0001)
        }
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let image = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

}
