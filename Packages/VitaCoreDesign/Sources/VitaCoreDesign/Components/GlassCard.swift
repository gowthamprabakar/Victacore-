// GlassCard.swift
// VitaCoreDesign — Reusable glass-morphism container
// Enterprise polish: layered shadows (contact + ambient + key),
// fixed press gesture (no conflict with tap), gradient border highlight.

import SwiftUI

// MARK: - GlassStyle

/// Visual style variants for `GlassCard`.
public enum GlassStyle {
    /// Standard card — 18 pt radius, 60 % glass fill.
    case standard
    /// Hero / feature card — 22 pt radius, stronger material + hero glow.
    case hero
    /// Enhanced readability card — 75 % glass fill.
    case enhanced
    /// Compact chip / small card — 12 pt radius.
    case small

    var cornerRadius: CGFloat {
        switch self {
        case .standard: return VCRadius.lg   // 18
        case .hero:     return VCRadius.xl   // 22
        case .enhanced: return VCRadius.lg   // 18
        case .small:    return VCRadius.md   // 12
        }
    }

    /// Internal content padding. Hero gets more breathing room.
    var internalPadding: CGFloat {
        switch self {
        case .standard: return VCSpacing.lg  // 16
        case .hero:     return VCSpacing.xl  // 20
        case .enhanced: return VCSpacing.lg  // 16
        case .small:    return VCSpacing.md  // 12
        }
    }

    /// Ambient shadow radius (middle layer of the 3-layer shadow stack).
    var ambientRadius: CGFloat {
        switch self {
        case .standard: return 14
        case .hero:     return 24
        case .enhanced: return 18
        case .small:    return 8
        }
    }

    var ambientY: CGFloat {
        switch self {
        case .standard: return 6
        case .hero:     return 10
        case .enhanced: return 8
        case .small:    return 3
        }
    }

    /// Key light shadow radius (outermost, most atmospheric layer).
    var keyRadius: CGFloat {
        switch self {
        case .standard: return 28
        case .hero:     return 40
        case .enhanced: return 32
        case .small:    return 16
        }
    }

    var keyY: CGFloat {
        switch self {
        case .standard: return 14
        case .hero:     return 20
        case .enhanced: return 16
        case .small:    return 8
        }
    }

    /// Tint overlay opacity for the ethereal primaryContainer hue.
    var tintOpacity: Double {
        switch self {
        case .standard: return 0.08
        case .hero:     return 0.14
        case .enhanced: return 0.10
        case .small:    return 0.06
        }
    }

    /// Whether this style gets an extra brand-colored outer glow.
    var hasHeroGlow: Bool {
        self == .hero
    }
}

// MARK: - GlassCard

/// A reusable glass-morphism card that wraps arbitrary content.
///
/// Usage:
/// ```swift
/// GlassCard(style: .hero) {
///     Text("Hello VitaCore")
/// }
/// ```
public struct GlassCard<Content: View>: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let style: GlassStyle
    public let content: () -> Content

    @State private var isPressed: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(style: GlassStyle = .standard, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.content = content
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        content()
            .padding(style.internalPadding)
            // --- Glass base material ---
            .background(
                ZStack {
                    // Ultra-thin system material (blur + translucency)
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Ethereal primary-container tint overlay (bumped from 0.06 → 0.08+)
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(VCColors.primaryContainer.opacity(style.tintOpacity))

                    // Liquid-glass sheen: 3-stop gradient from top to bottom
                    // (was 2-stop top→center — too short)
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
            // --- Gradient border: crisper white at top, fading at bottom ---
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
            // --- 3-layer shadow stack (contact + ambient + key) ---
            // Layer 1: tight contact shadow (1pt below, sharp)
            .shadow(
                color: VCColors.shadowContact,
                radius: 1,
                x: 0,
                y: 1
            )
            // Layer 2: ambient shadow (soft, neutral)
            .shadow(
                color: VCColors.shadowAmbient,
                radius: style.ambientRadius,
                x: 0,
                y: style.ambientY
            )
            // Layer 3: key light (colored, atmospheric, furthest)
            .shadow(
                color: style.hasHeroGlow ? VCColors.shadowHero : VCColors.shadowKey,
                radius: style.keyRadius,
                x: 0,
                y: style.keyY
            )
            // --- Press scale (subtle, not bouncy) ---
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPressed)
            // --- Fixed press gesture using DragGesture (no conflict with parent tap) ---
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
            // --- Haptic feedback on press ---
            .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: isPressed)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("GlassCard Styles") {
    ZStack {
        BackgroundMesh()

        VStack(spacing: VCSpacing.xxl) {
            GlassCard(style: .hero) {
                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    Text("Hero Card")
                        .vcFont(.title1)
                        .foregroundStyle(VCColors.onSurface)
                    Text("Primary feature surface with extra elevation and brand-colored glow.")
                        .vcFont(.subhead)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(style: .standard) {
                Text("Standard Card")
                    .vcFont(.headline)
                    .foregroundStyle(VCColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: VCSpacing.md) {
                GlassCard(style: .small) {
                    Text("Small")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
                GlassCard(style: .enhanced) {
                    Text("Enhanced")
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
            }
        }
        .padding(VCSpacing.xxl)
    }
}
#endif
