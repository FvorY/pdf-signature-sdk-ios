#if canImport(UIKit) && canImport(PDFKit)

import UIKit

extension ChromeView {
    // MARK: - Bars

    /// Web-style toolbar: brand, file and item buttons, pagination, zoom and theme in one row.
    func tabletTopBar() -> UIView {
        guard let owner else { return UIView() }
        let topbar = owner.config.ui.topbar
        let labels = owner.config.labels
        var views = brandViews()
        views.append(spacer())
        if topbar.upload { views.append(button("square.and.arrow.down", labels.uploadBtn, showTitle: true) { $0.openUploadPicker() }) }
        views += itemButtons(iconOnly: false)
        if topbar.pagination { views += paginationViews() }
        if topbar.zoom { views += zoomViews() }
        if topbar.themeToggle { views.append(themeButton()) }
        if let custom = topbar.customView { views.append(custom) }
        return scrollingBar(views, height: topbar.style?.height ?? 52, spread: false, style: topbar.style, lineOnTop: false)
    }

    /// Phone top bar: brand, custom view and a ⋯ menu with zoom, fit, theme and go-to-page.
    func phoneTopBar() -> UIView {
        guard let owner else { return UIView() }
        let topbar = owner.config.ui.topbar
        var views = brandViews()
        views.append(spacer())
        if let custom = topbar.customView { views.append(custom) }
        if topbar.zoom || topbar.themeToggle || (topbar.paginationInput && topbar.pagination) {
            let more = button("ellipsis.circle", owner.config.labels.moreMenu, showTitle: false) { _ in }
            more.menu = moreMenu()
            more.showsMenuAsPrimaryAction = true
            enabledWhenActive.append(more)
            views.append(more)
        }
        return bar(views, style: topbar.style, height: 48)
    }

    func phoneBottomBar(iconOnly: Bool) -> UIView {
        guard let owner else { return UIView() }
        var views: [UIView] = []
        if owner.config.ui.topbar.upload {
            views.append(button("square.and.arrow.down", owner.config.labels.uploadBtn, showTitle: !iconOnly) { $0.openUploadPicker() })
        }
        views += itemButtons(iconOnly: iconOnly)
        return scrollingBar(views, height: 56, spread: true, style: nil, lineOnTop: true)
    }

