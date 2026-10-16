#if canImport(UIKit) && canImport(PDFKit)

import UIKit

/// Item ids, images and changes made from the overlay.
extension PdfSignatureView {
    /// Ids in the web SDK format: `<type>-<epoch millis>-<5 random base-36 characters>`.
    static func makeID(_ type: ItemType) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        let suffix = String((0..<5).map { _ in alphabet.randomElement() ?? "0" })
        return "\(type.rawValue)-\(Int64(Date().timeIntervalSince1970 * 1000))-\(suffix)"
    }

    /// Without an explicit height, the item's height follows the image's aspect ratio (web SDK).
    func applyImage(_ image: PsdkImage, to id: String) async {
        guard let loaded = try? await loadItemImage(image) else { return }
        guard !isDestroyed, let index = items.firstIndex(where: { $0.id == id }) else { return }
        itemImages[id] = loaded
        overlayView.setNeedsDisplay()
        guard !explicitImageHeights.contains(id), loaded.size.width > 0 else { return }
        let current = items[index]
        let resized = current.with(height: current.width * Double(loaded.size.height / loaded.size.width))
        items[index] = resized
        emit(.signatureMoved(resized))
    }

    /// Moves an item from the overlay, keeping it on its page.
    func moveItem(id: String, x: Double, y: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }), let size = pageSize(items[index].page) else { return }
        let item = items[index]
        let box = PageGeometry.clampMove(CGRect(x: x, y: y, width: item.width, height: item.height), page: size)
        items[index] = item.with(x: Double(box.minX), y: Double(box.minY))
        overlayView.setNeedsDisplay()
    }

    /// Resizes an item from the overlay, keeping its top-left corner and at least 20 pt on each side.
    func resizeItem(id: String, width: Double, height: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }), let size = pageSize(items[index].page) else { return }
        let item = items[index]
        let box = PageGeometry.clampResize(CGRect(x: item.x, y: item.y, width: width, height: height), page: size)
        items[index] = item.with(width: Double(box.width), height: Double(box.height))
        overlayView.setNeedsDisplay()
    }

    func finishOverlayMove(_ id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        emit(.signatureMoved(item))
    }
}

#endif
