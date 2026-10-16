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
    /// 0–1, opacity of the background behind the spinner.
    public let backgroundOpacity: Double
    /// Above 0, blurs the pages behind the overlay.
    public let blurRadius: Double
    #if canImport(UIKit)
    /// Replaces the default spinner (web: `customHTML`).
    public let customView: UIView?

    public init(backgroundOpacity: Double = 0.18, blurRadius: Double = 0, customView: UIView? = nil) {
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
        self.blurRadius = max(blurRadius, 0)
        self.customView = customView
    }
    #endif
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
