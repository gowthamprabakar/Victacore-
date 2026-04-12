// TypographyTokens.swift
// VitaCoreDesign — Type scale tokens + ViewModifier integration
// Enterprise polish: numeric variants with monospacedDigit, refined tracking,
// heavier weights for display sizes per Apple HIG.

import SwiftUI

// MARK: - VCTypography

/// Type-scale tokens for VitaCore.
/// Each case maps to a SwiftUI `Font` and optional letter-spacing value.
public enum VCTypography: CaseIterable {
    // MARK: Display & Title
    case display
    case hero
    case title1
    case title2
    case title3

    // MARK: Numeric variants (ALWAYS use for metric values)
    /// 64pt — hero metric display (glucose primary, largest numeric value).
    case largeNumeric
    /// 48pt — metric detail hero values.
    case displayNumeric
    /// 32pt — metric grid primary values.
    case mediumNumeric
    /// 22pt — stat strip values.
    case smallNumeric

    // MARK: Body & UI
    case headline
    case body
    case subhead
    case footnote
    case caption
    case caption2

    // MARK: Specialty
    /// Uppercase section label (TODAY'S GOALS, LIVE METRICS).
    case sectionLabel
    /// Small pill badge / status chip.
    case badge
    /// Monospace for timestamps and data values.
    case mono
    /// Monospace tiny for source attribution.
    case monoTiny

    // -------------------------------------------------------------------------
    // MARK: Font
    // -------------------------------------------------------------------------

    public var font: Font {
        switch self {
        // Display & Title
        case .display:
            return .system(size: 48, weight: .black, design: .default)
        case .hero:
            return .system(size: 36, weight: .heavy, design: .default)
        case .title1:
            return .system(size: 28, weight: .bold, design: .default)
        case .title2:
            return .system(size: 22, weight: .bold, design: .default)
        case .title3:
            return .system(size: 20, weight: .semibold, design: .default)

        // Numeric variants — bold + rounded is intentionally NOT used for clinical data
        // (Apple Health uses default design for all values).
        case .largeNumeric:
            return .system(size: 64, weight: .bold, design: .default)
        case .displayNumeric:
            return .system(size: 48, weight: .bold, design: .default)
        case .mediumNumeric:
            return .system(size: 32, weight: .bold, design: .default)
        case .smallNumeric:
            return .system(size: 22, weight: .semibold, design: .default)

        // Body & UI
        case .headline:
            return .system(size: 17, weight: .semibold, design: .default)
        case .body:
            return .system(size: 17, weight: .regular, design: .default)
        case .subhead:
            return .system(size: 15, weight: .regular, design: .default)
        case .footnote:
            return .system(size: 13, weight: .regular, design: .default)
        case .caption:
            return .system(size: 12, weight: .regular, design: .default)
        case .caption2:
            return .system(size: 11, weight: .regular, design: .default)

        // Specialty
        case .sectionLabel:
            return .system(size: 12, weight: .semibold, design: .default)
        case .badge:
            return .system(size: 10, weight: .semibold, design: .default)
        case .mono:
            return .system(size: 11, weight: .medium, design: .monospaced)
        case .monoTiny:
            return .system(size: 9, weight: .medium, design: .monospaced)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Tracking (letter-spacing in em-relative points)
    // -------------------------------------------------------------------------

    /// Letter-spacing in points (positive = expand, negative = tighten).
    /// Calibrated per Apple HIG: larger sizes tighten, smaller expand slightly.
    public var tracking: CGFloat {
        switch self {
        // Display tightens per HIG (was -0.04 × 48 = -1.92, too tight)
        case .display:        return -0.022 * 48   // -1.05
        case .hero:           return -0.030 * 36   // -1.08
        case .title1:         return -0.020 * 28   // -0.56
        case .title2:         return -0.014 * 22   // -0.31
        case .title3:         return -0.010 * 20   // -0.20

        // Numeric values — slightly tighter than titles
        case .largeNumeric:   return -0.025 * 64   // -1.60
        case .displayNumeric: return -0.022 * 48   // -1.05
        case .mediumNumeric:  return -0.018 * 32   // -0.58
        case .smallNumeric:   return -0.012 * 22   // -0.26

        // Body — neutral
        case .headline:       return 0
        case .body:           return 0
        case .subhead:        return 0
        case .footnote:       return 0
        case .caption:        return 0
        case .caption2:       return 0

        // Specialty — expanded for readability at small sizes
        case .sectionLabel:   return 1.2
        case .badge:          return 0.5
        case .mono:           return 0
        case .monoTiny:       return 0
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Monospaced digits
    // -------------------------------------------------------------------------

    /// Whether this style uses tabular figures (no digit jitter on updates).
    /// Critical for numeric content that animates via `.contentTransition(.numericText())`.
    public var usesMonospacedDigits: Bool {
        switch self {
        case .largeNumeric, .displayNumeric, .mediumNumeric, .smallNumeric:
            return true
        case .mono, .monoTiny, .badge:
            return true
        default:
            return false
        }
    }

    /// Semantic text transform — sectionLabel is always uppercased.
    public var isUppercased: Bool {
        self == .sectionLabel
    }
}

// MARK: - VCFontModifier

/// Internal ViewModifier that applies a `VCTypography` style.
public struct VCFontModifier: ViewModifier {
    public let style: VCTypography

    public func body(content: Content) -> some View {
        if style.usesMonospacedDigits {
            content
                .font(style.font)
                .tracking(style.tracking)
                .monospacedDigit()
        } else {
            content
                .font(style.font)
                .tracking(style.tracking)
        }
    }
}

// MARK: - View extension

public extension View {
    /// Apply a VitaCore type-scale token to any `View`.
    ///
    ///     Text("Hello")
    ///         .vcFont(.headline)
    ///
    ///     Text("142")
    ///         .vcFont(.largeNumeric)   // Gets monospacedDigit automatically
    func vcFont(_ style: VCTypography) -> some View {
        modifier(VCFontModifier(style: style))
    }
}
