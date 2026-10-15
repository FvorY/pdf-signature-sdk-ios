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
    public private(set) var config: PsdkConfig
    public weak var delegate: PdfSignatureViewDelegate?

    public private(set) var isPasswordProtected = false
    public private(set) var currentPage = 1
    public private(set) var totalPages = 0
    public private(set) var currentScale: CGFloat
    public private(set) var isPaginationLocked = false
    public private(set) var isLoaded = false
    public private(set) var isLoading = false
    public private(set) var isDestroyed = false
    public private(set) var isSkeletonVisible = false

    public var eventsPublisher: AnyPublisher<PsdkEvent, Never> { events.eraseToAnyPublisher() }

    private let pdfView = PDFView()
    private let overlayView = ItemOverlayView()
    private var document: PDFDocument?
    private var pendingPasswordDocument: PDFDocument?
    private var items: [SignatureItem] = []
    private var itemImages: [String: UIImage] = [:]
    private var explicitImageHeights: Set<String> = []
    private var handlers: [UUID: (PsdkEvent) -> Void] = [:]
    private var onceHandlers: Set<UUID> = []
    private let events = PassthroughSubject<PsdkEvent, Never>()
    private var idCounter = 0
    private var skeletonView: UIView?
    private var secureScreenObserver: NSObjectProtocol?
    private var secureScreenOverlay: UIView?

    public init(config: PsdkConfig = .init()) {
        self.config = config
        self.currentScale = CGFloat(config.scale)
        super.init(frame: .zero)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = false
        pdfView.delegate = self
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.owner = self
        addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        configureSecureScreenObserver()
        if let file = config.file {
            Task { try? await loadDocument(file) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func loadDocument(_ source: PdfSource) async throws {
        guard !isDestroyed else { return }
        isLoading = true
        defer { isLoading = false }
        let data = try await loadData(source)
        guard let loaded = PDFDocument(data: data) else { throw PsdkError.invalidDocument }
        document = loaded
        pdfView.document = loaded
        if loaded.isLocked {
            pendingPasswordDocument = loaded
            isPasswordProtected = true
            isLoaded = false
            totalPages = 0
            currentPage = 0
            emitPasswordRequest(isIncorrect: false)
            return
        }
        finishLoading(loaded)
    }

    private func loadData(_ source: PdfSource) async throws -> Data {
        switch source {
        case .data(let value):
            try validateDocumentSize(value.count)
            return value
        case .file(let url):
            return try readLocalData(from: url)
        case .bundle(let name, let bundle):
            guard let url = bundle.url(forResource: name, withExtension: nil) else {
                throw PsdkError.sourceUnavailable
            }
            return try readLocalData(from: url)
        case .remote(let url, let headers):
            guard isAllowedRemoteURL(url) else { throw PsdkError.invalidURL }
            var request = URLRequest(url: url)
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            let loader = LimitedURLSession(
                allowInsecureHttp: config.allowInsecureHttp,
                maxBytes: Self.maxDocumentBytes,
                tooLargeError: .documentTooLarge
            )
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await loader.data(for: request)
            } catch let error as PsdkError {
                throw error
            } catch {
                throw PsdkError.sourceUnavailable
            }
            guard let http = response as? HTTPURLResponse else { throw PsdkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw PsdkError.httpStatus(http.statusCode) }
            try validateDocumentSize(data.count)
            return data
        }
    }

    private func loadItemImage(_ image: PsdkImage) async throws -> UIImage? {
        switch image {
        case .image(let value):
            return value
        case .base64(let value):
            let payload: String
            if let comma = value.firstIndex(of: ","), value[..<comma].lowercased().hasPrefix("data:") {
                payload = String(value[value.index(after: comma)...])
            } else {
                payload = value
            }
            guard payload.count <= Self.maxImageBase64Characters,
                  let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) else { return nil }
            guard data.count <= Self.maxImageBytes else { throw PsdkError.imageTooLarge }
            return UIImage(data: data)
        case .url(let url):
            guard isAllowedRemoteURL(url) else { throw PsdkError.invalidURL }
            let loader = LimitedURLSession(
                allowInsecureHttp: config.allowInsecureHttp,
                maxBytes: Self.maxImageBytes,
                tooLargeError: .imageTooLarge
            )
            let (data, response) = try await loader.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else { throw PsdkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw PsdkError.httpStatus(http.statusCode) }
            guard data.count <= Self.maxImageBytes else { throw PsdkError.imageTooLarge }
            return UIImage(data: data)
        }
    }

    private func readLocalData(from url: URL) throws -> Data {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                try validateDocumentSize(size.intValue)
            }
            let data = try Data(contentsOf: url)
            try validateDocumentSize(data.count)
            return data
        } catch let error as PsdkError {
            throw error
        } catch {
            throw PsdkError.sourceUnavailable
        }
    }

    private func validateDocumentSize(_ size: Int) throws {
        if size > Self.maxDocumentBytes { throw PsdkError.documentTooLarge }
    }

    private func isAllowedRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return false }
        return scheme == "https" || (config.allowInsecureHttp && scheme == "http")
    }

    private static let maxDocumentBytes = 100 * 1024 * 1024
    private static let maxImageBytes = 10 * 1024 * 1024
    private static let maxImageBase64Characters = 14_000_000

    private func finishLoading(_ loaded: PDFDocument) {
        pendingPasswordDocument = nil
        totalPages = loaded.pageCount
        currentPage = totalPages > 0 ? 1 : 0
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
        currentPage = 0
        isLoaded = false
        isPasswordProtected = false
        items.removeAll()
        itemImages.removeAll()
        explicitImageHeights.removeAll()
        overlayView.setNeedsDisplay()
    }

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

    public func setPaginationLocked(_ locked: Bool) { isPaginationLocked = locked }

    public func setScale(_ scale: CGFloat) async {
        currentScale = min(max(scale, 0.25), 4.0)
        pdfView.scaleFactor = currentScale
    }

    @discardableResult
    public func fitToScreen() async -> CGFloat {
        guard let page = document?.page(at: max(0, currentPage - 1)) else { return currentScale }
        let bounds = page.bounds(for: .cropBox)
        let available = pdfView.bounds.insetBy(dx: 24, dy: 24).size
        guard bounds.width > 0, bounds.height > 0, available.width > 0, available.height > 0 else { return currentScale }
        let scale = min(available.width / bounds.width, available.height / bounds.height)
        await setScale(scale)
        return currentScale
    }

    @discardableResult
    public func fitToWidth() async -> CGFloat {
        let availableWidth = pdfView.bounds.insetBy(dx: 24, dy: 24).width
        let widestPage = (0..<(document?.pageCount ?? 0))
            .compactMap { document?.page(at: $0)?.bounds(for: .cropBox).width }
            .max() ?? 0
        guard availableWidth > 0, widestPage > 0 else { return currentScale }
        await setScale(availableWidth / widestPage)
        return currentScale
    }

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

    /// Shows or hides a loading overlay while the host application performs work such as signing.
    public func showSkeleton(_ visible: Bool, options: SkeletonOptions? = nil) {
        guard !isDestroyed else { return }
        if !visible {
            skeletonView?.removeFromSuperview()
            skeletonView = nil
            isSkeletonVisible = false
            return
        }
        let shown = options ?? SkeletonOptions()
        let container = UIView(frame: bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(shown.backgroundOpacity))
        container.isAccessibilityElement = true
        container.accessibilityLabel = "Loading"
        if shown.blurRadius > 0 {
            let blur = UIBlurEffect(style: .systemMaterial)
            let blurView = UIVisualEffectView(effect: blur)
            blurView.frame = container.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(blurView)
        }
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        skeletonView?.removeFromSuperview()
        skeletonView = container
        addSubview(container)
        isSkeletonVisible = true
    }

    private func place(type: ItemType, options: PlaceOptions) throws -> String {
        guard isLoaded, let pageSize = pageSize(options.page ?? currentPage) else { throw PsdkError.documentNotLoaded }
        let page = options.page ?? currentPage
        guard page >= 1, page <= totalPages else { throw PsdkError.invalidPage }
        let defaultWidth = type == .signature ? 160.0 : 80.0
        let defaultHeight = type == .signature ? 48.0 : 80.0
        let width = options.width ?? defaultWidth
        let height = options.height ?? defaultHeight
        let idCounter = nextID()
        let item = SignatureItem(
            id: "\(type.rawValue)-\(Int(Date().timeIntervalSince1970 * 1000))-\(idCounter)",
            type: type,
            x: options.x ?? pageSize.width / 2 - defaultWidth / 2,
            y: options.y ?? pageSize.height / 2 - defaultHeight / 2,
            page: page,
            label: type == .estamp ? (options.label?.isEmpty == false ? options.label! : config.labels.defaultEStampLabel) : (options.label?.isEmpty == false ? options.label! : config.labels.defaultSignatureLabel),
            width: width,
            height: height,
            disableDrag: options.disableDrag,
            disableDragging: options.disableDragging,
            disableResize: options.disableResize,
            locked: options.locked
        )
        items.append(item)
        if options.height != nil { explicitImageHeights.insert(item.id) }
        emit(type == .signature ? .signaturePlaced(item) : .eStampPlaced(item))
        if let image = options.image {
            Task { [weak self] in
                guard let self else { return }
                guard let loaded = try? await self.loadItemImage(image) else { return }
                guard !self.isDestroyed, let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                self.itemImages[item.id] = loaded
                guard !self.explicitImageHeights.contains(item.id) else {
                    self.overlayView.setNeedsDisplay()
                    return
                }
                guard loaded.size.width > 0 else { return }
                let current = self.items[index]
                let resized = SignatureItem(
                    id: current.id,
                    type: current.type,
                    x: current.x,
                    y: current.y,
                    page: current.page,
                    label: current.label,
                    width: current.width,
                    height: current.width * Double(loaded.size.height / loaded.size.width),
                    disableDrag: current.disableDrag,
                    disableDragging: current.disableDragging,
                    disableResize: current.disableResize,
                    locked: current.locked
                )
                self.items[index] = resized
                self.overlayView.setNeedsDisplay()
                self.emit(.signatureMoved(resized))
            }
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

    public func pageSize(_ page: Int) -> CGSize? {
        guard let page = document?.page(at: page - 1) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        return page.rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
    }

    /// Renders one PDF page without the interactive overlay.
    public func renderPage(_ page: Int? = nil, scale: CGFloat? = nil) async -> UIImage? {
        guard let document, let pdfPage = document.page(at: max(0, (page ?? currentPage) - 1)) else { return nil }
        let bounds = pdfPage.bounds(for: .cropBox)
        let factor = max(0.25, scale ?? currentScale)
        let size = CGSize(width: bounds.width * factor, height: bounds.height * factor)
        guard size.width > 0, size.height > 0 else { return nil }
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: factor, y: -factor)
            pdfPage.draw(with: .cropBox, to: context)
            context.restoreGState()
        }
    }

    /// Renders one PDF page and draws the current page's items on top.
    public func renderPageWithOverlay(_ page: Int? = nil, scale: CGFloat? = nil) async -> UIImage? {
        guard let document, let pdfPage = document.page(at: max(0, (page ?? currentPage) - 1)) else { return nil }
        let targetPage = page ?? currentPage
        let bounds = pdfPage.bounds(for: .cropBox)
        let factor = max(0.25, scale ?? currentScale)
        let size = CGSize(width: bounds.width * factor, height: bounds.height * factor)
        guard size.width > 0, size.height > 0 else { return nil }
        let pageItems = items.filter { $0.page == targetPage }
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: factor, y: -factor)
            pdfPage.draw(with: .cropBox, to: context)
            context.restoreGState()
            for item in pageItems {
                let itemRect = CGRect(x: item.x * factor, y: item.y * factor, width: item.width * factor, height: item.height * factor)
                drawOverlayItem(item, in: itemRect, showControls: false)
            }
        }
    }

    @discardableResult
    public func on(_ type: PsdkEventType, _ handler: @escaping (PsdkEvent) -> Void) -> PsdkSubscription {
        let subscription = PsdkSubscription()
        handlers[subscription.id] = { event in if event.type == type { handler(event) } }
        return subscription
    }

    @discardableResult
    public func once(_ type: PsdkEventType, _ handler: @escaping (PsdkEvent) -> Void) -> PsdkSubscription {
        let subscription = on(type, handler)
        onceHandlers.insert(subscription.id)
        return subscription
    }

    public func off(_ subscription: PsdkSubscription) {
        handlers.removeValue(forKey: subscription.id)
        onceHandlers.remove(subscription.id)
    }

    public func updateConfig(_ transform: (inout PsdkConfig) -> Void) {
        transform(&config)
        currentScale = CGFloat(min(max(config.scale, 0.25), 4.0))
        pdfView.scaleFactor = currentScale
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
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        isSkeletonVisible = false
        if let secureScreenObserver {
            NotificationCenter.default.removeObserver(secureScreenObserver)
            self.secureScreenObserver = nil
        }
        secureScreenOverlay?.removeFromSuperview()
        secureScreenOverlay = nil
    }

    private func configureSecureScreenObserver() {
        if !config.secureScreen {
            if let secureScreenObserver {
                NotificationCenter.default.removeObserver(secureScreenObserver)
                self.secureScreenObserver = nil
            }
            secureScreenOverlay?.removeFromSuperview()
            secureScreenOverlay = nil
            return
        }
        guard secureScreenObserver == nil else {
            updateSecureScreenOverlay()
            return
        }
        secureScreenObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateSecureScreenOverlay() }
        }
        updateSecureScreenOverlay()
    }

    private func updateSecureScreenOverlay() {
        guard config.secureScreen else { return }
        if UIScreen.main.isCaptured {
            if secureScreenOverlay == nil {
                let cover = UIView()
                cover.backgroundColor = .black
                cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(cover)
                secureScreenOverlay = cover
            }
            secureScreenOverlay?.frame = bounds
        } else {
            secureScreenOverlay?.removeFromSuperview()
            secureScreenOverlay = nil
        }
    }

    private func openPicker(type: ItemType) {
        guard isLoaded, !config.disabled else { return }
        let options = type == .signature ? config.signatureOptions : config.estampOptions
        guard !options.isEmpty else {
            _ = try? place(type: type, options: .init())
            return
        }
        guard let presenter = nearestViewController else { return }
        let alert = UIAlertController(
            title: type == .signature ? config.labels.signatureModalTitle : config.labels.estampModalTitle,
            message: nil,
            preferredStyle: .actionSheet
        )
        for option in options {
            let label = option.label?.isEmpty == false
                ? option.label!
                : (type == .signature ? config.labels.defaultSignatureLabel : config.labels.defaultEStampLabel)
            let title = config.groupByCategory && option.group?.isEmpty == false
                ? "\(option.group!) · \(label)"
                : label
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                _ = try? self.place(type: type, options: PlaceOptions(label: option.label, image: option.image))
            })
        }
        alert.addAction(UIAlertAction(title: config.labels.cancelBtn, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds.insetBy(dx: bounds.width / 3, dy: bounds.height / 3)
        }
        presenter.present(alert, animated: true)
    }

    private var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    public func pdfViewPageChanged(_ notification: Notification) {
        guard let visible = pdfView.currentPage, let document,
              let index = (0..<document.pageCount).first(where: { document.page(at: $0) === visible }) else { return }
        let page = index + 1
        guard page != currentPage else { return }
        currentPage = page
        overlayView.setNeedsDisplay()
        emit(.pageChanged(page: page, total: totalPages, source: .scroll))
    }

    fileprivate func overlayItems() -> [SignatureItem] { items.filter { $0.page == currentPage } }

    fileprivate func pageRect(for item: SignatureItem) -> CGRect? {
        guard let page = document?.page(at: item.page - 1) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        let pdfRect = CGRect(x: bounds.minX + item.x, y: bounds.maxY - item.y - item.height, width: item.width, height: item.height)
        return pdfView.convert(pdfRect, from: page)
    }

    fileprivate func replaceOverlayItem(_ item: SignatureItem, with rect: CGRect, mode: OverlayGestureMode, startRect: CGRect) {
        guard let pageSize = pageSize(item.page), let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let pointScale = max(pdfView.scaleFactor, 0.001)
        let current = items[index]
        let currentRect = pageRect(for: current) ?? startRect
        let dx = Double(rect.minX - currentRect.minX) / pointScale
        let dy = Double(rect.minY - currentRect.minY) / pointScale
        let width = mode == .resize ? max(20, min(pageSize.width - current.x, Double(rect.width) / pointScale)) : current.width
        let height = mode == .resize ? max(20, min(pageSize.height - current.y, Double(rect.height) / pointScale)) : current.height
        let x = mode == .drag ? max(0, min(pageSize.width - current.width, current.x + dx)) : current.x
        let y = mode == .drag ? max(0, min(pageSize.height - current.height, current.y + dy)) : current.y
        items[index] = SignatureItem(id: current.id, type: current.type, x: x, y: y, page: current.page, label: current.label, width: width, height: height, disableDrag: current.disableDrag, disableDragging: current.disableDragging, disableResize: current.disableResize, locked: current.locked)
        overlayView.setNeedsDisplay()
    }

    fileprivate func finishOverlayMove(_ id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        emit(.signatureMoved(item))
    }

    private func nextID() -> Int { idCounter += 1; return idCounter }

    fileprivate func drawOverlayItem(_ item: SignatureItem, in itemRect: CGRect, showControls: Bool) {
        let color = item.type == .signature ? UIColor.systemBlue : UIColor.systemRed
        if let image = itemImages[item.id] {
            image.draw(in: itemRect)
        } else {
            color.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: itemRect, cornerRadius: 4).fill()
            item.label.draw(at: CGPoint(x: itemRect.minX + 6, y: itemRect.midY - 7), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: color,
            ])
        }
        color.withAlphaComponent(0.8).setStroke()
        let border = UIBezierPath(roundedRect: itemRect, cornerRadius: 4)
        border.lineWidth = 1
        border.stroke()
        guard showControls else { return }
        UIColor.systemRed.setFill()
        UIBezierPath(ovalIn: CGRect(x: itemRect.maxX - 20, y: itemRect.minY + 4, width: 12, height: 12)).fill()
        let handle = UIBezierPath()
        handle.move(to: CGPoint(x: itemRect.maxX - 12, y: itemRect.maxY - 2))
        handle.addLine(to: CGPoint(x: itemRect.maxX - 2, y: itemRect.maxY - 12))
        handle.lineWidth = 3
        color.setStroke()
        handle.stroke()
    }

    private func emit(_ event: PsdkEvent) {
        events.send(event)
        let current = handlers
        current.forEach { id, handler in
            handler(event)
            if onceHandlers.contains(id) {
                handlers.removeValue(forKey: id)
                onceHandlers.remove(id)
            }
        }
        delegate?.pdfSignatureView(self, didReceive: event)
    }
}

