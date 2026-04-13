// ColorTokens.swift
// VitaCoreDesign — Ethereal Light colour palette
// All hex values decoded at compile time via private Color(hex:) extension.

import SwiftUI

// MARK: - Hex convenience (private to this package)

extension Color {
    /// Initialise from a 6-digit hex string, e.g. "#694ead" or "694ead".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - VCColors

/// Ethereal Light design-system colour tokens for VitaCore.
public enum VCColors {

    // -------------------------------------------------------------------------
    // MARK: Brand / Primary
    // -------------------------------------------------------------------------

    /// Deep violet – primary interactive colour.
    public static let primary          = Color(hex: "694ead")
    /// Soft lavender – container behind primary elements.
    public static let primaryContainer = Color(hex: "cbb6ff")
    /// Slightly darker violet for pressed / dimmed states.
    public static let primaryDim       = Color(hex: "5d41a0")

    // -------------------------------------------------------------------------
    // MARK: Secondary
    // -------------------------------------------------------------------------

    /// Mauve-pink – secondary accent.
    public static let secondary          = Color(hex: "a2395f")
    /// Blush – container behind secondary elements.
    public static let secondaryContainer = Color(hex: "ffd9e1")

    // -------------------------------------------------------------------------
    // MARK: Tertiary
    // -------------------------------------------------------------------------

    /// Teal-blue – tertiary accent (data / charts).
    public static let tertiary          = Color(hex: "006594")
    /// Sky – container behind tertiary elements.
    public static let tertiaryContainer = Color(hex: "71c0f9")

    // -------------------------------------------------------------------------
    // MARK: Background & Surface
    // -------------------------------------------------------------------------

    /// Page background – near-white with faint violet undertone.
    public static let background     = Color(hex: "faf9fc")

    /// Absolute white card surface.
    public static let surfaceLowest  = Color(hex: "ffffff")
    /// Slightly off-white for elevated containers.
    public static let surfaceLow     = Color(hex: "f4f3f8")
    /// Default surface tone.
    public static let surface        = Color(hex: "eeedf3")
    /// Raised surface – card headers, section dividers.
    public static let surfaceHigh    = Color(hex: "e8e7ee")
    /// Highest raised surface.
    public static let surfaceHighest = Color(hex: "e2e2e9")
    /// Subdued surface for disabled / inactive states.
    public static let surfaceDim     = Color(hex: "d9d9e1")

    // -------------------------------------------------------------------------
    // MARK: Content / Text
    // -------------------------------------------------------------------------

    /// Primary text — 12.6:1 contrast on background (WCAG AAA).
    public static let onSurface        = Color(hex: "1E1F24")
    /// Secondary / supporting text — 7.8:1 contrast (WCAG AAA).
    public static let onSurfaceVariant = Color(hex: "4A4C54")
    /// Tertiary / placeholder / label text — 4.7:1 contrast (WCAG AA).
    public static let outline          = Color(hex: "696B73")
    /// Hairline dividers and subtle borders.
    public static let outlineVariant   = Color(hex: "A8A9B0")

    // -------------------------------------------------------------------------
    // MARK: Health State Colours (clinical spec)
    // -------------------------------------------------------------------------

    /// Safe / in-range – teal.
    public static let safe        = Color(hex: "00BFA5")
    /// Tinted safe background at 18 % opacity.
    public static let safeDim     = Color(hex: "00BFA5").opacity(0.18)

    /// Watch / borderline – amber.
    public static let watch       = Color(hex: "FFB300")
    /// Tinted watch background at 18 % opacity.
    public static let watchDim    = Color(hex: "FFB300").opacity(0.18)

    /// Alert – orange (between watch and critical).
    public static let alertOrange = Color(hex: "FF6B00")

    /// Critical – crimson.
    public static let critical    = Color(hex: "FF1744")
    /// Tinted critical background at 20 % opacity.
    public static let criticalDim = Color(hex: "FF1744").opacity(0.20)

    // -------------------------------------------------------------------------
    // MARK: Glass Colours
    // -------------------------------------------------------------------------

    /// Standard glass fill – white at 60 % opacity.
    public static let glassSurface  = Color.white.opacity(0.60)
    /// Enhanced glass fill – white at 75 % opacity.
    public static let glassEnhanced = Color.white.opacity(0.75)
    /// Glass edge highlight – white at 40 % opacity (stronger than before for crisp borders).
    public static let glassBorder   = Color.white.opacity(0.40)
    /// Glass edge subtle tint — brand colored highlight for hero cards.
    public static let glassBorderTinted = Color(hex: "694ead").opacity(0.18)
    /// Violet-tinted glass shadow at 8 % opacity.
    public static let glassShadow   = Color(hex: "694ead").opacity(0.08)

