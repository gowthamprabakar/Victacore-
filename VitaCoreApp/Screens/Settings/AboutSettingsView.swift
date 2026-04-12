import SwiftUI
import VitaCoreDesign

// MARK: - About Settings View

struct AboutSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    header

                    // Logo + wordmark
                    logoSection

                    // App Info
                    sectionLabel("APP INFO")
                    appInfoCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // AI Model
                    sectionLabel("AI MODEL")
                    aiModelCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Architecture
                    sectionLabel("ARCHITECTURE")
                    architectureCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Links
                    sectionLabel("LEGAL & SUPPORT")
                    linksCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Debug (development builds only)
                    #if DEBUG
                    sectionLabel("DEBUG")
                    debugSection
                        .padding(.horizontal, VCSpacing.xxl)
                    #endif

                    // Footer
                    footerSection

                    Spacer().frame(height: 40)
                }
                .padding(.top, VCSpacing.xxl)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) { backButton }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer().frame(width: 44 + VCSpacing.lg)
            Text("About")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, 60)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            ZStack {
                Circle()
                    .fill(VCColors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VCColors.primary)
            }
        }
        .padding(.leading, VCSpacing.lg)
        .padding(.top, 56)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(VCColors.outline)
                .padding(.leading, VCSpacing.md)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, VCSpacing.xs)
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: VCSpacing.md) {
            // Gradient circle logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [VCColors.primary, VCColors.secondary, VCColors.tertiary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: VCColors.primary.opacity(0.3), radius: 16, x: 0, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Wordmark
            Text("VitaCore")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(VCColors.onSurface)

            // Version tag
            Text("v1.0.0")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(VCColors.primary)
                .padding(.horizontal, VCSpacing.md)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(VCColors.primaryContainer.opacity(0.4))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VCSpacing.md)
    }

    // MARK: - App Info Card

    private var appInfoCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                infoRow(label: "Version",  value: "1.0.0")
                Divider().background(VCColors.outlineVariant)
                infoRow(label: "Build",    value: "1")
                Divider().background(VCColors.outlineVariant)
                infoRow(label: "Released", value: "April 2026")
                Divider().background(VCColors.outlineVariant)
                infoRow(label: "Bundle",   value: "com.vitacore.app", mono: true)
            }
        }
    }

    // MARK: - AI Model Card

    private var aiModelCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                // Model header
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VCColors.tertiary.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "brain.filled.head.profile")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VCColors.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("On-Device Language Model")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                        Text("Gemma 4 E4B")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                    }
                    Spacer()
                }
                .padding(.bottom, VCSpacing.sm)

                Divider().background(VCColors.outlineVariant)

                infoRow(label: "Quantization",   value: "INT4")
                Divider().background(VCColors.outlineVariant)
                infoRow(label: "Model Size",     value: "4.8 GB")
                Divider().background(VCColors.outlineVariant)
                infoRow(label: "Last Updated",   value: "April 2026")
            }
        }
    }

    // MARK: - Architecture Card

    private var architectureCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                architectureRow(
                    icon: "iphone.gen3",
                    iconColor: VCColors.safe,
                    text: "On-device intelligence"
                )
                Divider().background(VCColors.outlineVariant)
                architectureRow(
                    icon: "lock.doc.fill",
                    iconColor: VCColors.tertiary,
                    text: "Encrypted graph storage"
                )
                Divider().background(VCColors.outlineVariant)
                architectureRow(
                    icon: "hand.raised.fill",
                    iconColor: VCColors.primary,
                    text: "Privacy-first design"
                )
                Divider().background(VCColors.outlineVariant)
                architectureRow(
                    icon: "cpu",
                    iconColor: VCColors.secondary,
                    text: "A17 Pro Neural Engine"
                )
                Divider().background(VCColors.outlineVariant)
                architectureRow(
                    icon: "memorychip",
                    iconColor: VCColors.watch,
                    text: "8 GB RAM, 5-layer OpenClaw arch"
                )
            }
        }
    }

    private func architectureRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: VCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VCColors.onSurface)
            Spacer()
        }
        .padding(.vertical, VCSpacing.xs)
        .frame(minHeight: 44)
    }

    // MARK: - Links Card

    private var linksCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                linkRow(label: "Privacy Policy",       icon: "hand.raised.fill", iconColor: VCColors.primary)
                Divider().background(VCColors.outlineVariant)
                linkRow(label: "Terms of Service",     icon: "doc.text.fill",    iconColor: VCColors.tertiary)
                Divider().background(VCColors.outlineVariant)
                linkRow(label: "Open Source Licenses", icon: "curlybraces",       iconColor: VCColors.secondary)
                Divider().background(VCColors.outlineVariant)
                linkRow(label: "Acknowledgments",      icon: "heart.fill",        iconColor: VCColors.safe)
                Divider().background(VCColors.outlineVariant)
                linkRow(label: "Support",              icon: "questionmark.circle.fill", iconColor: VCColors.watch)
            }
        }
    }

    private func linkRow(label: String, icon: String, iconColor: Color) -> some View {
        Button {
            // Link action placeholder
        } label: {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VCColors.onSurface)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VCColors.outline)
            }
            .padding(.vertical, VCSpacing.xs)
            .frame(minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Shared Info Row

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: mono ? .monospaced : .default))
                .foregroundStyle(VCColors.onSurface)
        }
        .padding(.vertical, VCSpacing.sm)
        .frame(minHeight: 44)
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        GlassCard(style: .standard) {
            Button {
                UserDefaults.standard.set(false, forKey: "vitacore.hasCompletedOnboarding")
            } label: {
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.orange)
                    }
                    Text("Reset onboarding")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VCColors.onSurface)
                    Spacer()
                }
                .padding(.vertical, VCSpacing.xs)
                .frame(minHeight: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    #endif

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: VCSpacing.sm) {
            Text("Made with care for your health")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)

            Text("© 2026 VitaCore Health")
                .font(.system(size: 13))
                .foregroundStyle(VCColors.outline)

            Text("v1.0.0 (1)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(VCColors.outline.opacity(0.7))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VCSpacing.sm)
    }
}