public enum PsdkError: Error, Equatable {
    case sourceUnavailable
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case documentTooLarge
    case imageTooLarge
    case invalidDocument
    case documentNotLoaded
    case invalidPage
}

private final class LimitedURLSession: NSObject, URLSessionDataDelegate {
    private let allowInsecureHttp: Bool
    private let maxBytes: Int
    private let tooLargeError: PsdkError
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private var buffer = Data()
    private var response: URLResponse?
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
    private var task: URLSessionDataTask?
    private var redirectCount = 0
    private var finished = false

    init(allowInsecureHttp: Bool, maxBytes: Int, tooLargeError: PsdkError) {
        self.allowInsecureHttp = allowInsecureHttp
        self.maxBytes = maxBytes
        self.tooLargeError = tooLargeError
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.dataTask(with: request)
            self.task = task
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard !finished else {
            completionHandler(.cancel)
            return
        }
        if response.expectedContentLength > Int64(maxBytes) {
            finish(.failure(tooLargeError))
            completionHandler(.cancel)
            return
        }
        self.response = response
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !finished else { return }
        guard buffer.count <= maxBytes - data.count else {
            finish(.failure(tooLargeError))
            dataTask.cancel()
            return
        }
        buffer.append(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard !finished else {
            completionHandler(nil)
            return
        }
        redirectCount += 1
        guard redirectCount <= 5 else {
            finish(.failure(PsdkError.sourceUnavailable))
            completionHandler(nil)
            return
        }
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              !host.isEmpty,
              scheme == "https" || (allowInsecureHttp && scheme == "http") else {
            finish(.failure(PsdkError.invalidURL))
            completionHandler(nil)
            return
        }
        var safeRequest = request
        // Never carry credentials to a different redirect destination.
        if let originalHost = task.originalRequest?.url?.host, originalHost != host {
            safeRequest.allHTTPHeaderFields?.keys
                .forEach { safeRequest.setValue(nil, forHTTPHeaderField: $0) }
        }
        completionHandler(safeRequest)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !finished else { return }
        if let error {
            finish(.failure(error))
        } else if let response {
            finish(.success((buffer, response)))
        } else {
            finish(.failure(PsdkError.invalidResponse))
        }
    }

    private func finish(_ result: Result<(Data, URLResponse), Error>) {
        guard !finished else { return }
        finished = true
        let continuation = continuation
        self.continuation = nil
        task?.cancel()
        switch result {
        case .success(let value): continuation?.resume(returning: value)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }
}

private enum OverlayGestureMode { case drag, resize, delete }

private final class ItemOverlayView: UIView {
    weak var owner: PdfSignatureView?
    private var activeID: String?
    private var mode: OverlayGestureMode = .drag
    private var startPoint = CGPoint.zero
    private var startRect = CGRect.zero
    private var moved = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let owner else { return }
        for item in owner.overlayItems() {
            guard let itemRect = owner.pageRect(for: item) else { continue }
            owner.drawOverlayItem(item, in: itemRect, showControls: true)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let owner, !owner.isDestroyed, !owner.isPaginationLocked, !owner.config.disabled else { return }
        let point = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            guard let item = hitItem(at: point), let rect = owner.pageRect(for: item) else { return }
            activeID = item.id
            startPoint = point
            startRect = rect
            moved = false
            let deleteRect = CGRect(x: rect.maxX - 24, y: rect.minY, width: 24, height: 24)
            let resizeRect = CGRect(x: rect.maxX - 28, y: rect.maxY - 28, width: 28, height: 28)
            mode = deleteRect.contains(point) ? .delete : (resizeRect.contains(point) ? .resize : .drag)
            if mode == .drag && (item.disableDrag || item.disableDragging || item.locked || owner.config.disableDrag || owner.config.disableDragging) { activeID = nil }
            if mode == .resize && (item.disableResize || item.disableDragging || item.locked || owner.config.disableResize || owner.config.disableDragging) { activeID = nil }
        case .changed:
            guard let id = activeID, let item = owner.getSignatures().first(where: { $0.id == id }) else { return }
            let translation = recognizer.translation(in: self)
            moved = moved || hypot(translation.x, translation.y) > 2
            guard moved, mode != .delete else { return }
            let nextRect = mode == .drag
                ? startRect.offsetBy(dx: translation.x, dy: translation.y)
                : CGRect(x: startRect.minX, y: startRect.minY, width: startRect.width + translation.x, height: startRect.height + translation.y)
            owner.replaceOverlayItem(item, with: nextRect, mode: mode, startRect: startRect)
        case .ended:
            guard let id = activeID else { return }
            if mode == .delete && !moved { owner.removeSignature(id) }
            else if moved { owner.finishOverlayMove(id) }
            activeID = nil
        default:
            activeID = nil
        }
    }

    private func hitItem(at point: CGPoint) -> SignatureItem? {
        guard let owner else { return nil }
        return owner.overlayItems().reversed().first { item in
            owner.pageRect(for: item)?.insetBy(dx: -12, dy: -12).contains(point) == true
        }
    }
}

#endif
