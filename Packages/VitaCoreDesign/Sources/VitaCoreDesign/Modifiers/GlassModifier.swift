// GlassModifier.swift
// VitaCoreDesign — .glassCard() view modifier
// Matches GlassCard.swift with 3-layer shadows and gradient border.

import SwiftUI

// Note: GlassStyle is defined in Components/GlassCard.swift and is public,
// so it is available here without re-declaration.

// MARK: - GlassCardModifier

/// Internal `ViewModifier` that backs the `.glassCard()` extension.
public struct GlassCardModifier: ViewModifier {

    public let style: GlassStyle

    public func body(content: Content) -> some View {
        content
            .padding(style.internalPadding)
            .background(
                ZStack {
                    // System blur material
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Ethereal primary-container tint
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(VCColors.primaryContainer.opacity(style.tintOpacity))

                    // 3-stop liquid-glass sheen
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.28), location: 0.0),
                                    .init(color: Color.white.opacity(0.08), location: 0.35),
                                    .init(color: Color.clear,              location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            // Gradient border
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                VCColors.glassBorder,
                                VCColors.glassBorder.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // 3-layer shadows matching GlassCard.swift
            .shadow(color: VCColors.shadowContact, radius: 1, x: 0, y: 1)
            .shadow(color: VCColors.shadowAmbient, radius: style.ambientRadius, x: 0, y: style.ambientY)
            .shadow(
                color: style.hasHeroGlow ? VCColors.shadowHero : VCColors.shadowKey,
                radius: style.keyRadius,
                x: 0,
                y: style.keyY
            )
    }
}

// MARK: - View extension

public extension View {
    /// Wraps the view in a glass-morphism card with the specified style.
    ///
    /// ```swift
    /// VStack { ... }
    ///     .glassCard(style: .hero)
    /// ```
    func glassCard(style: GlassStyle = .standard) -> some View {
        modifier(GlassCardModifier(style: style))
    }
}
