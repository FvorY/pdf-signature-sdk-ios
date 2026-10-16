#if canImport(UIKit)

import UIKit

/// Color tokens, mapped from the web SDK's `--psdk-*` CSS variables. Start from ``light`` or
/// ``dark`` and change what you need. PDF pages are always drawn on white.
///
/// The defaults are the web SDK colors adjusted to pass WCAG AA (4.5:1) for text, the same as the
/// Android SDK. ``webLight`` and ``webDark`` give the exact web colors.
public struct PsdkColors {
    /// `--psdk-bg-base`: behind the pages.
    public var background: UIColor
    /// `--psdk-bg-surface`: toolbars, sheets, sidebar.
    public var surface: UIColor
    /// `--psdk-bg-elevated`: badges, inputs.
    public var surfaceElevated: UIColor
    /// `--psdk-bg-hover`: pressed buttons.
    public var surfacePressed: UIColor
    public var border: UIColor
    public var borderStrong: UIColor
    /// `--psdk-accent`: primary buttons, signature placeholders, active thumbnail.
    public var accent: UIColor
    public var accentPressed: UIColor
    public var accentSubtle: UIColor
    /// Text and icons on ``accent``.
    public var onAccent: UIColor
    /// `--psdk-danger`: delete buttons, E-Materai placeholders.
    public var danger: UIColor
    public var onDanger: UIColor
    public var dangerSubtle: UIColor
    public var success: UIColor
    public var warning: UIColor
    public var textPrimary: UIColor
    public var textSecondary: UIColor
    public var textMuted: UIColor

    /// Light theme, WCAG AA.
    public static var light: PsdkColors {
        var colors = webLight
        colors.accent = UIColor(argb: 0xFF0E_7C99)
        colors.accentPressed = UIColor(argb: 0xFF0B_6680)
        colors.accentSubtle = UIColor(argb: 0x1F0E_7C99)
        colors.danger = UIColor(argb: 0xFFDC_2626)
        colors.dangerSubtle = UIColor(argb: 0x1FDC_2626)
        return colors
    }

    /// Dark theme, WCAG AA.
    public static var dark: PsdkColors {
        var colors = webDark
        colors.onAccent = UIColor(argb: 0xFF0F_1117)
        colors.accentPressed = UIColor(argb: 0xFF3B_B4D3)
        colors.danger = UIColor(argb: 0xFFF2_6B6B)
        colors.dangerSubtle = UIColor(argb: 0x1FF2_6B6B)
        colors.onDanger = UIColor(argb: 0xFF0F_1117)
        colors.textMuted = UIColor(argb: 0xFF84_8BA0)
        return colors
    }

    /// The web SDK's light colors, unchanged.
    public static var webLight: PsdkColors {
        PsdkColors(
            background: UIColor(argb: 0xFFF8_FAFC),
            surface: UIColor(argb: 0xFFFF_FFFF),
            surfaceElevated: UIColor(argb: 0xFFF1_F5F9),
            surfacePressed: UIColor(argb: 0xFFE2_E8F0),
            border: UIColor(argb: 0x1400_0000),
            borderStrong: UIColor(argb: 0x2400_0000),
            accent: UIColor(argb: 0xFF14_A1C5),
            accentPressed: UIColor(argb: 0xFF10_8BA8),
            accentSubtle: UIColor(argb: 0x1F14_A1C5),
            onAccent: UIColor(argb: 0xFFFF_FFFF),
            danger: UIColor(argb: 0xFFEF_4444),
            onDanger: UIColor(argb: 0xFFFF_FFFF),
            dangerSubtle: UIColor(argb: 0x1FEF_4444),
            success: UIColor(argb: 0xFF22_C55E),
            warning: UIColor(argb: 0xFFF5_9E0B),
            textPrimary: UIColor(argb: 0xFF0F_172A),
            textSecondary: UIColor(argb: 0xFF47_5569),
            textMuted: UIColor(argb: 0xFF64_748B)
        )
    }

    /// The web SDK's dark colors, unchanged.
    public static var webDark: PsdkColors {
        var colors = webLight
        colors.background = UIColor(argb: 0xFF0F_1117)
        colors.surface = UIColor(argb: 0xFF1A_1D27)
        colors.surfaceElevated = UIColor(argb: 0xFF22_263A)
        colors.surfacePressed = UIColor(argb: 0xFF2A_2F45)
        colors.border = UIColor(argb: 0x14FF_FFFF)
        colors.borderStrong = UIColor(argb: 0x24FF_FFFF)
        colors.textPrimary = UIColor(argb: 0xFFF1_F5F9)
        colors.textSecondary = UIColor(argb: 0xFF8B_92A5)
        colors.textMuted = UIColor(argb: 0xFF5A_6070)
        return colors
    }
}

extension UIColor {
    /// A color from `0xAARRGGBB`, the same notation the Android SDK uses.
    convenience init(argb: UInt32) {
        self.init(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }
}

#endif
