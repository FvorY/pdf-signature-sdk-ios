#if canImport(UIKit) && canImport(PDFKit)

import PDFKit
import UIKit

/// The viewer UI around the pages: top bar, phone bottom bar, page indicator, thumbnails, status
/// line and empty state, laid out for phones or tablets like the Android SDK. Everything follows
/// `owner.config`, so `updateConfig` applies right away.
@MainActor
final class ChromeView: UIView {
    weak var owner: PdfSignatureView?

    /// Holds the PDFView and the item overlay.
    let viewerArea = UIView()
    private let column = UIStackView()
    private let middle = UIStackView()
    private let emptyState = UIStackView()
    private let emptyTitle = UILabel()
    private let emptySubtitle = UILabel()
    private let emptyError = UILabel()
    private let emptyUpload = UIButton(type: .system)
    private var thumbnails: PDFThumbnailView?
    private var pill: UIView?

    // Controls updated by `refresh()`
    var pageButtons: [UIButton] = []
    var prevButtons: [UIButton] = []
    var nextButtons: [UIButton] = []
    var zoomLabels: [UILabel] = []
    var zoomOutButtons: [UIButton] = []
    var zoomInButtons: [UIButton] = []
    var addButtons: [UIButton] = []
    var clearButtons: [UIButton] = []
    var enabledWhenActive: [UIControl] = []
    var statusLabel: UILabel?
    var statusZoom: UILabel?
    var securedBadge: UILabel?

    private var builtKey = ""

