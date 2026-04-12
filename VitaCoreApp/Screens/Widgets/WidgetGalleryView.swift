// WidgetGalleryView.swift
// VitaCore — Widget Gallery (in-app design reference screen)
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass

import SwiftUI
import VitaCoreDesign

// MARK: - WidgetGalleryView

/// Full-screen gallery showing all widget previews on their simulated
/// backgrounds. Accessible from Settings or the Debug menu during design
/// review; this screen will be removed / replaced once widgets ship in a
/// dedicated WidgetExtension target.
struct WidgetGalleryView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: Body

    var body: some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    lockScreenSection
                    mediumWidgetSection
                    largeWidgetSection
                    comingSoonSection
                }
                .padding(.horizontal, VCSpacing.md)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, VCSpacing.xl)
            }
        }
        .navigationTitle("Widget Gallery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(VCColors.primary)
                }
            }
        }
    }

    // MARK: - Section: Lock Screen

    private var lockScreenSection: some View {
        GallerySection(title: "Lock Screen", subtitle: "accessoryRectangular · 90 × 90 pt") {
            ZStack {
                // Simulated lock screen wallpaper
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.6),
                                Color.purple.opacity(0.4),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.lg))

                VStack(spacing: 20) {
                    // Simulated clock
                    VStack(spacing: 2) {
                        Text("9:41")
                            .font(.system(size: 52, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Thursday, April 10")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    // Widget row (three states side-by-side for comparison)
                    HStack(spacing: 12) {
                        LockScreenWidgetView(glucoseValue: 142, trend: .stable)
                        LockScreenWidgetView(glucoseValue: 185, trend: .rising)
                        LockScreenWidgetView(glucoseValue: 65,  trend: .fallingFast)
                    }
                }
            }
        }
    }

    // MARK: - Section: Home Screen Medium

    private var mediumWidgetSection: some View {
        GallerySection(title: "Home Screen — Medium", subtitle: "systemMedium · 340 × 160 pt") {
            ZStack {
                // Simulated home screen wallpaper
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.28, blue: 0.72),
                                Color(red: 0.22, green: 0.46, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.lg))

                MediumWidgetView()
                    .padding(.vertical, VCSpacing.lg)
            }
        }
    }

    // MARK: - Section: Home Screen Large

    private var largeWidgetSection: some View {
        GallerySection(title: "Home Screen — Large", subtitle: "systemLarge · 340 × 340 pt") {
            ZStack {
                // Simulated home screen wallpaper
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.34, blue: 0.56),
                                Color(red: 0.38, green: 0.22, blue: 0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.lg))

                LargeWidgetView()
                    .padding(.vertical, VCSpacing.lg)
            }
        }
    }

    // MARK: - Section: Coming Soon

    private var comingSoonSection: some View {
        GallerySection(title: "Available Soon", subtitle: "Apple Watch complications + StandBy") {
            VStack(spacing: 12) {
                ComingSoonCard(
                    icon: "applewatch",
                    title: "Watch Complication",
                    description: "Glucose + trend on Watch face",
                    color: VCColors.tertiary
                )
                ComingSoonCard(
                    icon: "applewatch.watchface",
                    title: "Watch Corner",
                    description: "Corner gauge for glucose band",
                    color: VCColors.primary
                )
                ComingSoonCard(
                    icon: "iphone.landscape",
                    title: "StandBy Widget",
                    description: "Full-screen StandBy glanceable",
                    color: VCColors.secondary
                )
            }
        }
    }
}

// MARK: - GallerySection

/// Reusable titled section wrapper used in WidgetGalleryView.
private struct GallerySection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VCColors.onSurface)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(VCColors.onSurfaceVariant)
            }

            content()
        }
    }
}

// MARK: - ComingSoonCard

private struct ComingSoonCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }

                Spacer()

                Text("Soon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.12))
                    )
            }
            .padding(VCSpacing.md)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Widget Gallery") {
    NavigationStack {
        WidgetGalleryView()
    }
}
#endif
