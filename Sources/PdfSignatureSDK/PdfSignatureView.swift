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
    lazy var chrome = ChromeView(owner: self)
    var document: PDFDocument?
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
    var uploadDelegate: UploadPickerDelegate?
    /// Why the last load failed; the empty state shows it (details only with `logLevel = .debug`).
    var lastError: Error?
    private var loadToken = 0
    private var pendingPassword: (id: UUID, continuation: CheckedContinuation<String?, Never>)?

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
        pdfView.autoScales = config.scale == nil
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4
        pdfView.delegate = self
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        overlayView.owner = self
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)
        chrome.pin(chrome, to: self)
        for child in [pdfView, overlayView] as [UIView] {
            child.translatesAutoresizingMaskIntoConstraints = false
            chrome.viewerArea.addSubview(child)
            chrome.pin(child, to: chrome.viewerArea)
        }
        observePdfView()
        configureSecureScreenObserver()
        applyTheme()
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

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if config.theme == .system, traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            applyTheme()
        }
    }

    // MARK: - Loading

    /// Opens a PDF. For an encrypted PDF it waits until `passwordRequested` is answered (or the
    /// built-in dialog), and throws ``PsdkError/passwordCancelled`` when the prompt is cancelled.
    public func loadDocument(_ source: PdfSource) async throws {
        guard !isDestroyed else { throw PsdkError.destroyed }
        answerPassword(nil, id: pendingPassword?.id)
        loadToken += 1
        let token = loadToken
        isLoading = true
        lastError = nil
        chrome.refresh()
        defer {
            if token == loadToken {
                isLoading = false
                chrome.refresh()
            }
        }
        do {
            let data = try await loadData(source)
            guard let loaded = PDFDocument(data: data) else { throw PsdkError.invalidDocument }
            if loaded.isLocked { try await unlock(loaded, token: token) }
            guard token == loadToken, !isDestroyed else { return }
            show(loaded)
            log(.debug, "Loaded \(loaded.pageCount) pages")
        } catch {
            if token == loadToken, !isDestroyed {
                lastError = error
                if case PsdkError.passwordCancelled = error { lastError = nil; closeDocument() }
                log(.error, "Could not open the PDF: \(error)")
            }
            throw error
        }
    }

    private func unlock(_ locked: PDFDocument, token: Int) async throws {
        var incorrect = false
        while true {
            guard let password = await askPassword(isIncorrect: incorrect, token: token) else {
                throw PsdkError.passwordCancelled
            }
            if locked.unlock(withPassword: password) { return }
            incorrect = true
        }
    }

    /// Sends `passwordRequested` and shows the built-in dialog. `nil` when cancelled or replaced.
    private func askPassword(isIncorrect: Bool, token: Int) async -> String? {
        guard token == loadToken, !isDestroyed else { return nil }
        isPasswordProtected = true
        return await withCheckedContinuation { continuation in
            let id = UUID()
            pendingPassword = (id, continuation)
            let request = PasswordRequest(
                isIncorrect: isIncorrect,
                submit: { [weak self] password in self?.answerPassword(password, id: id) },
                cancel: { [weak self] in self?.answerPassword(nil, id: id) }
            )
            emit(.passwordRequested(request))
            presentPasswordDialog(request)
        }
    }

    /// Answers only the prompt that is still open, so an old request cannot answer a newer one.
    private func answerPassword(_ password: String?, id: UUID?) {
        guard let pending = pendingPassword, pending.id == id else { return }
        pendingPassword = nil
        pending.continuation.resume(returning: password)
    }

    private func show(_ loaded: PDFDocument) {
        document = loaded
        pdfView.document = loaded
        applyConfiguredScale()
        observeScrollViewIfNeeded()
        totalPages = loaded.pageCount
        currentPage = 1
        isLoaded = totalPages > 0
        // The 🔒 badge shows while an encrypted document is open
        isPasswordProtected = loaded.isEncrypted
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        emit(.signaturesCleared)
        emit(.documentLoaded(totalPages: totalPages))
        chrome.rebuildIfNeeded()
        overlayView.setNeedsDisplay()
    }

    /// Back to the empty state, e.g. after a cancelled password prompt.
    private func closeDocument() {
        document = nil
        pdfView.document = nil
        totalPages = 0
        currentPage = 1
        isLoaded = false
        isPasswordProtected = false
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        chrome.rebuildIfNeeded()
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
        chrome.refresh()
    }

    public func setScale(_ scale: CGFloat) async {
        pdfView.autoScales = false
        currentScale = min(max(scale, 0.25), 4.0)
        pdfView.scaleFactor = currentScale
        overlayView.setNeedsDisplay()
        chrome.refresh()
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
        guard let size = getPageSize(currentPage) else { return currentScale }
        let available = pdfView.bounds.insetBy(dx: 24, dy: 24).size
        guard size.width > 0, size.height > 0, available.width > 0, available.height > 0 else { return currentScale }
        await setScale(min(available.width / size.width, available.height / size.height))
        return currentScale
    }

    @discardableResult
    public func fitToWidth() async -> CGFloat {
        let availableWidth = pdfView.bounds.insetBy(dx: 24, dy: 24).width
        let widestPage = (0..<totalPages).compactMap { getPageSize($0 + 1)?.width }.max() ?? 0
        guard availableWidth > 0, widestPage > 0 else { return currentScale }
        await setScale(availableWidth / widestPage)
        return currentScale
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
        configureSecureScreenObserver()
        applyTheme()
    }

    public func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true
        pdfView.document = nil
        document = nil
        answerPassword(nil, id: pendingPassword?.id)
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
        chrome.refresh()
    }
}

#endif
