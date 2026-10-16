#if canImport(UIKit) && canImport(PDFKit)

import Combine
import PDFKit
import UIKit

/// UIKit delegate for viewer events.
@MainActor
public protocol PdfSignatureViewDelegate: AnyObject {
    func pdfSignatureView(_ view: PdfSignatureView, didReceive event: PsdkEvent)
}

/// Native viewer surface. Rendering uses PDFKit with a PDF-point overlay for placed items.
@MainActor
public final class PdfSignatureView: UIView, PDFViewDelegate {
    public internal(set) var config: PsdkConfig
    public weak var delegate: PdfSignatureViewDelegate?

    public private(set) var isPasswordProtected = false
    public internal(set) var currentPage = 1
    public private(set) var totalPages = 0
    public internal(set) var currentScale: CGFloat
    public private(set) var isPaginationLocked = false
    public private(set) var isLoaded = false
    public private(set) var isLoading = false
    public private(set) var isDestroyed = false
    public internal(set) var isSkeletonVisible = false

    public var eventsPublisher: AnyPublisher<PsdkEvent, Never> { events.eraseToAnyPublisher() }

    let pdfView = PDFView()
    let overlayView = ItemOverlayView()
    var document: PDFDocument?
    private var pendingPasswordDocument: PDFDocument?
    var items: [SignatureItem] = []
    var itemImages: [String: UIImage] = [:]
    var explicitImageHeights: Set<String> = []
    private var handlers: [UUID: (PsdkEvent) -> Void] = [:]
    private let events = PassthroughSubject<PsdkEvent, Never>()
    var notificationObservers: [NSObjectProtocol] = []
    var scrollObservation: NSKeyValueObservation?
    var skeletonView: UIView?
    var secureScreenObserver: NSObjectProtocol?
    var secureScreenOverlay: UIView?

    static let signatureWidth = 160.0
    static let signatureHeight = 48.0
    static let estampSize = 80.0
    /// Item labels are part of the backend payload, so they match the web SDK in every language.
    static let signatureLabel = "Signature"
    static let estampLabel = "E-Materai"

