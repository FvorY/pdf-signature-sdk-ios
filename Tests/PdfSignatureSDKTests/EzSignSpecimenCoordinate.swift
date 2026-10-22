//
//  SpecimenCoordinate.swift
//  ezSign
//
//  Created by Ferdy Cahya on 10/19/26.
//
//  Port PERSIS lib/utils/specimen_coordinates.dart — rumus posisi spesimen (tanda tangan/stamp/seal)
//  antara koordinat PDF (point) dan koordinat preview di layar. Jangan diubah tanpa mengubah Flutter/web.
//
//  Koordinat preview ("mobile"): titik tengah spesimen relatif ke TENGAH halaman preview,
//  x ke kanan, y ke bawah. Koordinat PDF: pojok kiri-bawah spesimen, y dari bawah halaman.
//  Koordinat web: sama dengan PDF tetapi y dari atas halaman.
//

import CoreGraphics

/// Kotak spesimen + ukuran dokumen tempat koordinat itu berlaku (key Flutter: docWidth, docHeight, x, y, width, height).
struct SpecimenRect: Equatable {
    var docWidth: Double
    var docHeight: Double
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

/// Hasil `pdfSpecimenToPreview` (key Flutter: mobileX, mobileY, mobileWidth, mobileHeight).
struct SpecimenMobileRect: Equatable {
    var mobileX: Double
    var mobileY: Double
    var mobileWidth: Double
    var mobileHeight: Double
}

/// Hasil `previewSpecimenToPage` (key Flutter: x, y, width, height).
struct SpecimenPageRect: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

class SpecimenCoordinate {
    /// Flutter: `pdfSpecimenToPreview(preview, item)` — koordinat PDF -> preview.
    static func pdfSpecimenToPreview(preview: CGSize, item: SpecimenRect) -> SpecimenMobileRect {
        let sourceWidth = item.docWidth
        let sourceHeight = item.docHeight
        let sx = Double(preview.width) / sourceWidth
        let sy = Double(preview.height) / sourceHeight

        return SpecimenMobileRect(
            mobileX: (item.x + item.width / 2 - sourceWidth / 2) * sx,
            mobileY: (sourceHeight / 2 - item.y - item.height / 2) * sy,
            mobileWidth: item.width * sx,
            mobileHeight: item.height * sy
        )
    }

    /// Flutter: `previewSpecimenToPage(page, item, {web = false})` — koordinat preview -> PDF (atau web).
    static func previewSpecimenToPage(page: CGSize, item: SpecimenRect, web: Bool = false) -> SpecimenPageRect {
        let sx = Double(page.width) / item.docWidth
        let sy = Double(page.height) / item.docHeight
        let width = item.width * sx
        let height = item.height * sy
        let centerX = (item.docWidth / 2 + item.x) * sx
        let centerY = (item.docHeight / 2 + item.y) * sy

        return SpecimenPageRect(
            x: centerX - width / 2,
            y: (web ? centerY : Double(page.height) - centerY) - height / 2,
            width: width,
            height: height
        )
    }

    /// Flutter: `resizePdfView(image, item)` — memakai ukuran halaman PDF dalam point.
    static func resizePdfView(page: PdfPageImage, item: SpecimenRect) -> SpecimenPageRect {
        return previewSpecimenToPage(page: page.pageSize, item: item)
    }

    /// Flutter: `resizeWebView(image, item)`.
    static func resizeWebView(page: PdfPageImage, item: SpecimenRect) -> SpecimenPageRect {
        return previewSpecimenToPage(page: page.pageSize, item: item, web: true)
    }

    /// Flutter: `resizeAppView(preview, item)`.
    static func resizeAppView(preview: CGSize, item: SpecimenRect) -> SpecimenMobileRect {
        return pdfSpecimenToPreview(preview: preview, item: item)
    }
}
