#if canImport(UIKit) && canImport(PDFKit)

import UIKit

extension PdfSignatureView {
    // MARK: - Skeleton

    /// Shows or hides a loading overlay over the pages while the host app works, e.g. while signing.
    public func showSkeleton(_ visible: Bool, options: SkeletonOptions? = nil) {
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        isSkeletonVisible = false
        guard visible, !isDestroyed else { return }
        let shown = options ?? SkeletonOptions()
        let area = chrome.viewerArea
        let container = UIView(frame: area.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(shown.backgroundOpacity))
        container.isAccessibilityElement = true
        container.accessibilityLabel = "Loading"
        container.accessibilityTraits = .updatesFrequently
        if shown.blurRadius > 0 {
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .dark : .light))
            blurView.frame = container.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(blurView)
        }
        let spinner: UIView
        if let custom = shown.customView {
            spinner = custom
        } else {
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.color = colors.accent
            indicator.startAnimating()
            spinner = indicator
        }
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        skeletonView = container
        area.addSubview(container)
        isSkeletonVisible = true
    }

    // MARK: - Picker

    /// Places the default item when there are no options, otherwise shows them (grouped with
    /// `groupByCategory`) in an action sheet.
    func openPicker(type: ItemType) {
        guard isLoaded, !config.disabled else { return }
        let isSignature = type == .signature
        let options = isSignature ? config.signatureOptions : config.estampOptions
        guard !options.isEmpty else {
            _ = try? place(type: type, options: .init())
            return
        }
        guard let presenter = nearestViewController else { return }
        let labels = config.labels
        let alert = UIAlertController(
            title: isSignature ? labels.signatureModalTitle : labels.estampModalTitle,
            message: nil,
            preferredStyle: .actionSheet
        )
        let groups = config.groupByCategory ? ChromeRules.group(options, defaultGroup: labels.defaultGroup) : [("", options)]
        for (group, members) in groups {
            for option in members {
                let label = ChromeRules.optionLabel(option, isSignature: isSignature, labels: labels)
                let title = group.isEmpty ? label : "\(group) · \(label)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    _ = try? self?.place(type: type, options: PlaceOptions(label: option.label, image: option.image))
                })
            }
        }
        alert.addAction(UIAlertAction(title: labels.cancelBtn, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(alert, animated: true)
    }

    // MARK: - Secure screen

    /// Covers the viewer while the screen is recorded or mirrored. iOS cannot block screenshots.
    func configureSecureScreenObserver() {
        guard config.secureScreen else {
            removeSecureScreenObserver()
            return
        }
        if secureScreenObserver == nil {
            secureScreenObserver = NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateSecureScreenOverlay() }
            }
        }
        updateSecureScreenOverlay()
    }

    func removeSecureScreenObserver() {
        if let secureScreenObserver {
            NotificationCenter.default.removeObserver(secureScreenObserver)
            self.secureScreenObserver = nil
        }
        secureScreenOverlay?.removeFromSuperview()
        secureScreenOverlay = nil
    }

    private func updateSecureScreenOverlay() {
        guard config.secureScreen, !isDestroyed, (window?.screen ?? UIScreen.main).isCaptured else {
            secureScreenOverlay?.removeFromSuperview()
            secureScreenOverlay = nil
            return
        }
        if secureScreenOverlay == nil {
            let cover = UIView(frame: bounds)
            cover.backgroundColor = .black
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(cover)
            secureScreenOverlay = cover
        }
        if let secureScreenOverlay { bringSubviewToFront(secureScreenOverlay) }
    }
}

#endif
