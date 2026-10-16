#if canImport(UIKit) && canImport(PDFKit)

import PDFKit
import UIKit

/// Follows PDFView's current page, scroll and zoom, and applies the scroll lock.
extension PdfSignatureView {
    /// Scrolling changes the current page (`pageChanged` with source `.scroll`).
    func handlePageChanged() {
        guard let visible = pdfView.currentPage, let document else { return }
        let index = document.index(for: visible)
        guard index != NSNotFound else { return }
        let page = index + 1
        guard page != currentPage else { return }
        currentPage = page
        overlayView.setNeedsDisplay()
        emit(.pageChanged(page: page, total: totalPages, source: .scroll))
    }

    /// The overlay is drawn in view coordinates, so it is redrawn whenever PDFView scrolls or zooms.
    func observePdfView() {
        let center = NotificationCenter.default
        let scale = center.addObserver(forName: .PDFViewScaleChanged, object: pdfView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentScale = self.pdfView.scaleFactor
                self.overlayView.setNeedsDisplay()
                self.chrome.refresh()
            }
        }
        let visible = center.addObserver(forName: .PDFViewVisiblePagesChanged, object: pdfView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.overlayView.setNeedsDisplay() }
        }
        let page = center.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePageChanged() }
        }
        notificationObservers = [scale, visible, page]
    }

    func observeScrollViewIfNeeded() {
        guard scrollObservation == nil, let scrollView = Self.findScrollView(in: pdfView) else { return }
        scrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.overlayView.setNeedsDisplay() }
        }
        applyScrollLock()
    }

    /// Scroll lock (`lockScrollWhenPaginationLocked`) and pinch / double-tap zoom (`ui.viewer.zoom`).
    func applyScrollLock() {
        let locked = isPaginationLocked && config.lockScrollWhenPaginationLocked
        let scrollView = Self.findScrollView(in: pdfView)
        scrollView?.isScrollEnabled = !locked
        scrollView?.pinchGestureRecognizer?.isEnabled = config.ui.viewer.zoom
        Self.doubleTapRecognizers(in: pdfView).forEach { $0.isEnabled = config.ui.viewer.zoom }
    }

    private static func doubleTapRecognizers(in view: UIView) -> [UITapGestureRecognizer] {
        let own = (view.gestureRecognizers ?? []).compactMap { $0 as? UITapGestureRecognizer }.filter { $0.numberOfTapsRequired == 2 }
        return own + view.subviews.flatMap(doubleTapRecognizers)
    }

    private static func findScrollView(in view: UIView) -> UIScrollView? {
        for child in view.subviews {
            if let scrollView = child as? UIScrollView { return scrollView }
            if let nested = findScrollView(in: child) { return nested }
        }
        return nil
    }
}

extension SignatureItem {
    func with(x: Double? = nil, y: Double? = nil, width: Double? = nil, height: Double? = nil) -> SignatureItem {
        SignatureItem(
            id: id,
            type: type,
            x: x ?? self.x,
            y: y ?? self.y,
            page: page,
            label: label,
            width: width ?? self.width,
            height: height ?? self.height,
            disableDrag: disableDrag,
            disableDragging: disableDragging,
            disableResize: disableResize,
            locked: locked
        )
    }
}

#endif
