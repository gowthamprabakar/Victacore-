// OnboardingContainer.swift
// VitaCoreApp — Shared wrapper for all 8 onboarding screens
//
// Provides: progress dots, step counter, back/skip navigation,
// title/subtitle header, and the BackgroundMesh ambient layer.

import SwiftUI
import VitaCoreDesign

// MARK: - OnboardingContainer

/// A full-screen onboarding wrapper that provides the shared chrome
/// (progress indicator, navigation buttons, header text) across all
/// 8 onboarding steps.
public struct OnboardingContainer<Content: View>: View {

    // -------------------------------------------------------------------------
    // MARK: Configuration
    // -------------------------------------------------------------------------

    /// Current step (1-based).
    let step: Int
    /// Total number of steps — always 8 for VitaCore onboarding.
    let totalSteps: Int
    /// Screen title displayed below the progress bar.
    let title: String
    /// Optional subtitle shown beneath the title.
    let subtitle: String?
    /// Whether to show the skip button in the top-right corner.
    let showSkip: Bool
    /// Whether to show the back chevron in the top-left corner.
    let showBack: Bool
    /// Called when the primary Continue / Get Started button is tapped.
    let onNext: () -> Void
    /// Called when the user taps Skip. `nil` hides the button.
    let onSkip: (() -> Void)?
    /// Called when the user taps Back. `nil` hides the button.
    let onBack: (() -> Void)?
    /// The screen-specific content rendered between the header and the safe-area bottom.
    @ViewBuilder let content: () -> Content

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        ZStack {
            // Ambient animated background
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Top navigation bar
                topBar
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.top, VCSpacing.sm)

                // Step progress dots
                progressDots
                    .padding(.top, VCSpacing.md)

                // Title + subtitle header
                headerText
                    .padding(.top, VCSpacing.xxl)
                    .padding(.horizontal, VCSpacing.xxl)

                // Screen-specific content
                content()
                    .padding(.top, VCSpacing.xl)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // -------------------------------------------------------------------------
    // MARK: Sub-views
    // -------------------------------------------------------------------------

    /// Top bar: back button + step counter + skip button.
    private var topBar: some View {
        HStack(spacing: 0) {
            // Back button — left slot
            if showBack {
                backButton
            } else {
                // Invisible placeholder keeps counter centred
                Color.clear.frame(width: VCSpacing.tapTarget, height: VCSpacing.tapTarget)
            }

            Spacer()

            stepCounter

            Spacer()

            // Skip button — right slot
            if showSkip {
                skipButton
            } else {
                Color.clear.frame(width: VCSpacing.tapTarget, height: VCSpacing.tapTarget)
            }
        }
    }

    /// Monospaced "Step X of Y" label.
    private var stepCounter: some View {
        Text("Step \(step) of \(totalSteps)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(VCColors.outline)
            .monospacedDigit()
    }

    /// Eight progress dots, filled up to the current step.
    private var progressDots: some View {
        HStack(spacing: VCSpacing.xs) {
            ForEach(1...totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? VCColors.primary : VCColors.outlineVariant)
                    .frame(width: index == step ? 20 : 8, height: 6)
                    .animation(VCAnimation.valueSpring, value: step)
            }
        }
    }

    /// Back chevron button.
    private var backButton: some View {
        Button {
            onBack?()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VCColors.onSurface)
                .frame(width: VCSpacing.tapTarget, height: VCSpacing.tapTarget)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(VCColors.glassBorder, lineWidth: 1)
                        )
                )
        }
        .pressEffect()
    }

    /// Skip text button.
    private var skipButton: some View {
        Button {
            onSkip?()
        } label: {
            Text("Skip")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(VCColors.outline)
                .frame(minWidth: VCSpacing.tapTarget, minHeight: VCSpacing.tapTarget)
        }
    }

    /// Title + optional subtitle.
    private var headerText: some View {
        VStack(spacing: VCSpacing.sm) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(VCColors.onSurface)
                .multilineTextAlignment(.center)
                .tracking(-0.02 * 28)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - VCPrimaryButton

/// Full-width pill-shaped primary gradient button used across onboarding.
public struct VCPrimaryButton: View {

    let title: String
    let isDisabled: Bool
    let action: () -> Void

    public init(title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isDisabled {
                            RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                                .fill(VCColors.outlineVariant)
                        } else {
                            RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [VCColors.primary, VCColors.primaryDim],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: VCColors.primary.opacity(0.35), radius: 12, x: 0, y: 6)
                        }
                    }
                )
        }
        .disabled(isDisabled)
        .pressEffect()
        .animation(VCAnimation.cardPress, value: isDisabled)
    }
}
