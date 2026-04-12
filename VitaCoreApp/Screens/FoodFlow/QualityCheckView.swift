// QualityCheckView.swift
// VitaCore – Food Photo Analysis Pipeline – Stage 2
// Shown when image quality metrics fall below acceptable thresholds.
// Gives the user the option to retake or proceed with reduced confidence.

import SwiftUI
import UIKit
import VitaCoreContracts
import VitaCoreDesign

struct QualityCheckView: View {

    let image: UIImage?
    let report: ImageQualityReport
    let onRetake: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // ── Blurred, dimmed captured image as background ──
            backgroundLayer

            // ── BackgroundMesh on top to blend with design system ──
            BackgroundMesh()
                .ignoresSafeArea()
                .opacity(0.55)

            // ── Centred card ──
            ScrollView(showsIndicators: false) {
                VStack {
                    Spacer(minLength: 80)
                    qualityCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, VCSpacing.xl)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 24)
                    .overlay(Color.black.opacity(0.50))
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }

    // MARK: - Quality Card

    private var qualityCard: some View {
        GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: VCSpacing.xxl) {

                // Header
                VStack(alignment: .center, spacing: VCSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(VCColors.watch)
                        .symbolEffect(.pulse)

                    Text("Image Quality Warning")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(VCColors.onSurface)
                        .multilineTextAlignment(.center)

                    Text("We detected some issues with your photo.\nAnalysis may be less accurate.")
                        .font(.subheadline)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                // User-readable issues list (if any supplied by the report)
                if !report.issues.isEmpty {
                    issuesList
                }

                // Score meters
                VStack(spacing: VCSpacing.lg) {
                    ScoreMeter(
                        label: "Lighting",
                        icon: "sun.max.fill",
                        score: report.brightnessScore,
                        qualityLabel: brightnessLabel(report.brightnessScore)
                    )
                    ScoreMeter(
                        label: "Sharpness",
                        icon: "camera.aperture",
                        score: report.sharpnessScore,
                        qualityLabel: sharpnessLabel(report.sharpnessScore)
                    )
                    ScoreMeter(
                        label: "Visibility",
                        icon: "eye.fill",
                        score: report.occlusionScore,
                        qualityLabel: occlusionLabel(report.occlusionScore)
                    )
                }

                // Overall score badge
                overallScoreBadge

                // Action buttons
                VStack(spacing: VCSpacing.md) {
                    // Primary: retake
                    Button(action: onRetake) {
                        Label("Retake Photo", systemImage: "camera.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: VCRadius.pill)
                            )
                            .foregroundStyle(.white)
                    }

                    // Secondary: continue anyway
                    Button(action: onContinue) {
                        Label("Analyze Anyway", systemImage: "wand.and.stars")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: VCRadius.pill)
                                    .stroke(VCColors.tertiary, lineWidth: 1.5)
                            )
                            .foregroundStyle(VCColors.tertiary)
                    }
                }
            }
            .padding(VCSpacing.xxl)
        }
    }

    // MARK: - Issues List

    private var issuesList: some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            ForEach(report.issues, id: \.self) { issue in
                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(VCColors.alertOrange)
                    Text(issue)
                        .font(.footnote)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }
            }
        }
        .padding(VCSpacing.md)
        .background(VCColors.alertOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: VCRadius.md))
    }

    // MARK: - Overall Score Badge

    private var overallScoreBadge: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(scoreColor(report.overallScore))

            Text("Overall Quality Score")
                .font(.caption.weight(.medium))
                .foregroundStyle(VCColors.onSurfaceVariant)

            Spacer()

            Text("\(Int(report.overallScore * 100))%")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(scoreColor(report.overallScore))
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.sm)
        .background(scoreColor(report.overallScore).opacity(0.10), in: RoundedRectangle(cornerRadius: VCRadius.md))
    }

    // MARK: - Label Helpers

    private func brightnessLabel(_ score: Float) -> String {
        switch score {
        case 0.7...: return "Good lighting"
        case 0.4..<0.7: return "Dim lighting"
        default: return "Too dark"
        }
    }

    private func sharpnessLabel(_ score: Float) -> String {
        switch score {
        case 0.75...: return "Sharp"
        case 0.5..<0.75: return "Slightly blurry"
        default: return "Very blurry"
        }
    }

    private func occlusionLabel(_ score: Float) -> String {
        switch score {
        case 0.7...: return "Clear view"
        case 0.4..<0.7: return "Partially obscured"
        default: return "Heavily obscured"
        }
    }

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 0.7...: return VCColors.safe
        case 0.4..<0.7: return VCColors.watch
        default: return VCColors.alertOrange
        }
    }
}

// MARK: - Score Meter Row

private struct ScoreMeter: View {
    let label: String
    let icon: String
    let score: Float
    let qualityLabel: String

    private var barColor: Color {
        switch score {
        case 0.7...: return VCColors.safe
        case 0.4..<0.7: return VCColors.watch
        default: return VCColors.alertOrange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VCSpacing.xs) {
            HStack(spacing: VCSpacing.sm) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(barColor)
                    .frame(width: 16)

                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VCColors.onSurface)

                Spacer()

                Text(qualityLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(barColor)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VCColors.outline.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.75), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(score), height: 6)
                        .animation(.easeOut(duration: 0.6), value: score)
                }
            }
            .frame(height: 6)
        }
    }
}
