import Foundation

/// Fields to merge into /signing/initsign. Hash is local validation metadata, not a request field.
public struct InitSignDocument: Encodable, Sendable {
    public let base64Pdf: String
    public let documentSha256: String
    public let signatureData: [InitSignSignature]

    enum CodingKeys: String, CodingKey { case base64Pdf, signatureData }
}

public struct InitSignSignature: Encodable, Sendable {
    public let viewOrientation: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let docWidth: Double
    public let docHeight: Double
    public let page: Int
    public let scale: Int
    public let specimenId: String
    public let specimenType: String
    public let jenisDocument: String? = nil

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(viewOrientation, forKey: .viewOrientation)
        try values.encode(x, forKey: .x)
        try values.encode(y, forKey: .y)
        try values.encode(width, forKey: .width)
        try values.encode(height, forKey: .height)
        try values.encode(docWidth, forKey: .docWidth)
        try values.encode(docHeight, forKey: .docHeight)
        try values.encode(page, forKey: .page)
        try values.encode(scale, forKey: .scale)
        try values.encode(specimenId, forKey: .specimenId)
        try values.encode(specimenType, forKey: .specimenType)
        try values.encodeNil(forKey: .jenisDocument)
    }
    private enum CodingKeys: String, CodingKey {
        case viewOrientation, x, y, width, height, docWidth, docHeight, page, scale
        case specimenId, specimenType, jenisDocument
    }
}

public enum InitSignExportError: Error, Equatable {
    case documentNotReady
    case noSignatures
    case invalidPage(Int)
    case invalidRectangle(String)
    case missingSpecimenId(String)
}

extension SignatureItem {
    /// Same PDF-point output as Flutter resizePdfView; SDK positions already use PDF points.
    public func toInitSignData(pageWidth: Double, pageHeight: Double, specimenId: String) throws -> InitSignSignature {
        guard !specimenId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InitSignExportError.missingSpecimenId(id)
        }
        guard page >= 1 else { throw InitSignExportError.invalidPage(page) }
        guard [pageWidth, pageHeight, x, y, width, height].allSatisfy({ $0.isFinite }),
              pageWidth > 0, pageHeight > 0, width > 0, height > 0,
              x >= 0, y >= 0, x + width <= pageWidth, y + height <= pageHeight else {
            throw InitSignExportError.invalidRectangle(id)
        }
        return InitSignSignature(viewOrientation: 0, x: x, y: pageHeight - y - height,
            width: width, height: height, docWidth: pageWidth, docHeight: pageHeight,
            page: page, scale: 1, specimenId: specimenId, specimenType: type == .estamp ? "emeterai" : "signature")
    }
}

#if canImport(UIKit) && canImport(PDFKit)
import CryptoKit
import PDFKit

extension PdfSignatureView {
    /// Uses the original bytes and exact displayed CropBox dimensions of the loaded PDF.
    /// SDK item IDs must be explicitly bound to backend specimen IDs.
    public func exportInitSignDocument(specimenIds: [String: String]) throws -> InitSignDocument {
        guard isLoaded, !isLoading, !isDestroyed, let data = signingDocumentData, let document else {
            throw InitSignExportError.documentNotReady
        }
        guard !items.isEmpty else { throw InitSignExportError.noSignatures }
        let rows = try items.map { item in
            guard item.page >= 1, let page = document.page(at: item.page - 1) else {
                throw InitSignExportError.invalidPage(item.page)
            }
            let size = PageGeometry.displaySize(bounds: page.bounds(for: .cropBox), rotation: page.rotation)
            return try item.toInitSignData(pageWidth: size.width, pageHeight: size.height,
                specimenId: specimenIds[item.id] ?? "")
        }
        return InitSignDocument(base64Pdf: data.base64EncodedString(),
            documentSha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), signatureData: rows)
    }
}
#endif
