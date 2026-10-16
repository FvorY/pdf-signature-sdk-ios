import CoreGraphics

/// Converts between item boxes as the SDK reports them (PDF points, top-left origin of the page as
/// displayed, after /Rotate) and PDFKit page space (bottom-left origin of the unrotated CropBox).
enum PageGeometry {
    /// Smallest item width or height while resizing. The web SDK uses 30 canvas px (20 pt at 1.5 zoom).
    static let minSize: CGFloat = 20

    /// /Rotate normalized to 0, 90, 180 or 270.
    static func normalized(_ rotation: Int) -> Int {
        ((rotation % 360) + 360) % 360
    }

    /// The web SDK draws pages at zoom 1.5 and reports the canvas size divided by 1.5, so sizes are
    /// rounded down to 1/1.5 pt (A4 595.28 × 841.89 becomes 594.67 × 841.33).
    static func webSize(_ size: CGSize) -> CGSize {
        CGSize(width: (size.width * 1.5).rounded(.down) / 1.5, height: (size.height * 1.5).rounded(.down) / 1.5)
    }

    /// Size of the page as displayed: the CropBox, with width and height swapped for 90 and 270.
    static func displaySize(bounds: CGRect, rotation: Int) -> CGSize {
        normalized(rotation) % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
    }

    /// The rectangle in page space covered by `box` on the displayed page. /Rotate turns the page clockwise.
    static func pageRect(_ box: CGRect, bounds: CGRect, rotation: Int) -> CGRect {
        switch normalized(rotation) {
        case 90:
            return CGRect(x: bounds.minX + box.minY, y: bounds.minY + box.minX, width: box.height, height: box.width)
        case 180:
            return CGRect(x: bounds.maxX - box.maxX, y: bounds.minY + box.minY, width: box.width, height: box.height)
        case 270:
            return CGRect(x: bounds.maxX - box.maxY, y: bounds.maxY - box.maxX, width: box.height, height: box.width)
        default:
            return CGRect(x: bounds.minX + box.minX, y: bounds.maxY - box.maxY, width: box.width, height: box.height)
        }
    }

    /// Keeps a moved box inside the page.
    static func clampMove(_ box: CGRect, page: CGSize) -> CGRect {
        let x = min(max(box.minX, 0), max(page.width - box.width, 0))
        let y = min(max(box.minY, 0), max(page.height - box.height, 0))
        return CGRect(x: x, y: y, width: box.width, height: box.height)
    }

    /// Resizing keeps the top-left corner in place, so the size is limited by the space to the page
    /// edge, and never goes below ``minSize``.
    static func clampResize(_ box: CGRect, page: CGSize) -> CGRect {
        let width = min(max(box.width, minSize), max(page.width - box.minX, minSize))
        let height = min(max(box.height, minSize), max(page.height - box.minY, minSize))
        return CGRect(x: box.minX, y: box.minY, width: width, height: height)
    }
}
