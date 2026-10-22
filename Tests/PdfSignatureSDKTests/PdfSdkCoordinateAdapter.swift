//
//  PdfSdkCoordinateAdapter.swift
//  ezSign
//
//  Created by Ferdy Cahya on 10/21/26.
//

import CoreGraphics
import PDFKit

struct PdfSdkCoordinateAdapter {
    let pageSize: CGSize
    init?(page: PDFPage) {
        let crop = page.bounds(for: .cropBox)
        let rotation = ((page.rotation % 360) + 360) % 360
        guard Self.isValid(crop), [0, 90, 180, 270].contains(rotation) else { return nil }
        pageSize = rotation == 90 || rotation == 270 ? CGSize(width: crop.height, height: crop.width) : crop.size
    }

    func backendRect(from sdkRect: CGRect) -> SpecimenPageRect? {
        guard Self.isValid(sdkRect) else { return nil }
        return SpecimenPageRect(
            x: sdkRect.minX,
            y: pageSize.height - sdkRect.maxY,
            width: sdkRect.width,
            height: sdkRect.height
        )
    }

    func sdkRect(from backendRect: SpecimenPageRect) -> CGRect? {
        let rect = CGRect(x: backendRect.x, y: backendRect.y, width: backendRect.width, height: backendRect.height)
        guard Self.isValid(rect) else { return nil }
        return CGRect(
            x: rect.minX,
            y: pageSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.size.width > 0 && rect.size.height > 0
    }
}
