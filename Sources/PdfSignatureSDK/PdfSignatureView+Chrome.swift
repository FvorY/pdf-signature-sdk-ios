#if canImport(UIKit) && canImport(PDFKit)

import UIKit

extension PdfSignatureView {
    // MARK: - Skeleton

    /// Shows or hides a loading overlay while the host application performs work such as signing.
    public func showSkeleton(_ visible: Bool, options: SkeletonOptions? = nil) {
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        isSkeletonVisible = false
        guard visible, !isDestroyed else { return }
        let shown = options ?? SkeletonOptions()
        let container = UIView(frame: bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(shown.backgroundOpacity))
        container.isAccessibilityElement = true
        container.accessibilityLabel = "Loading"
        container.accessibilityTraits = .updatesFrequently
        if shown.blurRadius > 0 {
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
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
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        skeletonView = container
        addSubview(container)
        isSkeletonVisible = true
    }

    // MARK: - Picker

    func openPicker(type: ItemType) {
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
            let fallback = type == .signature ? config.labels.defaultSignatureLabel : config.labels.defaultEStampLabel
            let label = option.label.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
            let group = option.group.flatMap { $0.isEmpty ? nil : $0 } ?? config.labels.defaultGroup
            let title = config.groupByCategory ? "\(group) · \(label)" : label
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                _ = try? self?.place(type: type, options: PlaceOptions(label: option.label, image: option.image))
            })
        }
        alert.addAction(UIAlertAction(title: config.labels.cancelBtn, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(alert, animated: true)
    }

    private var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller.presentedViewController ?? controller
            }
            responder = current.next
        }
        return nil
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
