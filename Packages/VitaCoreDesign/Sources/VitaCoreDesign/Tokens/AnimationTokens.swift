// AnimationTokens.swift
// VitaCoreDesign — Motion / animation token library
// Enterprise polish: modern iOS 17+ preset curves, staggered section entrances,
// semantic naming for every motion type used in the app.

import SwiftUI

// MARK: - VCAnimation

/// Pre-defined `Animation` curves and timings for VitaCore.
public enum VCAnimation {

    // -------------------------------------------------------------------------
    // MARK: Modern iOS 17+ Presets (preferred for new code)
    // -------------------------------------------------------------------------

    /// iOS 17 `.smooth` spring — use for most state changes, sheet presentations.
    public static let smooth: Animation = .smooth(duration: 0.45, extraBounce: 0.0)

    /// iOS 17 `.snappy` spring — use for quick interactions, toggles, selections.
    public static let snappy: Animation = .snappy(duration: 0.32, extraBounce: 0.0)

    /// iOS 17 `.bouncy` spring — use for playful entrances, delight moments.
    public static let bouncy: Animation = .bouncy(duration: 0.55, extraBounce: 0.15)

    // -------------------------------------------------------------------------
    // MARK: Entrance & Transitions
    // -------------------------------------------------------------------------

    /// Standard card entrance — spring with minimal bounce, 0.55s.
    public static let cardEntrance: Animation = .spring(response: 0.55, dampingFraction: 0.85)

    /// Hero entrance for onboarding and feature introductions.
    public static let heroEntrance: Animation = .spring(response: 0.7, dampingFraction: 0.78)

    /// Sheet/modal present — slightly dampened spring.
    public static let sheetPresent: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    /// Page transition — smoother for navigation pushes.
    public static let pageTransition: Animation = .smooth(duration: 0.38)

    /// Fade crossfade — use for content swaps without geometry change.
    public static let crossfade: Animation = .easeInOut(duration: 0.25)

    // -------------------------------------------------------------------------
    // MARK: Data Visualisation
    // -------------------------------------------------------------------------

    /// Ring / arc fill — smooth cubic bezier over 1.4 s (material-style ease).
    public static let ringFill: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 1.4)

    /// Animated numeric counter — quick spring settle for `.contentTransition(.numericText())`.
    public static let valueSpring: Animation = .spring(response: 0.4, dampingFraction: 0.78)

    /// Chart line draw — over 0.8 s easeOut.
    public static let chartDraw: Animation = .easeOut(duration: 0.8)

    /// Shimmer sweep for loading skeletons — linear repeating 1.6 s.
    public static let shimmer: Animation = .linear(duration: 1.6).repeatForever(autoreverses: false)

    // -------------------------------------------------------------------------
    // MARK: Ambient / Repeat
    // -------------------------------------------------------------------------

    /// Slow breathing pulse — 2.5 s easeInOut, repeating. Use for status dots, health indicators.
    public static let breathe: Animation = .easeInOut(duration: 2.5)
        .repeatForever(autoreverses: true)

    /// Slower ambient breathe — 3.5s, for large glowing elements.
    public static let ambientBreathe: Animation = .easeInOut(duration: 3.5)
        .repeatForever(autoreverses: true)

    /// Critical-value pulse — 1.2 s easeInOut, repeating.
    public static let criticalPulse: Animation = .easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)

    /// Slow rotation for animated orbs (onboarding welcome, loading states).
    public static let slowRotate: Animation = .linear(duration: 20)
        .repeatForever(autoreverses: false)

    // -------------------------------------------------------------------------
    // MARK: Interaction
    // -------------------------------------------------------------------------

    /// Card press-down response — subtle spring (0.98 scale).
    public static let cardPress: Animation = .spring(response: 0.28, dampingFraction: 0.78)

    /// Button tap — quick pulse.
    public static let buttonTap: Animation = .spring(response: 0.22, dampingFraction: 0.72)

    /// Tab selection — snappy.
    public static let tabSwitch: Animation = .snappy(duration: 0.25, extraBounce: 0.0)

    // -------------------------------------------------------------------------
    // MARK: Stagger Helper
    // -------------------------------------------------------------------------

    /// Returns a delay value suitable for staggered list animations.
    /// - Parameter index: Zero-based item index.
    /// - Returns: Delay in seconds.
    public static func staggerDelay(index: Int, step: Double = 0.06) -> Double {
        step * Double(index)
    }

    /// Staggered section entrance with index-based delay.
    public static func sectionEntrance(index: Int) -> Animation {
        cardEntrance.delay(staggerDelay(index: index, step: 0.07))
    }
}
