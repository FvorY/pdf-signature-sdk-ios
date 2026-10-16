#if canImport(UIKit) && canImport(PDFKit)

import PDFKit
import UIKit

extension PdfSignatureView {
    // MARK: - Overlay geometry and locks

    /// The item's rectangle in this view's coordinates, following PDFView's scroll, zoom and /Rotate.
    func viewRect(for item: SignatureItem) -> CGRect? {
        guard let page = document?.page(at: item.page - 1) else { return nil }
        let box = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        let rect = PageGeometry.pageRect(box, bounds: page.bounds(for: .cropBox), rotation: page.rotation)
        return convert(pdfView.convert(rect, from: page), from: pdfView)
    }

    /// One-based numbers of the pages PDFView shows right now.
    func visiblePageNumbers() -> [Int] {
        guard let document else { return [] }
        return pdfView.visiblePages.compactMap { page in
            let index = document.index(for: page)
            return index == NSNotFound ? nil : index + 1
        }
    }

    /// Lock rules copied from the web SDK.
    func canDrag(_ item: SignatureItem) -> Bool {
        !(config.disableDragging || config.disableDrag || item.disableDragging || item.disableDrag || item.locked)
    }

    func canResize(_ item: SignatureItem) -> Bool {
        !(config.disableResize || item.disableResize || config.disableDragging || item.disableDragging || item.locked)
    }

    func drawItem(_ item: SignatureItem, in rect: CGRect, showDelete: Bool, showResize: Bool) {
        let color = item.type == .signature ? UIColor.systemBlue : UIColor.systemRed
        if let image = itemImages[item.id] {
            image.draw(in: rect)
        } else {
            color.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 4).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: color
            ]
            item.label.draw(at: CGPoint(x: rect.minX + 6, y: rect.midY - 7), withAttributes: attributes)
        }
        color.withAlphaComponent(0.8).setStroke()
        let border = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        border.lineWidth = 1
        border.stroke()
        if showDelete {
            let button = ItemOverlayView.deleteRect(for: rect).insetBy(dx: 5, dy: 5)
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: button).fill()
            UIColor.white.setStroke()
            let cross = UIBezierPath()
            let inset = button.insetBy(dx: 5.5, dy: 5.5)
            cross.move(to: CGPoint(x: inset.minX, y: inset.minY))
            cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
            cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
            cross.lineWidth = 2
            cross.stroke()
        }
        if showResize {
            let handle = ItemOverlayView.resizeRect(for: rect).insetBy(dx: 8, dy: 8)
            color.setFill()
            UIBezierPath(roundedRect: handle, cornerRadius: 2).fill()
        }
    }

    // MARK: - Page images

    /// Renders one PDF page without the interactive overlay, `scale` pixels per PDF point.
    public func renderPage(_ page: Int? = nil, scale: CGFloat? = nil) async -> UIImage? {
        render(page ?? currentPage, scale: scale, withItems: false)
    }

    /// Renders one PDF page and draws that page's items on top.
    public func renderPageWithOverlay(_ page: Int? = nil, scale: CGFloat? = nil) async -> UIImage? {
        render(page ?? currentPage, scale: scale, withItems: true)
    }

    private func render(_ number: Int, scale: CGFloat?, withItems: Bool) -> UIImage? {
        guard let pdfPage = document?.page(at: number - 1), let display = pageSize(number) else { return nil }
        let factor = max(0.25, scale ?? currentScale)
        let size = CGSize(width: (display.width * factor).rounded(), height: (display.height * factor).rounded())
        guard size.width > 0, size.height > 0 else { return nil }
        // thumbnail(of:for:) applies /Rotate, so the image matches pageSize.
        let pageImage = pdfPage.thumbnail(of: size, for: .cropBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pageItems = withItems ? items.filter { $0.page == number } : []
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            pageImage.draw(in: CGRect(origin: .zero, size: size))
            for item in pageItems {
                let rect = CGRect(x: item.x * factor, y: item.y * factor, width: item.width * factor, height: item.height * factor)
                drawItem(item, in: rect, showDelete: false, showResize: false)
            }
        }
    }
}

#endif
