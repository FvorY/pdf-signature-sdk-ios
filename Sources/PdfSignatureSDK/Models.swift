import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// A PDF supplied to the viewer.
public enum PdfSource {
    case file(URL)
    case data(Data)
    case remote(URL, headers: [String: String] = [:])
    case bundle(name: String, bundle: Bundle = .main)
}

/// An image used by a placed item.
public enum PsdkImage {
    case url(URL)
    case base64(String)
#if canImport(UIKit)
    case image(UIImage)
#endif

    public init(string: String) {
        if string.hasPrefix("data:"), let comma = string.firstIndex(of: ",") {
            self = .base64(String(string[string.index(after: comma)...]))
        } else if let url = URL(string: string) {
            self = .url(url)
        } else {
            self = .base64(string)
        }
    }
}

/// Options used when placing a signature or E-Materai item.
public struct PlaceOptions {
    public var x: Double?
    public var y: Double?
    public var page: Int?
    public var label: String?
    public var image: PsdkImage?
    public var width: Double?
    public var height: Double?
    public var disableDrag: Bool
    public var disableDragging: Bool
    public var disableResize: Bool
    public var locked: Bool

    public init(
        x: Double? = nil,
        y: Double? = nil,
        page: Int? = nil,
        label: String? = nil,
        image: PsdkImage? = nil,
        width: Double? = nil,
        height: Double? = nil,
        disableDrag: Bool = false,
        disableDragging: Bool = false,
        disableResize: Bool = false,
        locked: Bool = false
    ) {
        self.x = x
        self.y = y
        self.page = page
        self.label = label
        self.image = image
        self.width = width
        self.height = height
        self.disableDrag = disableDrag
        self.disableDragging = disableDragging
        self.disableResize = disableResize
        self.locked = locked
    }
}

public enum ItemType: String, Codable, Sendable {
    case signature
    case estamp
}

/// Theme preference for the native viewer chrome.
public enum PsdkThemeMode: String, Sendable {
    case light
    case dark
    case system
}

/// A choice shown by the signature or E-Materai picker.
public struct PickerOption {
    public let id: String
    public let label: String?
    public let image: PsdkImage?
    public let group: String?

    public init(id: String, label: String? = nil, image: PsdkImage? = nil, group: String? = nil) {
        self.id = id
        self.label = label
        self.image = image
        self.group = group
    }
}

/// Options for the loading overlay shown by `showSkeleton`.
public struct SkeletonOptions {
    public let backgroundOpacity: Double
    public let blurRadius: Double

    public init(backgroundOpacity: Double = 0.18, blurRadius: Double = 0) {
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
        self.blurRadius = max(blurRadius, 0)
    }
}

/// Text shown by the built-in native dialogs and toolbar actions.
public struct PsdkLabels: Sendable {
    public var uploadBtn: String
    public var signatureBtn: String
    public var estampBtn: String
    public var clearBtn: String
    public var signatureModalTitle: String
    public var estampModalTitle: String
    public var defaultGroup: String
    public var cancelBtn: String
    public var defaultSignatureLabel: String
    public var defaultEStampLabel: String

    public init(
        uploadBtn: String = "Open PDF",
        signatureBtn: String = "Add Signature",
        estampBtn: String = "E-Materai",
        clearBtn: String = "Clear All",
        signatureModalTitle: String = "Select Signature Role",
        estampModalTitle: String = "Select E-Materai",
        defaultGroup: String = "General",
        cancelBtn: String = "Cancel",
        defaultSignatureLabel: String = "Signature",
        defaultEStampLabel: String = "E-Materai"
    ) {
        self.uploadBtn = uploadBtn
        self.signatureBtn = signatureBtn
        self.estampBtn = estampBtn
        self.clearBtn = clearBtn
        self.signatureModalTitle = signatureModalTitle
        self.estampModalTitle = estampModalTitle
        self.defaultGroup = defaultGroup
        self.cancelBtn = cancelBtn
        self.defaultSignatureLabel = defaultSignatureLabel
        self.defaultEStampLabel = defaultEStampLabel
    }

    public static let indonesian = PsdkLabels(
        uploadBtn: "Buka PDF",
        signatureBtn: "Tambah Tanda Tangan",
        estampBtn: "E-Materai",
        clearBtn: "Hapus Semua",
        signatureModalTitle: "Pilih Peran Penanda Tangan",
        estampModalTitle: "Pilih E-Materai",
        defaultGroup: "Umum",
        cancelBtn: "Batal",
        defaultSignatureLabel: "Tanda Tangan",
        defaultEStampLabel: "E-Materai"
    )
}

/// Optional color tokens for hosts that want consistent native chrome.
public struct PsdkColors: Sendable {
    public var background: String
    public var surface: String
    public var content: String
    public var accent: String
    public var danger: String

    public init(
        background: String = "#FFFFFF",
        surface: String = "#F7F8FA",
        content: String = "#111827",
        accent: String = "#2563EB",
        danger: String = "#DC2626"
    ) {
        self.background = background
        self.surface = surface
        self.content = content
        self.accent = accent
        self.danger = danger
    }
}

public struct PsdkTypography: Sendable {
    public var fontName: String?
    public var baseFontSize: Double?

    public init(fontName: String? = nil, baseFontSize: Double? = nil) {
        self.fontName = fontName
        self.baseFontSize = baseFontSize
    }
}

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

