// AnalysisLoadingView.swift
// VitaCore – Food Photo Analysis Pipeline – Stage 4
// Animated on-device inference loading screen with thinking orb,
// segmented status text, progress bar, and privacy feature pills.

import SwiftUI
import VitaCoreDesign

struct AnalysisLoadingView: View {

    let progress: Double   // 0.0 – 1.0, driven by FoodFlowViewModel
    let statusText: String // e.g. "Detecting food items..."

    // MARK: - Animation state
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerGlowOpacity: Double = 0.4
    @State private var appeared: Bool = false

    private let orbSize: CGFloat = 180

    var body: some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Animated Orb ──
                orbView
                    .padding(.bottom, VCSpacing.xxl)

                // ── Status text ──
                statusSection
                    .padding(.bottom, VCSpacing.xl)

                // ── Progress bar + percentage ──
                progressSection
                    .padding(.bottom, 0)

                Spacer()

                // ── Feature pills row ──
                featurePills
                    .padding(.bottom, VCSpacing.xxxl)
            }
            .padding(.horizontal, VCSpacing.xl)
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Orb

    private var orbView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(VCColors.primary.opacity(outerGlowOpacity))
                .frame(width: orbSize + 60, height: orbSize + 60)
                .blur(radius: 30)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            // Slow rotating outer ring
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(
                    AngularGradient(
                        colors: [
                            VCColors.primary.opacity(0.0),
                            VCColors.primaryContainer.opacity(0.5),
                            VCColors.tertiaryContainer.opacity(0.6),
                            VCColors.primaryContainer.opacity(0.3),
                            VCColors.primary.opacity(0.0)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: orbSize + 30, height: orbSize + 30)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 8).repeatForever(autoreverses: false),
                    value: rotation
                )

            // Second counter-rotating dashed ring
            Circle()
                .trim(from: 0, to: 0.45)
                .stroke(
                    VCColors.tertiaryContainer.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6])
                )
                .frame(width: orbSize + 14, height: orbSize + 14)
                .rotationEffect(.degrees(-rotation * 0.6))
                .animation(
                    .linear(duration: 8).repeatForever(autoreverses: false),
                    value: rotation
                )

            // Middle breathing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [VCColors.primaryContainer.opacity(0.8), VCColors.tertiaryContainer.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: orbSize + 4, height: orbSize + 4)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            // Core gradient sphere
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            VCColors.primary,
                            Color(red: 0.5, green: 0.25, blue: 0.75),
                            VCColors.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .shadow(color: VCColors.primary.opacity(0.5), radius: 20, x: 0, y: 8)

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.28
                    )
                )
                .frame(width: orbSize * 0.5, height: orbSize * 0.35)
                .offset(x: -orbSize * 0.12, y: -orbSize * 0.20)

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.5), radius: 8)
                .scaleEffect(1 + (pulseScale - 1) * 0.5)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: pulseScale
                )
        }
        .frame(width: orbSize + 60, height: orbSize + 60)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: VCSpacing.sm) {
            Text("Analyzing your meal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VCColors.onSurface)
                .multilineTextAlignment(.center)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: statusText)
                .id(statusText) // forces transition on text change
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: VCSpacing.sm) {
            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VCColors.surfaceLow.opacity(0.6))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * progress), height: 4)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(width: 240, height: 4)

            // Percentage + ETA
            HStack(spacing: VCSpacing.xs) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(VCColors.primary)

                Text("·")
                    .foregroundStyle(VCColors.outlineVariant)

                Text("Estimated 3 seconds")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }
            .animation(.easeInOut(duration: 0.3), value: Int(progress * 100))
        }
    }

    // MARK: - Feature Pills

    private var featurePills: some View {
        GlassCard(style: .small) {
            HStack(spacing: 0) {
                FeaturePill(icon: "lock.fill",    label: "On-Device",  color: VCColors.safe)
                pillDivider
                FeaturePill(icon: "cpu",          label: "Gemma 4",    color: VCColors.tertiary)
                pillDivider
                FeaturePill(icon: "shield.fill",  label: "Private",    color: VCColors.primary)
            }
            .padding(.vertical, VCSpacing.md)
        }
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(VCColors.outlineVariant.opacity(0.4))
            .frame(width: 1, height: 28)
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            outerGlowOpacity = 0.65
        }
    }
}

// MARK: - Feature Pill Sub-view

private struct FeaturePill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: VCSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(VCColors.onSurface)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VCSpacing.sm)
    }
}
