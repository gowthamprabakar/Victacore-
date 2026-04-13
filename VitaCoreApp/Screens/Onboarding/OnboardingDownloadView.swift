// OnboardingDownloadView.swift
// VitaCoreApp — OB-08: AI model download onboarding screen

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - OnboardingDownloadView

struct OnboardingDownloadView: View {

    // -------------------------------------------------------------------------
    // MARK: External
    // -------------------------------------------------------------------------

    /// Called when onboarding is fully complete and the app should launch.
    let onComplete: () -> Void

    /// Sprint 4 O-02: closure that triggers real Gemma model download.
    /// Receives a progress callback (0.0-1.0). Nil = simulated download.
    var onStartDownload: ((@Sendable @escaping (Double) -> Void) async throws -> Void)? = nil

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var progress: Double = 0.0          // 0.0 – 1.0
    @State private var isComplete: Bool = false
    @State private var showCompletionUI: Bool = false
    @State private var orbScale: CGFloat = 1.0
    @State private var orbOpacity: Double = 0.85
    @State private var progressTimer: Timer? = nil

    // Derived display values
    private var progressPercent: Int { Int(progress * 100) }
    private let totalGB: Double = 4.8
    private var downloadedGB: Double { progress * totalGB }
    private var remainingMin: Int { max(0, Int((1.0 - progress) * 5)) }   // rough estimate

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        ZStack {
            // Full-screen background — no nav bar, no tab bar
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                VStack(spacing: VCSpacing.md) {
                    Text("Setting Up Intelligence")
                        .vcFont(.title1)
                        .foregroundStyle(VCColors.onSurface)
                        .multilineTextAlignment(.center)

                    Text(isComplete ? "Your AI model is ready." : "Downloading VitaCore AI model (4.8 GB)")
                        .vcFont(.subhead)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .animation(VCAnimation.cardEntrance, value: isComplete)
                }
                .padding(.top, 60)
                .padding(.horizontal, VCSpacing.xxl)

                Spacer()

                // ── Orb + circular progress ───────────────────────────────────
                ZStack {
                    // Ambient glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(VCColors.primaryContainer.opacity(0.06 - Double(i) * 0.015))
                            .frame(width: 220 + CGFloat(i * 40), height: 220 + CGFloat(i * 40))
                            .scaleEffect(orbScale)
                            .animation(
                                VCAnimation.breathe.delay(Double(i) * 0.3),
                                value: orbScale
                            )
                    }

                    // Circular progress track
                    Circle()
                        .stroke(VCColors.primaryContainer.opacity(0.25), lineWidth: 10)
                        .frame(width: 200, height: 200)

                    // Circular progress fill
                    Circle()
                        .trim(from: 0, to: isComplete ? 1.0 : progress)
                        .stroke(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.primaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(VCAnimation.ringFill, value: progress)

                    // Orb body
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    VCColors.primaryContainer.opacity(0.9),
                                    VCColors.primary.opacity(0.5)
                                ],
                                center: .topLeading,
                                startRadius: 10,
                                endRadius: 90
                            )
                        )
                        .frame(width: 168, height: 168)
                        .scaleEffect(orbScale)
                        .opacity(orbOpacity)
                        .animation(VCAnimation.breathe, value: orbScale)

                    // Center content
                    if showCompletionUI {
                        Image(systemName: "checkmark")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(VCColors.primary)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(progressPercent)%")
                            .vcFont(.hero)
                            .foregroundStyle(VCColors.primary)
                            .contentTransition(.numericText())
                            .animation(VCAnimation.valueSpring, value: progressPercent)
                    }
                }
                .frame(height: 260)

                Spacer(minLength: VCSpacing.xxl)

                // ── Linear progress bar ───────────────────────────────────────
                VStack(spacing: VCSpacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                                .fill(VCColors.primaryContainer.opacity(0.25))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: VCRadius.pill, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [VCColors.primary, VCColors.primaryContainer],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(8, geo.size.width * (isComplete ? 1.0 : progress)),
                                    height: 8
                                )
                                .animation(VCAnimation.ringFill, value: progress)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, VCSpacing.xxl)

                    if !showCompletionUI {
                        Text(String(format: "%.1f GB of %.1f GB · ~%d min remaining",
                                    downloadedGB, totalGB, remainingMin))
                            .vcFont(.caption)
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .contentTransition(.numericText())
                            .animation(VCAnimation.valueSpring, value: progressPercent)
                    }
                }

                Spacer(minLength: VCSpacing.xxl)

                // ── Status cards ──────────────────────────────────────────────
                VStack(spacing: VCSpacing.md) {
                    DownloadStatusCard(
                        icon: "iphone",
                        iconColor: VCColors.primary,
                        title: "On-Device AI",
                        description: "Your health data never leaves your iPhone"
                    )
                    .fadeUpEntrance(delay: 0.1)

                    DownloadStatusCard(
                        icon: "lock.shield.fill",
                        iconColor: VCColors.safe,
                        title: "Private by Design",
                        description: "No cloud processing. Everything runs locally."
                    )
                    .fadeUpEntrance(delay: 0.2)
                }
                .padding(.horizontal, VCSpacing.xxl)

                Spacer(minLength: VCSpacing.xxxl)

                // ── Completion action ─────────────────────────────────────────
                if showCompletionUI {
                    VStack(spacing: VCSpacing.lg) {
                        Text("VitaCore is Ready")
                            .vcFont(.title2)
                            .foregroundStyle(VCColors.onSurface)

                        Button(action: onComplete) {
                            Text("Start Using VitaCore")
                                .vcFont(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: VCSpacing.tapTarget + 4)
                                .background(
                                    LinearGradient(
                                        colors: [VCColors.primary, VCColors.primaryDim],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: VCRadius.xl, style: .continuous))
                        }
                        .padding(.horizontal, VCSpacing.xxl)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear { startDownloadSimulation() }
        .onDisappear { progressTimer?.invalidate() }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }

    // -------------------------------------------------------------------------
    // MARK: Download simulation
    // -------------------------------------------------------------------------

    private func startDownloadSimulation() {
        // Start ambient orb breathing
        orbScale = 1.06

        if let onStartDownload {
            // Sprint 4 O-02: real model download via Gemma4Runtime.load(progress:)
            Task {
                do {
                    try await onStartDownload { fraction in
                        Task { @MainActor in
                            withAnimation { progress = fraction }
                        }
                    }
                    await MainActor.run { finishDownload() }
                } catch {
                    // Download failed — allow skip.
                    await MainActor.run {
                        withAnimation { isComplete = true; showCompletionUI = true }
                    }
                }
            }
        } else {
            // Simulator fallback: simulate download progress over ~8 seconds
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if progress < 1.0 {
                    let increment = Double.random(in: 0.008...0.018)
                    withAnimation {
                        progress = min(1.0, progress + increment)
                    }
                } else {
                    timer.invalidate()
                    finishDownload()
                }
            }
        }
    }

    private func finishDownload() {
        withAnimation(VCAnimation.cardEntrance) {
            isComplete = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(VCAnimation.cardEntrance) {
                showCompletionUI = true
                orbScale = 1.0
                orbOpacity = 1.0
            }
        }
    }
}

// MARK: - DownloadStatusCard

private struct DownloadStatusCard: View {

    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        GlassCard(style: .small) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text(title)
                        .vcFont(.headline)
                        .foregroundStyle(VCColors.onSurface)
                    Text(description)
                        .vcFont(.caption)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(VCColors.safe)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    OnboardingDownloadView(onComplete: {})
}
#endif