    /// Bottom bar that scrolls sideways when long labels do not fit, like the Android SDK; when they
    /// fit, the buttons are spread over the width.
    private func scrollingBar(_ views: [UIView], height: CGFloat, spread: Bool, style: TopBarStyle?, lineOnTop: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor = style?.background ?? colors.surface
        let padding = style?.horizontalPadding ?? 12
        for view in views where !(view is UIStackView) && view.accessibilityIdentifier != "psdk-spacer" {
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        pin(scroll, to: container)
        let stack = UIStackView(arrangedSubviews: views)
        stack.alignment = .center
        stack.spacing = 8
        stack.distribution = spread ? .equalSpacing : .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        let frame = scroll.frameLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -padding),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: frame.heightAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualTo: frame.widthAnchor, constant: -2 * padding),
            container.heightAnchor.constraint(equalToConstant: height)
        ])
        let line = UIView()
        line.backgroundColor = colors.border
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            lineOnTop
                ? line.topAnchor.constraint(equalTo: container.topAnchor)
                : line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return container
    }

    /// Floating "‹ 1 / 5 ›" over the pages on phones.
    func pagePill() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = colors.surface
        container.layer.cornerRadius = 20
        container.layer.borderWidth = 1
        container.layer.borderColor = colors.borderStrong.cgColor
        container.layer.shadowOpacity = 0.15
        container.layer.shadowRadius = 6
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        let stack = UIStackView(arrangedSubviews: paginationViews())
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            container.heightAnchor.constraint(equalToConstant: 40)
        ])
        return container
    }

    func statusBar() -> UIView {
        let status = label(.caption1, color: colors.textSecondary)
        let badge = label(.caption1, color: colors.success)
        badge.text = "🔒 " + (owner?.config.labels.securedBadge ?? "")
        let zoom = label(.caption1, color: colors.textMuted)
        statusLabel = status
        securedBadge = badge
        statusZoom = zoom
        return bar([status, badge, spacer(), zoom], style: nil, height: 28)
    }

    // MARK: - Groups

    private func brandViews() -> [UIView] {
        guard let owner else { return [] }
        let topbar = owner.config.ui.topbar
        var views: [UIView] = []
        if let logo = topbar.logo {
            let image = UIImageView(image: logo)
            image.contentMode = .scaleAspectFit
            image.widthAnchor.constraint(equalToConstant: 28).isActive = true
            image.heightAnchor.constraint(equalToConstant: 28).isActive = true
            views.append(image)
        }
        if let text = ChromeRules.brandText(topbar, labels: owner.config.labels) {
            let brand = label(.headline, color: topbar.style?.content ?? colors.textPrimary)
            brand.text = text
            brand.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            views.append(brand)
        }
        return views
    }

    private func itemButtons(iconOnly: Bool) -> [UIView] {
        guard let owner else { return [] }
        let topbar = owner.config.ui.topbar
        let labels = owner.config.labels
        var views: [UIView] = []
        if topbar.signature {
            let add = button("signature", labels.signatureBtn, showTitle: !iconOnly, filled: true) { $0.openSignatureModal() }
            addButtons.append(add)
            views.append(add)
        }
        if topbar.eStamp {
            let add = button("seal", labels.estampBtn, showTitle: !iconOnly) { $0.openEStampModal() }
            addButtons.append(add)
            views.append(add)
        }
        if topbar.signature || topbar.eStamp {
            let clear = button("trash", labels.clearBtn, showTitle: !iconOnly, tint: colors.danger) { $0.clearSignatures() }
            clearButtons.append(clear)
            views.append(clear)
        }
        return views
    }

    private func paginationViews() -> [UIView] {
        guard let owner else { return [] }
        let labels = owner.config.labels
        let prev = button("chevron.left", labels.prevPage, showTitle: false) { $0.prevPage() }
        let next = button("chevron.right", labels.nextPage, showTitle: false) { $0.nextPage() }
        let page = UIButton(type: .system)
        page.titleLabel?.font = owner.font(.subheadline).monospacedDigits
        page.setTitleColor(colors.textPrimary, for: .normal)
        page.addAction(UIAction { [weak owner] _ in owner?.presentGoToPage() }, for: .touchUpInside)
        prevButtons.append(prev)
        nextButtons.append(next)
        pageButtons.append(page)
        return [prev, page, next]
    }

    private func zoomViews() -> [UIView] {
        guard let owner else { return [] }
        let labels = owner.config.labels
        let out = button("minus.magnifyingglass", labels.zoomOut, showTitle: false) { $0.stepZoom(-0.25) }
        let into = button("plus.magnifyingglass", labels.zoomIn, showTitle: false) { $0.stepZoom(0.25) }
        let fit = button("arrow.up.left.and.arrow.down.right", labels.fitToScreen, showTitle: false) { viewer in
            Task { await viewer.fitToScreen() }
        }
        let percent = label(.subheadline, color: colors.textSecondary)
        percent.font = owner.font(.subheadline).monospacedDigits
        zoomOutButtons.append(out)
        zoomInButtons.append(into)
        zoomLabels.append(percent)
        enabledWhenActive.append(fit)
        return [out, percent, into, fit]
    }

    private func themeButton() -> UIButton {
        let dark = owner?.isDark ?? false
        let theme = button(dark ? "sun.max" : "moon", owner?.config.labels.toggleTheme ?? "", showTitle: false) { $0.toggleTheme() }
        enabledWhenActive.append(theme)
        return theme
    }

    private func moreMenu() -> UIMenu {
        guard let owner else { return UIMenu() }
        let topbar = owner.config.ui.topbar
        let labels = owner.config.labels
        func item(_ title: String, _ symbol: String, _ run: @escaping (PdfSignatureView) -> Void) -> UIAction {
            UIAction(title: title, image: UIImage(systemName: symbol)) { [weak owner] _ in
                if let owner { run(owner) }
            }
        }
        var actions: [UIMenuElement] = []
        if topbar.zoom {
            actions.append(item(labels.zoomIn, "plus.magnifyingglass") { $0.stepZoom(0.25) })
            actions.append(item(labels.zoomOut, "minus.magnifyingglass") { $0.stepZoom(-0.25) })
            actions.append(item(labels.fitToScreen, "arrow.up.left.and.arrow.down.right") { viewer in
                Task { await viewer.fitToScreen() }
            })
        }
        if topbar.pagination, topbar.paginationInput {
            actions.append(item(labels.goToPageTitle, "number") { $0.presentGoToPage() })
        }
        if topbar.themeToggle {
            actions.append(item(labels.toggleTheme, owner.isDark ? "sun.max" : "moon") { $0.toggleTheme() })
        }
        return UIMenu(children: actions)
    }

    // MARK: - Building blocks

    func button(
        _ symbol: String,
        _ title: String,
        showTitle: Bool,
        filled: Bool = false,
        tint: UIColor? = nil,
        action: @escaping (PdfSignatureView) -> Void
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        if showTitle {
            button.setTitle(" " + title, for: .normal)
            button.titleLabel?.font = owner?.font(.subheadline)
        }
        button.accessibilityLabel = title
        button.titleLabel?.lineBreakMode = .byClipping
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.tintColor = filled ? colors.onAccent : (tint ?? colors.accent)
        if filled {
            button.backgroundColor = colors.accent
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        button.addAction(UIAction { [weak self] _ in
            guard let owner = self?.owner else { return }
            action(owner)
        }, for: .touchUpInside)
        return button
    }

    func label(_ style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = owner?.font(style) ?? .preferredFont(forTextStyle: style)
        label.textColor = color
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    func spacer() -> UIView {
        let view = UIView()
        view.accessibilityIdentifier = "psdk-spacer"
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func bar(_ views: [UIView], style: TopBarStyle?, height: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = style?.background ?? colors.surface
        let stack = UIStackView(arrangedSubviews: views)
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        let padding = style?.horizontalPadding ?? 12
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: style?.height ?? height)
        ])
        let line = UIView()
        line.backgroundColor = colors.border
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return container
    }
}

extension UIFont {
    var monospacedDigits: UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                .typeIdentifier: kMonospacedNumbersSelector
            ]]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

#endif
