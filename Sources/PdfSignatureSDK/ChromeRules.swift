#if canImport(UIKit)

import UIKit

/// Rules behind the toolbar, picker and status line, the same as the Android SDK's `ChromeRules`.
enum ChromeRules {
    static let tabletMinWidth: CGFloat = 600
    static let iconOnlyMaxWidth: CGFloat = 360
    /// Below this viewer height the phone thumbnail strip is hidden, so the bottom bar keeps its room.
    static let minHeightForThumbnails: CGFloat = 560
    /// Below this viewer height the status line is hidden as well.
    static let minHeightForStatusBar: CGFloat = 420

    static func showThumbnailStrip(height: CGFloat) -> Bool { height >= minHeightForThumbnails }

    static func showStatusBar(height: CGFloat) -> Bool { height >= minHeightForStatusBar }

    /// No top bar when every toolbar option is off and there is nothing custom to show.
    static func topBarHasContent(_ topbar: TopBarConfig) -> Bool {
        topbar.upload || topbar.signature || topbar.eStamp || topbar.pagination || topbar.paginationInput ||
            topbar.zoom || topbar.themeToggle || topbar.customView != nil || topbar.logo != nil ||
            !(topbar.brandText ?? "x").isEmpty
    }

    static func isTablet(_ layout: PsdkLayout, width: CGFloat) -> Bool {
        switch layout {
        case .phone: return false
        case .tablet: return true
        case .auto: return width >= tabletMinWidth
        }
    }

    /// `""` hides the brand, `nil` uses the default text.
    static func brandText(_ topbar: TopBarConfig, labels: PsdkLabels) -> String? {
        guard let text = topbar.brandText else { return labels.brandDefault }
        return text.isEmpty ? nil : text
    }

    /// Groups in order of first appearance; options without a group go under `defaultGroup`.
    static func group(_ options: [PickerOption], defaultGroup: String) -> [(String, [PickerOption])] {
        var order: [String] = []
        var groups: [String: [PickerOption]] = [:]
        for option in options {
            let key = option.group ?? ""
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(option)
        }
        return order.map { ($0.isEmpty ? defaultGroup : $0, groups[$0] ?? []) }
    }

    /// Option text, or the default label when it has none.
    static func optionLabel(_ option: PickerOption, isSignature: Bool, labels: PsdkLabels) -> String {
        if let label = option.label, !label.isEmpty { return label }
        return isSignature ? labels.defaultSignatureLabel : labels.defaultEStampLabel
    }

    /// "1 signature" / "N signatures", `nil` when there are none.
    static func itemCount(_ count: Int, labels: PsdkLabels) -> String? {
        switch count {
        case 0: return nil
        case 1: return String(format: labels.signatureCountOne, count)
        default: return String(format: labels.signatureCountOther, count)
        }
    }

    static func zoomPercent(_ scale: CGFloat) -> String { "\(Int((scale * 100).rounded()))%" }

    /// Parsed page number, or `nil` when the text is not a number.
    static func parsePage(_ text: String) -> Int? { Int(text.trimmingCharacters(in: .whitespaces)) }

    /// Light or dark for the theme, following the system for ``PsdkThemeMode/system``.
    static func isDark(_ theme: PsdkThemeMode, traits: UITraitCollection) -> Bool {
        switch theme {
        case .light: return false
        case .dark: return true
        case .system: return traits.userInterfaceStyle == .dark
        }
    }
}

#endif
