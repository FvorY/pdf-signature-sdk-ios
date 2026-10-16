#if canImport(UIKit)

import UIKit

/// Light, dark, or follow the system appearance.
public enum PsdkThemeMode: String, Sendable {
    case light
    case dark
    /// Mobile addition: follows the system appearance and changes with it.
    case system
}

/// Phone or tablet layout; ``auto`` switches at 600 pt width.
public enum PsdkLayout: String, Sendable {
    case auto
    case phone
    case tablet
}

public enum PsdkLogLevel: String, Sendable {
    case none
    case error
    case debug
}

/// Result of `onUpload` (web: return `false`, a replacement file, or anything else).
public enum UploadDecision {
    /// Open the file the user picked.
    case proceed
    /// Do not open anything.
    case cancel
    /// Open this source instead of the picked file.
    case replace(PdfSource)
}

/// Font for the viewer chrome (Android: `fontFamily`).
public struct PsdkTypography: Sendable {
    public var fontName: String?
    public var baseFontSize: Double?

    public init(fontName: String? = nil, baseFontSize: Double? = nil) {
        self.fontName = fontName
        self.baseFontSize = baseFontSize
    }
}

/// Which parts of the viewer UI are shown (web: `ui`).
public struct PsdkUiConfig {
    public var topbar: TopBarConfig
    public var sidebar: SidebarConfig
    public var viewer: ViewerUiConfig
    /// Status line with "Ready", the item count and the zoom. Always shown on the web.
    public var statusbar: Bool
    /// Built-in password dialog. Turn off to show your own from the `passwordRequested` event.
    public var passwordDialog: Bool
    public var layout: PsdkLayout
    /// Short vibration when an item starts moving or is deleted.
    public var haptics: Bool

    public init(
        topbar: TopBarConfig = .init(),
        sidebar: SidebarConfig = .init(),
        viewer: ViewerUiConfig = .init(),
        statusbar: Bool = true,
        passwordDialog: Bool = true,
        layout: PsdkLayout = .auto,
        haptics: Bool = true
    ) {
        self.topbar = topbar
        self.sidebar = sidebar
        self.viewer = viewer
        self.statusbar = statusbar
        self.passwordDialog = passwordDialog
        self.layout = layout
        self.haptics = haptics
    }
}

/// Toolbar contents (web: `ui.topbar`). On phones the buttons are spread over a top bar, a bottom
/// bar, a floating page indicator and a ⋯ menu; a button turned off here is hidden everywhere.
public struct TopBarConfig {
    public var upload: Bool
    public var signature: Bool
    public var eStamp: Bool
    public var pagination: Bool
    public var paginationInput: Bool
    public var zoom: Bool
    public var themeToggle: Bool
    /// Extra view at the end of the top bar (web: `customComponent`).
    public var customView: UIView?
    /// Logo before the brand text. No logo by default.
    public var logo: UIImage?
    /// Brand text. `nil` shows `labels.brandDefault`; an empty string hides it.
    public var brandText: String?
    /// Replaces the web SDK's inline `style` object.
    public var style: TopBarStyle?

    public init(
        upload: Bool = true,
        signature: Bool = true,
        eStamp: Bool = true,
        pagination: Bool = true,
        paginationInput: Bool = true,
        zoom: Bool = true,
        themeToggle: Bool = true,
        customView: UIView? = nil,
        logo: UIImage? = nil,
        brandText: String? = nil,
        style: TopBarStyle? = nil
    ) {
        self.upload = upload
        self.signature = signature
        self.eStamp = eStamp
        self.pagination = pagination
        self.paginationInput = paginationInput
        self.zoom = zoom
        self.themeToggle = themeToggle
        self.customView = customView
        self.logo = logo
        self.brandText = brandText
        self.style = style
    }
}

public struct TopBarStyle {
    public var background: UIColor?
    public var content: UIColor?
    public var height: CGFloat?
    public var horizontalPadding: CGFloat?

    public init(background: UIColor? = nil, content: UIColor? = nil, height: CGFloat? = nil, horizontalPadding: CGFloat? = nil) {
        self.background = background
        self.content = content
        self.height = height
        self.horizontalPadding = horizontalPadding
    }
}