    // -------------------------------------------------------------------------
    // MARK: Layered Shadows — ambient + key light
    // -------------------------------------------------------------------------

    /// Contact shadow — tight, dark, close to element (1pt below).
    public static let shadowContact = Color.black.opacity(0.04)
    /// Ambient shadow — softer, wider, adds depth (6-12pt below).
    public static let shadowAmbient = Color.black.opacity(0.06)
    /// Key light shadow — colored, atmospheric, far below (16-24pt).
    public static let shadowKey     = Color(hex: "4A2F8A").opacity(0.10)
    /// Hero card glow — brand-colored aura for featured content.
    public static let shadowHero    = Color(hex: "694ead").opacity(0.15)

    // -------------------------------------------------------------------------
    // MARK: Elevated Surfaces
    // -------------------------------------------------------------------------

    /// Surface for modal sheets and floating elements.
    public static let surfaceElevated = Color(hex: "FCFBFF")
    /// Surface for contextual floating overlays.
    public static let surfaceFloating = Color(hex: "FFFFFF")

    // =========================================================================
    // MARK: Dark Mode Palette (Sprint 1 D-01)
    // =========================================================================

    /// Deep space background — near-black with violet undertone.
    public static let backgroundDark     = Color(hex: "0F0E14")
    public static let surfaceLowestDark  = Color(hex: "1A1922")
    public static let surfaceLowDark     = Color(hex: "22212B")
    public static let surfaceDark        = Color(hex: "2B2A35")
    public static let surfaceHighDark    = Color(hex: "35343F")
    public static let surfaceHighestDark = Color(hex: "3F3E49")
    public static let surfaceDimDark     = Color(hex: "17161F")

    /// Light text on dark surfaces — same contrast ratios as light mode.
    public static let onSurfaceDark        = Color(hex: "E8E7EE")
    public static let onSurfaceVariantDark = Color(hex: "B0B1B8")
    public static let outlineDark          = Color(hex: "8A8B92")
    public static let outlineVariantDark   = Color(hex: "5A5B62")

    /// Glass on dark — slightly lighter than surface with higher opacity.
    public static let glassSurfaceDark  = Color.white.opacity(0.08)
    public static let glassEnhancedDark = Color.white.opacity(0.12)
    public static let glassBorderDark   = Color.white.opacity(0.15)

    public static let surfaceElevatedDark = Color(hex: "252430")
    public static let surfaceFloatingDark = Color(hex: "2E2D3A")
}

// MARK: - Adaptive Color Accessors

public extension VCColors {

    /// Returns the correct color for the current color scheme.
    /// Usage: `VCColors.adaptive(.background, scheme: colorScheme)`
    static func adaptive(_ token: VCColorToken, scheme: ColorScheme) -> Color {
        switch (token, scheme) {
        case (.background, .dark):       return backgroundDark
        case (.background, _):           return background
        case (.surface, .dark):          return surfaceDark
        case (.surface, _):              return surface
        case (.surfaceLowest, .dark):    return surfaceLowestDark
        case (.surfaceLowest, _):        return surfaceLowest
        case (.surfaceLow, .dark):       return surfaceLowDark
        case (.surfaceLow, _):           return surfaceLow
        case (.surfaceHigh, .dark):      return surfaceHighDark
        case (.surfaceHigh, _):          return surfaceHigh
        case (.onSurface, .dark):        return onSurfaceDark
        case (.onSurface, _):            return onSurface
        case (.onSurfaceVariant, .dark): return onSurfaceVariantDark
        case (.onSurfaceVariant, _):     return onSurfaceVariant
        case (.outline, .dark):          return outlineDark
        case (.outline, _):              return outline
        case (.glassSurface, .dark):     return glassSurfaceDark
        case (.glassSurface, _):         return glassSurface
        case (.glassBorder, .dark):      return glassBorderDark
        case (.glassBorder, _):          return glassBorder
        }
    }
}

/// Token identifiers for adaptive color lookup.
public enum VCColorToken: Sendable {
    case background, surface, surfaceLowest, surfaceLow, surfaceHigh
    case onSurface, onSurfaceVariant, outline
    case glassSurface, glassBorder
}
