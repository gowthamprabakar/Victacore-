// AnimationModifiers.swift
// VitaCoreDesign — Reusable animation view modifiers

import SwiftUI

// MARK: - FadeUpEntranceModifier

/// Slides content up from a slight offset while fading in.
/// Use with an optional stagger delay for list items.
public struct FadeUpEntranceModifier: ViewModifier {
    public let delay: Double

    @State private var visible: Bool = false

    public func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                withAnimation(VCAnimation.cardEntrance.delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - PulseAnimationModifier

/// Applies the critical-pulse scale animation — intended for values in a
/// dangerous threshold band.
public struct PulseAnimationModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(VCAnimation.criticalPulse) {
                    scale = 1.04
                }
            }
    }
}

// MARK: - PressEffectModifier

/// Scales the view down to 0.97 while a long-press gesture is active.
public struct PressEffectModifier: ViewModifier {
    @State private var isPressed: Bool = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(VCAnimation.cardPress, value: isPressed)
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}

// MARK: - View extensions

public extension View {

    /// Animates the view into the screen with a fade + upward slide.
    /// - Parameter delay: Optional stagger delay in seconds (use `VCAnimation.staggerDelay(index:)`).
    func fadeUpEntrance(delay: Double = 0) -> some View {
        modifier(FadeUpEntranceModifier(delay: delay))
    }

    /// Applies a repeating scale pulse — use on values in a critical state.
    func pulseAnimation() -> some View {
        modifier(PulseAnimationModifier())
    }

    /// Scales the view to 0.97 on long-press, restoring on release.
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }
}
