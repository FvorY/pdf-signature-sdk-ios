#if canImport(UIKit) && canImport(PDFKit)

import UIKit

/// Item ids, images and changes made from the overlay.
extension PdfSignatureView {
    // MARK: - Public item API

    @discardableResult
    public func placeSignature(_ options: PlaceOptions = .init()) throws -> String {
        try place(type: .signature, options: options)
    }

    @discardableResult
    public func placeEStamp(_ options: PlaceOptions = .init()) throws -> String {
        try place(type: .estamp, options: options)
    }

    /// Opens the native picker, or places the default signature when no options were configured.
    public func openSignatureModal() {
        openPicker(type: .signature)
    }

    /// Opens the native picker, or places the default E-Materai when no options were configured.
    public func openEStampModal() {
        openPicker(type: .estamp)
    }

    /// Applies `config.defaultPosition` to a placement started from the UI, clamped inside the page.
    func positioned(_ type: ItemType, _ options: PlaceOptions) -> PlaceOptions {
        guard let position = config.defaultPosition,
              let size = getPageSize(options.page ?? currentPage) else { return options }
        let isStamp = type == .estamp
        let width = options.width ?? (isStamp ? Self.estampSize : Self.signatureWidth)
        let height = options.height ?? (isStamp ? Self.estampSize : Self.signatureHeight)
        var result = options
        result.x = min(max(position.x, 0), max(0, Double(size.width) - width))
        result.y = min(max(position.y, 0), max(0, Double(size.height) - height))
        return result
    }

    /// Places an item the way the web SDK does: centered on the page (using the default size) unless
    /// both `x` and `y` are given, and E-Materai always labelled "E-Materai".
    func place(type: ItemType, options: PlaceOptions) throws -> String {
        guard isLoaded else { throw PsdkError.documentNotLoaded }
        let page = options.page ?? currentPage
        guard page >= 1, page <= totalPages, let size = getPageSize(page) else { throw PsdkError.invalidPage }
        let isStamp = type == .estamp
        let defaultWidth = isStamp ? Self.estampSize : Self.signatureWidth
        let defaultHeight = isStamp ? Self.estampSize : Self.signatureHeight
        let centered = options.x == nil || options.y == nil
        let label = isStamp ? Self.estampLabel : (options.label.flatMap { $0.isEmpty ? nil : $0 } ?? Self.signatureLabel)
        let item = SignatureItem(
            id: Self.makeID(type),
            type: type,
            x: centered ? Double(size.width) / 2 - defaultWidth / 2 : options.x ?? 0,
            y: centered ? Double(size.height) / 2 - defaultHeight / 2 : options.y ?? 0,
            page: page,
            label: label,
            width: options.width ?? defaultWidth,
            height: options.height ?? defaultHeight,
            disableDrag: options.disableDrag,
            disableDragging: options.disableDragging,
            disableResize: options.disableResize,
            locked: options.locked
        )
        items.append(item)
        if options.height != nil { explicitImageHeights.insert(item.id) }
        emit(isStamp ? .eStampPlaced(item) : .signaturePlaced(item))
        overlayView.setNeedsDisplay()
        if let image = options.image {
            Task { [weak self] in await self?.applyImage(image, to: item.id) }
        }
        return item.id
    }

    public func removeSignature(_ id: String) {
        guard items.contains(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        itemImages.removeValue(forKey: id)
        explicitImageHeights.remove(id)
        emit(.signatureRemoved(id: id))
        overlayView.setNeedsDisplay()
    }

    public func clearSignatures() {
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        emit(.signaturesCleared)
        overlayView.setNeedsDisplay()
    }

    public func getSignatures() -> [SignatureItem] { items }

    public func getSignaturesByPage(_ page: Int? = nil) -> [SignatureItem] {
        items.filter { $0.page == (page ?? currentPage) }
    }

    /// Page size in PDF points as displayed (CropBox, width and height swapped for /Rotate 90 or 270),
    /// rounded like the web SDK so default positions match it.
    public func getPageSize(_ page: Int) -> CGSize? {
        guard let pdfPage = document?.page(at: page - 1) else { return nil }
        return PageGeometry.webSize(PageGeometry.displaySize(bounds: pdfPage.bounds(for: .cropBox), rotation: pdfPage.rotation))
    }

    @available(*, deprecated, renamed: "getPageSize(_:)")
    public func pageSize(_ page: Int) -> CGSize? { getPageSize(page) }

    // MARK: - Ids, images and overlay changes

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
        guard let index = items.firstIndex(where: { $0.id == id }), let size = getPageSize(items[index].page) else { return }
        let item = items[index]
        let box = PageGeometry.clampMove(CGRect(x: x, y: y, width: item.width, height: item.height), page: size)
        items[index] = item.with(x: Double(box.minX), y: Double(box.minY))
        overlayView.setNeedsDisplay()
    }

    /// Resizes an item from the overlay, keeping its top-left corner and at least 20 pt on each side.
    func resizeItem(id: String, width: Double, height: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }), let size = getPageSize(items[index].page) else { return }
        let item = items[index]
        var box = PageGeometry.clampResize(CGRect(x: item.x, y: item.y, width: width, height: height), page: size)
        if item.type == .estamp, config.estampKeepAspectRatio, item.width > 0 {
            // Follow the width, then shrink both if the height hits the page edge
            let ratio = item.height / item.width
            var newWidth = Double(box.width)
            let maxHeight = Double(size.height) - item.y
            if newWidth * ratio > maxHeight { newWidth = maxHeight / ratio }
            newWidth = max(newWidth, Double(PageGeometry.minSize), Double(PageGeometry.minSize) / ratio)
            box = CGRect(x: item.x, y: item.y, width: newWidth, height: newWidth * ratio)
        }
        items[index] = item.with(width: Double(box.width), height: Double(box.height))
        overlayView.setNeedsDisplay()
    }

    func finishOverlayMove(_ id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        emit(.signatureMoved(item))
    }
}

#endif