    init(owner: PdfSignatureView) {
        self.owner = owner
        super.init(frame: .zero)
        column.axis = .vertical
        middle.axis = .horizontal
        for view in [column] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            pin(view, to: self)
        }
        viewerArea.clipsToBounds = true
        viewerArea.accessibilityIdentifier = "psdk-pages"
        buildEmptyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var colors: PsdkColors { owner?.colors ?? .light }
    var isTablet: Bool { ChromeRules.isTablet(owner?.config.ui.layout ?? .auto, width: bounds.width) }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildIfNeeded()
    }

    /// Rebuilds the bars when the layout, the visible parts or the theme changed.
    func rebuildIfNeeded(force: Bool = false) {
        guard let owner, bounds.width > 0 else { return }
        let key = [
            "\(isTablet)", "\(bounds.width < ChromeRules.iconOnlyMaxWidth)",
            "\(ChromeRules.showThumbnailStrip(height: bounds.height))", "\(ChromeRules.showStatusBar(height: bounds.height))",
            "\(owner.isLoaded)", "\(owner.isDark)"
        ].joined(separator: "|")
        guard force || key != builtKey else { return refresh() }
        builtKey = key
        rebuild()
    }

    private func rebuild() {
        guard let owner else { return }
        let config = owner.config
        column.arrangedSubviews.forEach { $0.removeFromSuperview() }
        middle.arrangedSubviews.forEach { $0.removeFromSuperview() }
        resetControls()
        backgroundColor = colors.background

        let topbar = config.ui.topbar
        let showBars = ChromeRules.topBarHasContent(topbar)
        if showBars { column.addArrangedSubview(isTablet ? tabletTopBar() : phoneTopBar()) }

        thumbnails = nil
        let wantsThumbnails = config.ui.sidebar.thumbnails && owner.isLoaded
        if isTablet, wantsThumbnails { middle.addArrangedSubview(makeThumbnails(vertical: true)) }
        middle.addArrangedSubview(viewerArea)
        column.addArrangedSubview(middle)
        if !isTablet {
            if wantsThumbnails, ChromeRules.showThumbnailStrip(height: bounds.height) {
                column.addArrangedSubview(makeThumbnails(vertical: false))
            }
            if showBars { column.addArrangedSubview(phoneBottomBar(iconOnly: bounds.width < ChromeRules.iconOnlyMaxWidth)) }
        }
        if config.ui.statusbar, ChromeRules.showStatusBar(height: bounds.height) { column.addArrangedSubview(statusBar()) }

        pill?.removeFromSuperview()
        pill = nil
        if !isTablet, topbar.pagination, owner.isLoaded {
            let indicator = pagePill()
            viewerArea.addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: viewerArea.centerXAnchor),
                indicator.bottomAnchor.constraint(equalTo: viewerArea.bottomAnchor, constant: -16)
            ])
            pill = indicator
        }
        applyEmptyStateColors()
        refresh()
    }

    private func resetControls() {
        pageButtons = []
        prevButtons = []
        nextButtons = []
        zoomLabels = []
        zoomOutButtons = []
        zoomInButtons = []
        addButtons = []
        clearButtons = []
        enabledWhenActive = []
        statusLabel = nil
        statusZoom = nil
        securedBadge = nil
    }

    private func makeThumbnails(vertical: Bool) -> UIView {
        let view = PDFThumbnailView()
        view.pdfView = owner?.pdfView
        view.layoutMode = vertical ? .vertical : .horizontal
        view.thumbnailSize = vertical ? CGSize(width: 84, height: 110) : CGSize(width: 48, height: 64)
        view.backgroundColor = colors.surface
        view.accessibilityLabel = owner?.config.labels.sidebarTitle
        view.translatesAutoresizingMaskIntoConstraints = false
        if vertical {
            view.widthAnchor.constraint(equalToConstant: 120).isActive = true
        } else {
            view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }
        thumbnails = view
        return view
    }

    /// Updates texts and enabled states after a page, zoom, item or lock change.
    func refresh() {
        guard let owner else { return }
        let config = owner.config
        let active = !config.disabled
        let pageText = owner.isLoaded ? "\(owner.currentPage) / \(owner.totalPages)" : "– / –"
        pageButtons.forEach {
            $0.setTitle(pageText, for: .normal)
            $0.isEnabled = active && owner.isLoaded && config.ui.topbar.paginationInput && !owner.isPaginationLocked
            $0.accessibilityLabel = String(format: config.labels.a11yPage, owner.currentPage, owner.totalPages)
        }
        let canNavigate = active && owner.isLoaded && !owner.isPaginationLocked
        prevButtons.forEach { $0.isEnabled = canNavigate && owner.currentPage > 1 }
        nextButtons.forEach { $0.isEnabled = canNavigate && owner.currentPage < owner.totalPages }
        zoomLabels.forEach { $0.text = ChromeRules.zoomPercent(owner.currentScale) }
        zoomOutButtons.forEach { $0.isEnabled = active && owner.isLoaded && owner.currentScale > 0.25 }
        zoomInButtons.forEach { $0.isEnabled = active && owner.isLoaded && owner.currentScale < 4 }
        addButtons.forEach { $0.isEnabled = active && owner.isLoaded }
        clearButtons.forEach { $0.isEnabled = active && !owner.items.isEmpty }
        enabledWhenActive.forEach { $0.isEnabled = active }
        thumbnails?.isUserInteractionEnabled = !owner.isPaginationLocked
        let parts = [config.labels.statusReady, ChromeRules.itemCount(owner.items.count, labels: config.labels)].compactMap { $0 }
        statusLabel?.text = parts.joined(separator: " · ")
        statusZoom?.text = owner.isLoaded ? ChromeRules.zoomPercent(owner.currentScale) : nil
        securedBadge?.isHidden = !(owner.isLoaded && owner.isPasswordProtected)
        refreshEmptyState()
    }

    // MARK: - Empty state

    private func buildEmptyState() {
        emptyState.axis = .vertical
        emptyState.alignment = .center
        emptyState.spacing = 8
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: "doc.text"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)
        emptyTitle.font = .preferredFont(forTextStyle: .headline)
        for label in [emptySubtitle, emptyError] {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        emptyUpload.addAction(UIAction { [weak self] _ in self?.owner?.openUploadPicker() }, for: .touchUpInside)
        [icon, emptyTitle, emptySubtitle, emptyError, emptyUpload].forEach(emptyState.addArrangedSubview)
        viewerArea.addSubview(emptyState)
        NSLayoutConstraint.activate([
            emptyState.centerXAnchor.constraint(equalTo: viewerArea.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: viewerArea.centerYAnchor),
            emptyState.widthAnchor.constraint(lessThanOrEqualTo: viewerArea.widthAnchor, constant: -48)
        ])
    }

    private func applyEmptyStateColors() {
        emptyState.arrangedSubviews.first?.tintColor = colors.textMuted
        emptyTitle.textColor = colors.textPrimary
        emptySubtitle.textColor = colors.textSecondary
        emptyError.textColor = colors.danger
        emptyUpload.tintColor = colors.accent
        if let font = owner?.font(.headline) { emptyTitle.font = font }
    }

    private func refreshEmptyState() {
        guard let owner else { return }
        let labels = owner.config.labels
        emptyState.isHidden = owner.isLoaded || owner.isLoading
        emptyTitle.text = labels.emptyTitle
        emptySubtitle.text = labels.emptySubtitle
        emptyUpload.setTitle(labels.uploadBtn, for: .normal)
        emptyUpload.isHidden = !owner.config.ui.topbar.upload
        emptyUpload.isEnabled = !owner.config.disabled
        // Error details only with logLevel debug, like the Android SDK
        if let error = owner.lastError {
            emptyError.isHidden = false
            emptyError.text = owner.config.logLevel == .debug ? "\(labels.errorLoad): \(error)" : labels.errorLoad
        } else {
            emptyError.isHidden = true
        }
        viewerArea.bringSubviewToFront(emptyState)
        if let pill { viewerArea.bringSubviewToFront(pill) }
    }

    func pin(_ view: UIView, to container: UIView) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

#endif