public enum UploadDecision {
    case proceed
    case cancel
    case replace(PdfSource)
}

/// Which parts of the native viewer chrome are shown.
public struct PsdkUiConfig: Sendable {
    public var upload: Bool
    public var signature: Bool
    public var eStamp: Bool
    public var pagination: Bool
    public var zoom: Bool
    public var themeToggle: Bool
    public var thumbnails: Bool
    public var passwordDialog: Bool
    public var haptics: Bool
    public var paginationInput: Bool
    public var statusbar: Bool
    public var layout: PsdkLayout
    public var brandText: String?

    public init(
        upload: Bool = true,
        signature: Bool = true,
        eStamp: Bool = true,
        pagination: Bool = true,
        zoom: Bool = true,
        themeToggle: Bool = true,
        thumbnails: Bool = true,
        passwordDialog: Bool = true,
        haptics: Bool = true,
        paginationInput: Bool = true,
        statusbar: Bool = true,
        layout: PsdkLayout = .auto,
        brandText: String? = nil
    ) {
        self.upload = upload
        self.signature = signature
        self.eStamp = eStamp
        self.pagination = pagination
        self.zoom = zoom
        self.themeToggle = themeToggle
        self.thumbnails = thumbnails
        self.passwordDialog = passwordDialog
        self.haptics = haptics
        self.paginationInput = paginationInput
        self.statusbar = statusbar
        self.layout = layout
        self.brandText = brandText
    }
}

/// A placed item. Coordinates are always PDF points with a top-left origin.
public struct SignatureItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: ItemType
    public let x: Double
    public let y: Double
    public let page: Int
    public let label: String
    public let width: Double
    public let height: Double
    public let disableDrag: Bool
    public let disableDragging: Bool
    public let disableResize: Bool
    public let locked: Bool

    public init(
        id: String,
        type: ItemType,
        x: Double,
        y: Double,
        page: Int,
        label: String,
        width: Double,
        height: Double,
        disableDrag: Bool = false,
        disableDragging: Bool = false,
        disableResize: Bool = false,
        locked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.page = page
        self.label = label
        self.width = width
        self.height = height
        self.disableDrag = disableDrag
        self.disableDragging = disableDragging
        self.disableResize = disableResize
        self.locked = locked
    }

    public func yFromBottom(pageHeight: Double) -> Double {
        pageHeight - y - height
    }
}

/// Basic viewer configuration. UI configuration is added alongside the native toolbar.
public struct PsdkConfig {
    public var file: PdfSource?
    /// Initial zoom, 0.25–4.0. `nil` (default) fits the page width to the view, like the Android SDK.
    /// The web SDK defaults to 1.5; coordinates do not depend on the zoom.
    public var scale: Double?
    /// Remote HTTP is disabled by default. Enable only for a trusted legacy endpoint without TLS.
    public var allowInsecureHttp: Bool

    public var theme: PsdkThemeMode
    public var labels: PsdkLabels
    public var signatureOptions: [PickerOption]
    public var estampOptions: [PickerOption]
    public var groupByCategory: Bool
    public var disabled: Bool
    public var disableDragging: Bool
    public var disableDrag: Bool
    public var disableResize: Bool
    public var ui: PsdkUiConfig
    public var colors: PsdkColors?
    public var typography: PsdkTypography?
    public var estampKeepAspectRatio: Bool
    public var lockScrollWhenPaginationLocked: Bool
    public var secureScreen: Bool
    public var logLevel: PsdkLogLevel
    public var onUpload: ((PdfSource) async -> UploadDecision)?

    public init(
        file: PdfSource? = nil,
        scale: Double? = nil,
        allowInsecureHttp: Bool = false,
        theme: PsdkThemeMode = .system,
        labels: PsdkLabels = .init(),
        signatureOptions: [PickerOption] = [],
        estampOptions: [PickerOption] = [],
        groupByCategory: Bool = false,
        disabled: Bool = false,
        disableDragging: Bool = false,
        disableDrag: Bool = false,
        disableResize: Bool = false,
        ui: PsdkUiConfig = .init(),
        colors: PsdkColors? = nil,
        typography: PsdkTypography? = nil,
        estampKeepAspectRatio: Bool = false,
        lockScrollWhenPaginationLocked: Bool = false,
        secureScreen: Bool = false,
        logLevel: PsdkLogLevel = .error,
        onUpload: ((PdfSource) async -> UploadDecision)? = nil
    ) {
        self.file = file
        self.scale = scale.map { min(max($0, 0.25), 4.0) }
        self.allowInsecureHttp = allowInsecureHttp
        self.theme = theme
        self.labels = labels
        self.signatureOptions = signatureOptions
        self.estampOptions = estampOptions
        self.groupByCategory = groupByCategory
        self.disabled = disabled
        self.disableDragging = disableDragging
        self.disableDrag = disableDrag
        self.disableResize = disableResize
        self.ui = ui
        self.colors = colors
        self.typography = typography
        self.estampKeepAspectRatio = estampKeepAspectRatio
        self.lockScrollWhenPaginationLocked = lockScrollWhenPaginationLocked
        self.secureScreen = secureScreen
        self.logLevel = logLevel
        self.onUpload = onUpload
    }
}
