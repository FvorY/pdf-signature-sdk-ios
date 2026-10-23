#if canImport(UIKit) && canImport(PDFKit)

import os
import UIKit
import UniformTypeIdentifiers

extension PdfSignatureView {
    // MARK: - Theme and fonts

    /// Whether the dark colors are in use (``PsdkThemeMode/system`` follows the system appearance).
    var isDark: Bool { ChromeRules.isDark(config.theme, traits: traitCollection) }

    var colors: PsdkColors { isDark ? config.darkColors : config.lightColors }

    func font(_ style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        guard let typography = config.typography else { return base }
        // baseFontSize is the body size; other styles keep their ratio to it
        let body = UIFont.preferredFont(forTextStyle: .body).pointSize
        let size = typography.baseFontSize.map { CGFloat($0) * base.pointSize / body } ?? base.pointSize
        if let name = typography.fontName, let custom = UIFont(name: name, size: size) {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: custom)
        }
        return base.withSize(size)
    }

    /// Colors of everything the SDK draws, and the light/dark style of system sheets and menus.
    func applyTheme() {
        switch config.theme {
        case .light: overrideUserInterfaceStyle = .light
        case .dark: overrideUserInterfaceStyle = .dark
        case .system: overrideUserInterfaceStyle = .unspecified
        }
        pdfView.backgroundColor = colors.background
        chrome.rebuildIfNeeded(force: true)
        overlayView.setNeedsDisplay()
    }

    /// Theme button: switch between light and dark. No event.
    func toggleTheme() {
        let dark = isDark
        updateConfig { $0.theme = dark ? .light : .dark }
    }

    /// Zoom buttons: ±0.25 within 0.25–4.0.
    func stepZoom(_ step: CGFloat) {
        let next = ((currentScale + step) * 100).rounded() / 100
        Task { await setScale(min(max(next, 0.25), 4.0)) }
    }

    // MARK: - Dialogs

    func presentGoToPage() {
        guard isLoaded, !isPaginationLocked, config.ui.topbar.paginationInput, let presenter = nearestViewController else { return }
        let labels = config.labels
        let alert = UIAlertController(title: labels.goToPageTitle, message: "1 – \(totalPages)", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .numberPad
            field.text = "\(self.currentPage)"
        }
        alert.addAction(UIAlertAction(title: labels.cancelBtn, style: .cancel))
        alert.addAction(UIAlertAction(title: labels.okBtn, style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, let page = ChromeRules.parsePage(text) else { return }
            self?.goToPage(page)
        })
        presenter.present(alert, animated: true)
    }

    /// A placement started from the UI: with `askPositionOnAdd` ask for X/Y first, otherwise place it
    /// right away at `defaultPosition` or the page center.
    func startPlacement(type: ItemType, options: PlaceOptions) {
        guard config.askPositionOnAdd else {
            _ = try? place(type: type, options: positioned(type, options))
            return
        }
        guard let presenter = nearestViewController, let size = getPageSize(options.page ?? currentPage) else { return }
        let labels = config.labels
        let pageSize = String(
            format: labels.positionPageSize,
            Self.formatPoints(Double(size.width)),
            Self.formatPoints(Double(size.height))
        )
        let description = "\(labels.positionModalDesc)\n\(pageSize)"
        let alert = UIAlertController(title: labels.positionModalTitle, message: description, preferredStyle: .alert)
        for placeholder in [labels.positionX, labels.positionY] {
            alert.addTextField { field in
                field.keyboardType = .decimalPad
                field.placeholder = placeholder
            }
        }
        let place = UIAlertAction(title: labels.placeBtn, style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields, fields.count == 2 else { return }
            let input = ChromeRules.positionInput(x: fields[0].text ?? "", y: fields[1].text ?? "")
            switch input {
            case .center: _ = try? self.place(type: type, options: self.positioned(type, options))
            case let .position(x, y):
                let target = PlacementPosition(x: x, y: y)
                _ = try? self.place(type: type, options: self.positioned(type, options, at: target))
            case .invalid: break
            }
        }
        alert.addAction(UIAlertAction(title: labels.cancelBtn, style: .cancel))
        alert.addAction(place)
        // "Place" stays disabled while the fields are neither both empty nor both numbers
        let refresh = UIAction { [weak alert, weak place] _ in
            guard let fields = alert?.textFields, fields.count == 2 else { return }
            let input = ChromeRules.positionInput(x: fields[0].text ?? "", y: fields[1].text ?? "")
            place?.isEnabled = input != .invalid
            alert?.message = input == .invalid ? labels.positionInvalid : description
        }
        alert.textFields?.forEach { $0.addAction(refresh, for: .editingChanged) }
        presenter.present(alert, animated: true)
    }

    static func formatPoints(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.2f", value)
    }

    /// Built-in password dialog (`ui.passwordDialog`). The `passwordRequested` event is sent either way.
    func presentPasswordDialog(_ request: PasswordRequest) {
        guard config.ui.passwordDialog, let presenter = nearestViewController else { return }
        let labels = config.labels
        let message = request.isIncorrect ? labels.passwordIncorrect : labels.passwordModalDesc
        let alert = UIAlertController(title: labels.passwordModalTitle, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.isSecureTextEntry = true
            field.placeholder = labels.passwordPlaceholder
            field.textContentType = .password
        }
        alert.addAction(UIAlertAction(title: labels.cancelBtn, style: .cancel) { _ in request.cancel() })
        alert.addAction(UIAlertAction(title: labels.unlockBtn, style: .default) { [weak alert] _ in
            request.updatePassword(alert?.textFields?.first?.text ?? "")
        })
        presenter.present(alert, animated: true)
    }

    /// Upload button: system file picker for PDFs, then `onUpload` decides what opens.
    func openUploadPicker() {
        guard !config.disabled, let presenter = nearestViewController else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        let delegate = UploadPickerDelegate { [weak self] url in
            Task { await self?.handlePickedFile(url) }
        }
        uploadDelegate = delegate
        picker.delegate = delegate
        presenter.present(picker, animated: true)
    }

    func handlePickedFile(_ url: URL) async {
        let picked = PdfSource.file(url)
        let decision = await config.onUpload?(picked) ?? .proceed
        let source: PdfSource
        switch decision {
        case .cancel: return
        case .proceed: source = picked
        case .replace(let replacement): source = replacement
        }
        do {
            try await loadDocument(source)
        } catch {
            log(.error, "Could not open the picked file: \(error)")
        }
    }

    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                var top = controller
                while let presented = top.presentedViewController { top = presented }
                return top
            }
            responder = current.next
        }
        return nil
    }

    // MARK: - Haptics and logging

    func haptic() {
        guard config.ui.haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func log(_ level: PsdkLogLevel, _ message: @autoclosure () -> String) {
        switch (config.logLevel, level) {
        case (.none, _), (.error, .debug), (_, .none): return
        default: break
        }
        let text = message()
        if level == .error {
            Self.logger.error("\(text, privacy: .public)")
        } else {
            Self.logger.debug("\(text, privacy: .public)")
        }
    }

    static let logger = Logger(subsystem: "io.github.fvory.psdk", category: "PdfSignatureSDK")
}

/// Forwards the picked file; UIDocumentPickerViewController keeps only a weak delegate.
final class UploadPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onPick: (URL) -> Void

    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first { onPick(url) }
    }
}

#endif