public struct SidebarConfig {
    /// Page thumbnails: a strip above the bottom bar on phones, a left sidebar on tablets.
    public var thumbnails: Bool

    public init(thumbnails: Bool = true) {
        self.thumbnails = thumbnails
    }
}

public struct ViewerUiConfig {
    /// Pinch-to-zoom and double-tap zoom (web: `ui.viewer.zoom`).
    public var zoom: Bool

    public init(zoom: Bool = true) {
        self.zoom = zoom
    }
}

/// Viewer configuration (web: the options object). Change it later with `updateConfig`.
public struct PsdkConfig {
    public var file: PdfSource?
    /// Remote HTTP is disabled by default. Enable only for a trusted legacy endpoint without TLS.
    public var allowInsecureHttp: Bool
    /// Initial zoom, 0.25–4.0. `nil` (default) fits the page width to the view.
    /// The web SDK defaults to 1.5; coordinates do not depend on the zoom.
    public var scale: Double?
    public var theme: PsdkThemeMode
    public var lightColors: PsdkColors
    public var darkColors: PsdkColors
    public var typography: PsdkTypography?
    /// Turns off every interaction with items, including delete and the add buttons.
    public var disabled: Bool
    /// Locks moving and resizing of every item.
    public var disableDragging: Bool
    /// Locks moving of every item.
    public var disableDrag: Bool
    /// Locks resizing of every item.
    public var disableResize: Bool
    /// Resizing an E-Materai keeps its width/height ratio.
    public var estampKeepAspectRatio: Bool
    public var signatureOptions: [PickerOption]
    public var estampOptions: [PickerOption]
    /// Shows picker options under their `group` headings.
    public var groupByCategory: Bool
    /// Called with the file the user picked from the upload button.
    public var onUpload: ((PdfSource) async -> UploadDecision)?
    /// Also blocks scrolling while pagination is locked (off by default, like the web SDK).
    public var lockScrollWhenPaginationLocked: Bool
    /// Covers the viewer while the screen is recorded or mirrored. iOS cannot block screenshots.
    public var secureScreen: Bool
    public var labels: PsdkLabels
    public var ui: PsdkUiConfig
    public var logLevel: PsdkLogLevel

    public init(
        file: PdfSource? = nil,
        allowInsecureHttp: Bool = false,
        scale: Double? = nil,
        theme: PsdkThemeMode = .light,
        lightColors: PsdkColors = .light,
        darkColors: PsdkColors = .dark,
        typography: PsdkTypography? = nil,
        disabled: Bool = false,
        disableDragging: Bool = false,
        disableDrag: Bool = false,
        disableResize: Bool = false,
        estampKeepAspectRatio: Bool = false,
        signatureOptions: [PickerOption] = [],
        estampOptions: [PickerOption] = [],
        groupByCategory: Bool = false,
        onUpload: ((PdfSource) async -> UploadDecision)? = nil,
        lockScrollWhenPaginationLocked: Bool = false,
        secureScreen: Bool = false,
        labels: PsdkLabels = .init(),
        ui: PsdkUiConfig = .init(),
        logLevel: PsdkLogLevel = .error
    ) {
        self.file = file
        self.allowInsecureHttp = allowInsecureHttp
        self.scale = scale.map { min(max($0, 0.25), 4.0) }
        self.theme = theme
        self.lightColors = lightColors
        self.darkColors = darkColors
        self.typography = typography
        self.disabled = disabled
        self.disableDragging = disableDragging
        self.disableDrag = disableDrag
        self.disableResize = disableResize
        self.estampKeepAspectRatio = estampKeepAspectRatio
        self.signatureOptions = signatureOptions
        self.estampOptions = estampOptions
        self.groupByCategory = groupByCategory
        self.onUpload = onUpload
        self.lockScrollWhenPaginationLocked = lockScrollWhenPaginationLocked
        self.secureScreen = secureScreen
        self.labels = labels
        self.ui = ui
        self.logLevel = logLevel
    }
}

#endif
