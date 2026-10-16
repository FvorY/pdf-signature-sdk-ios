#if canImport(UIKit) && canImport(PDFKit)

import PDFKit
import UIKit

/// Draws the placed items over the PDFView and handles drag, resize and delete.
/// Touches that do not start on an item pass through, so PDFView keeps scrolling and zooming.
@MainActor
final class ItemOverlayView: UIView {
    weak var owner: PdfSignatureView?

    private enum Mode { case drag, resize }

    private var activeID: String?
    private var mode = Mode.drag
    private var start = (x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    private var moved = false

    /// Delete and resize controls sit on the item's top-right and bottom-right corners, so they never
    /// overlap, even on small items.
    static let controlSize: CGFloat = 28
    /// Extra touch margin around an item, so small items and the corner controls are easy to grab.
    static let touchMargin: CGFloat = controlSize / 2

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let owner, !owner.isDestroyed, !owner.config.disabled else { return false }
        return hitItem(at: point) != nil
    }

    /// Elements are kept per item id: VoiceOver and UI tests expect the same object between queries.
    private var elementCache: [String: UIAccessibilityElement] = [:]

    /// One VoiceOver element per visible item, with move, resize and delete actions like the
    /// Android SDK (the overlay itself is drawn, so it has no subviews to read).
    override var accessibilityElements: [Any]? {
        get {
            guard let owner, !owner.isDestroyed else { return [] }
            var cache: [String: UIAccessibilityElement] = [:]
            let elements = visibleItems().map { item, rect -> UIAccessibilityElement in
                let element = elementCache[item.id] ?? UIAccessibilityElement(accessibilityContainer: self)
                element.accessibilityTraits = .button
                element.accessibilityLabel = String(format: owner.config.labels.a11yItem, item.label, item.page)
                element.accessibilityValue = "x \(Int(item.x)), y \(Int(item.y)), \(Int(item.width)) × \(Int(item.height))"
                element.accessibilityIdentifier = "psdk-item-\(item.type.rawValue)-\(item.page)"
                element.accessibilityFrameInContainerSpace = rect
                element.accessibilityCustomActions = owner.config.disabled ? [] : actions(for: item)
                cache[item.id] = element
                return element
            }
            elementCache = cache
            return elements
        }
        set { _ = newValue }
    }

    private func actions(for item: SignatureItem) -> [UIAccessibilityCustomAction] {
        guard let owner else { return [] }
        let labels = owner.config.labels
        let id = item.id
        func action(_ name: String, _ change: @escaping (PdfSignatureView, SignatureItem) -> Void) -> UIAccessibilityCustomAction {
            UIAccessibilityCustomAction(name: name) { [weak owner] _ in
                guard let owner, let current = owner.items.first(where: { $0.id == id }) else { return false }
                change(owner, current)
                owner.finishOverlayMove(id)
                return true
            }
        }
        var result: [UIAccessibilityCustomAction] = []
        if owner.canDrag(item) {
            let step = 10.0
            result += [
                action(labels.a11yMoveUp) { $0.moveItem(id: id, x: $1.x, y: $1.y - step) },
                action(labels.a11yMoveDown) { $0.moveItem(id: id, x: $1.x, y: $1.y + step) },
                action(labels.a11yMoveLeft) { $0.moveItem(id: id, x: $1.x - step, y: $1.y) },
                action(labels.a11yMoveRight) { $0.moveItem(id: id, x: $1.x + step, y: $1.y) }
            ]
        }
        if owner.canResize(item) {
            result += [
                action(labels.a11yBigger) { $0.resizeItem(id: id, width: $1.width * 1.1, height: $1.height * 1.1) },
                action(labels.a11ySmaller) { $0.resizeItem(id: id, width: $1.width / 1.1, height: $1.height / 1.1) }
            ]
        }
        result.append(UIAccessibilityCustomAction(name: labels.a11yDelete) { [weak owner] _ in
            owner?.removeSignature(id)
            return owner != nil
        })
        return result
    }

    override func draw(_ rect: CGRect) {
        guard let owner, !owner.isDestroyed else { return }
        let canDelete = !owner.config.disabled
        for (item, itemRect) in visibleItems() {
            owner.drawItem(item, in: itemRect, showDelete: canDelete, showResize: canDelete && owner.canResize(item))
        }
    }

    /// Items on the pages PDFView currently shows, with their rectangles in this view.
    private func visibleItems() -> [(SignatureItem, CGRect)] {
        guard let owner else { return [] }
        let visiblePages = Set(owner.visiblePageNumbers())
        return owner.items.compactMap { item in
            guard visiblePages.contains(item.page), let rect = owner.viewRect(for: item) else { return nil }
            return (item, rect)
        }
    }

    private func hitItem(at point: CGPoint) -> (SignatureItem, CGRect)? {
        visibleItems().reversed().first { _, rect in
            rect.insetBy(dx: -Self.touchMargin, dy: -Self.touchMargin).contains(point)
        }
    }

    static func deleteRect(for rect: CGRect) -> CGRect {
        CGRect(x: rect.maxX - controlSize / 2, y: rect.minY - controlSize / 2, width: controlSize, height: controlSize)
    }

    static func resizeRect(for rect: CGRect) -> CGRect {
        CGRect(x: rect.maxX - controlSize / 2, y: rect.maxY - controlSize / 2, width: controlSize, height: controlSize)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let owner, !owner.config.disabled else { return }
        let point = recognizer.location(in: self)
        guard let (item, rect) = hitItem(at: point) else { return }
        // The delete button works even on locked items, like the web SDK.
        if Self.deleteRect(for: rect).contains(point) {
            owner.haptic()
            owner.removeSignature(item.id)
        }
    }

    private func beginPan(at point: CGPoint) {
        guard let owner, let (item, rect) = hitItem(at: point) else { return }
        mode = Self.resizeRect(for: rect).contains(point) ? .resize : .drag
        let allowed = mode == .resize ? owner.canResize(item) : owner.canDrag(item)
        activeID = allowed ? item.id : nil
        if allowed { owner.haptic() }
        start = (item.x, item.y, item.width, item.height)
        moved = false
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let owner, !owner.isDestroyed, !owner.config.disabled else { return }
        switch recognizer.state {
        case .began:
            // A pan is recognized only after the finger has moved, so find the item where the touch started
            let location = recognizer.location(in: self)
            let offset = recognizer.translation(in: self)
            beginPan(at: CGPoint(x: location.x - offset.x, y: location.y - offset.y))
        case .changed:
            guard let id = activeID else { return }
            let translation = recognizer.translation(in: self)
            let scale = Double(max(owner.pdfView.scaleFactor, 0.001))
            let dx = Double(translation.x) / scale
            let dy = Double(translation.y) / scale
            moved = true
            switch mode {
            case .drag: owner.moveItem(id: id, x: start.x + dx, y: start.y + dy)
            case .resize: owner.resizeItem(id: id, width: start.width + dx, height: start.height + dy)
            }
        case .ended:
            if let id = activeID, moved { owner.finishOverlayMove(id) }
            activeID = nil
        default:
            activeID = nil
        }
    }
}

#endif
