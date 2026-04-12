// OnboardingWelcomeView.swift
// VitaCoreApp — OB-01: Welcome Screen
//
// The first screen users see. Full-bleed BackgroundMesh with a large
// VitaCore wordmark, tagline, and a single Get Started CTA.
// No step counter, no back button, no skip.

import SwiftUI
import VitaCoreDesign

// MARK: - OnboardingWelcomeView

struct OnboardingWelcomeView: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    let onNext: () -> Void

    @State private var logoVisible: Bool = false
    @State private var taglineVisible: Bool = false
    @State private var subtitleVisible: Bool = false
    @State private var buttonVisible: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        ZStack {
            // Full-bleed animated ambient background
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + wordmark cluster
                logoCluster

                Spacer()

                // Tagline + subtitle
                textCluster
                    .padding(.horizontal, VCSpacing.xxl)

                Spacer()

                // Get Started button
                VCPrimaryButton(title: "Get Started", action: {
                    HapticFeedback.medium.trigger()
                    onNext()
                })
                    .padding(.horizontal, VCSpacing.xxl)
                    .opacity(buttonVisible ? 1 : 0)
                    .offset(y: buttonVisible ? 0 : 24)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: buttonVisible)

                Spacer(minLength: VCSpacing.xxxl)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear { animateEntrance() }
    }

    // -------------------------------------------------------------------------
    // MARK: Sub-views
    // -------------------------------------------------------------------------

    /// VitaCore logo mark + wordmark.
    private var logoCluster: some View {
        VStack(spacing: VCSpacing.xl) {
            // App icon stand-in: layered glass circles with primary gradient core
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(VCColors.primaryContainer.opacity(0.30))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                // Glass shell
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 108, height: 108)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.60), Color.white.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: VCColors.glassShadow, radius: 24, x: 0, y: 8)

                // Core gradient orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [VCColors.primaryContainer, VCColors.primary],
                            center: .center,
                            startRadius: 0,
                            endRadius: 38
                        )
                    )
                    .frame(width: 76, height: 76)

                // Heart pulse icon
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: VCColors.primary.opacity(0.5), radius: 6, x: 0, y: 2)
            }
            .opacity(logoVisible ? 1 : 0)
            .scaleEffect(logoVisible ? 1 : 0.7)
            .animation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1), value: logoVisible)

            // Wordmark — stronger, more dramatic primary→secondary gradient
            VStack(spacing: VCSpacing.xs) {
                Text("VitaCore")
                    .font(.system(size: 46, weight: .black, design: .default))
                    .tracking(-0.022 * 46)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                VCColors.primary,
                                VCColors.primaryDim,
                                VCColors.secondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("HEALTH INTELLIGENCE")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .tracking(2.2)
            }
            .opacity(logoVisible ? 1 : 0)
            .offset(y: logoVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: logoVisible)
        }
    }

    /// Tagline + long-form subtitle.
    private var textCluster: some View {
        VStack(spacing: VCSpacing.lg) {
            // Primary tagline
            Text("Your health, understood.")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.02 * 26)
                .foregroundColor(VCColors.onSurface)
                .multilineTextAlignment(.center)
                .opacity(taglineVisible ? 1 : 0)
                .offset(y: taglineVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: taglineVisible)

            // Elevator pitch
            Text("AI-powered health intelligence that lives on your device. Private. Personal. Proactive.")
                .font(.system(size: 16))
                .foregroundColor(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(subtitleVisible ? 1 : 0)
                .offset(y: subtitleVisible ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.72), value: subtitleVisible)

            // Feature pills
            featurePills
                .opacity(subtitleVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.88), value: subtitleVisible)
        }
    }

    /// Small pill badges highlighting key capabilities.
    private var featurePills: some View {
        HStack(spacing: VCSpacing.sm) {
            FeaturePill(icon: "lock.shield", label: "On-Device")
            FeaturePill(icon: "brain.head.profile", label: "AI Powered")
            FeaturePill(icon: "heart.fill", label: "Personalised")
        }
        .padding(.top, VCSpacing.sm)
    }

    // -------------------------------------------------------------------------
    // MARK: Animations
    // -------------------------------------------------------------------------

    private func animateEntrance() {
        logoVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { taglineVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { subtitleVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { buttonVisible = true }
    }
}

// MARK: - FeaturePill

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VCColors.primary)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VCColors.onSurfaceVariant)
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.xs + 2)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(VCColors.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("OB-01 Welcome") {
    OnboardingWelcomeView(onNext: {})
}
#endif
