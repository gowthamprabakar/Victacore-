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
}