    public init(config: PsdkConfig = .init()) {
        self.config = config
        self.currentScale = CGFloat(config.scale ?? 1)
        super.init(frame: .zero)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = config.scale == nil
        pdfView.delegate = self
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        addSubview(pdfView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.owner = self
        addSubview(overlayView)
        for child in [pdfView, overlayView] as [UIView] {
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: leadingAnchor),
                child.trailingAnchor.constraint(equalTo: trailingAnchor),
                child.topAnchor.constraint(equalTo: topAnchor),
                child.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        observePdfView()
        configureSecureScreenObserver()
        if let file = config.file {
            Task { try? await loadDocument(file) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override public func layoutSubviews() {
        super.layoutSubviews()
        observeScrollViewIfNeeded()
        overlayView.setNeedsDisplay()
    }

    // MARK: - Loading
    public func loadDocument(_ source: PdfSource) async throws {
        guard !isDestroyed else { return }
        isLoading = true
        defer { isLoading = false }
        let data = try await loadData(source)
        guard let loaded = PDFDocument(data: data) else { throw PsdkError.invalidDocument }
        document = loaded
        pdfView.document = loaded
        applyConfiguredScale()
        observeScrollViewIfNeeded()
        if loaded.isLocked {
            pendingPasswordDocument = loaded
            isPasswordProtected = true
            isLoaded = false
            totalPages = 0
            currentPage = 1
            emitPasswordRequest(isIncorrect: false)
            return
        }
        finishLoading(loaded)
    }

    private func finishLoading(_ loaded: PDFDocument) {
        pendingPasswordDocument = nil
        totalPages = loaded.pageCount
        currentPage = 1
        isLoaded = totalPages > 0
        isPasswordProtected = false
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        emit(.signaturesCleared)
        emit(.documentLoaded(totalPages: totalPages))
        overlayView.setNeedsDisplay()
    }

    private func emitPasswordRequest(isIncorrect: Bool) {
        let request = PasswordRequest(
            isIncorrect: isIncorrect,
            submit: { [weak self] password in self?.unlock(password) },
            cancel: { [weak self] in self?.cancelPassword() }
        )
        emit(.passwordRequested(request))
    }

    private func unlock(_ password: String) {
        guard let locked = pendingPasswordDocument else { return }
        if locked.unlock(withPassword: password) {
            document = locked
            pdfView.document = locked
            finishLoading(locked)
        } else {
            emitPasswordRequest(isIncorrect: true)
        }
    }

    private func cancelPassword() {
        pendingPasswordDocument = nil
        document = nil
        pdfView.document = nil
        totalPages = 0
        currentPage = 1
        isLoaded = false
        isPasswordProtected = false
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        overlayView.setNeedsDisplay()
    }

    // MARK: - Navigation and zoom

    @discardableResult
    public func nextPage() -> Bool { goToPage(currentPage + 1) }

    @discardableResult
    public func prevPage() -> Bool { goToPage(currentPage - 1) }

    @discardableResult
    public func goToPage(_ page: Int) -> Bool {
        guard isLoaded, !isPaginationLocked, page >= 1, page <= totalPages, page != currentPage,
              let target = document?.page(at: page - 1) else { return false }
        currentPage = page
        pdfView.go(to: target)
        overlayView.setNeedsDisplay()
        emit(.pageChanged(page: page, total: totalPages, source: .api))
        return true
    }

    public func setPaginationLocked(_ locked: Bool) {
        isPaginationLocked = locked
        applyScrollLock()
    }

    public func setScale(_ scale: CGFloat) async {
        pdfView.autoScales = false
        currentScale = min(max(scale, 0.25), 4.0)
        pdfView.scaleFactor = currentScale
        overlayView.setNeedsDisplay()
    }

    /// A fixed `config.scale`, or PDFView's fit-to-width when it is `nil`.
    private func applyConfiguredScale() {
        if let scale = config.scale {
            pdfView.autoScales = false
            currentScale = CGFloat(min(max(scale, 0.25), 4.0))
            pdfView.scaleFactor = currentScale
        } else {
            pdfView.autoScales = true
            currentScale = pdfView.scaleFactor
        }
        overlayView.setNeedsDisplay()
    }

    @discardableResult
    public func fitToScreen() async -> CGFloat {
        guard let size = pageSize(currentPage) else { return currentScale }
        let available = pdfView.bounds.insetBy(dx: 24, dy: 24).size
        guard size.width > 0, size.height > 0, available.width > 0, available.height > 0 else { return currentScale }
        await setScale(min(available.width / size.width, available.height / size.height))
        return currentScale
    }

    @discardableResult
    public func fitToWidth() async -> CGFloat {
        let availableWidth = pdfView.bounds.insetBy(dx: 24, dy: 24).width
        let widestPage = (0..<totalPages).compactMap { pageSize($0 + 1)?.width }.max() ?? 0
        guard availableWidth > 0, widestPage > 0 else { return currentScale }
        await setScale(availableWidth / widestPage)
        return currentScale
    }

    // MARK: - Items

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

    /// Places an item the way the web SDK does: centered on the page (using the default size) unless
    /// both `x` and `y` are given, and E-Materai always labelled "E-Materai".
    func place(type: ItemType, options: PlaceOptions) throws -> String {
        guard isLoaded else { throw PsdkError.documentNotLoaded }
        let page = options.page ?? currentPage
        guard page >= 1, page <= totalPages, let size = pageSize(page) else { throw PsdkError.invalidPage }
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
    public func pageSize(_ page: Int) -> CGSize? {
        guard let pdfPage = document?.page(at: page - 1) else { return nil }
        return PageGeometry.webSize(PageGeometry.displaySize(bounds: pdfPage.bounds(for: .cropBox), rotation: pdfPage.rotation))
    }

    // MARK: - Events and lifecycle

    @discardableResult
    public func on(_ type: PsdkEventType, _ handler: @escaping (PsdkEvent) -> Void) -> PsdkSubscription {
        let subscription = PsdkSubscription()
        handlers[subscription.id] = { event in if event.type == type { handler(event) } }
        return subscription
    }

    @discardableResult
    public func once(_ type: PsdkEventType, _ handler: @escaping (PsdkEvent) -> Void) -> PsdkSubscription {
        let subscription = PsdkSubscription()
        handlers[subscription.id] = { [weak self] event in
            guard event.type == type else { return }
            self?.off(subscription)
            handler(event)
        }
        return subscription
    }

    public func off(_ subscription: PsdkSubscription) {
        handlers.removeValue(forKey: subscription.id)
    }

    public func updateConfig(_ transform: (inout PsdkConfig) -> Void) {
        let oldScale = config.scale
        transform(&config)
        if config.scale != oldScale { applyConfiguredScale() }
        applyScrollLock()
        overlayView.setNeedsDisplay()
        configureSecureScreenObserver()
    }

    public func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true
        pdfView.document = nil
        document = nil
        pendingPasswordDocument = nil
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        handlers.removeAll()
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        scrollObservation = nil
        showSkeleton(false)
        removeSecureScreenObserver()
        overlayView.setNeedsDisplay()
    }

    func emit(_ event: PsdkEvent) {
        events.send(event)
        for handler in Array(handlers.values) { handler(event) }
        delegate?.pdfSignatureView(self, didReceive: event)
    }
}

#endif
