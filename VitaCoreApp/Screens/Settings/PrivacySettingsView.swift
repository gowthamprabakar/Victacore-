import SwiftUI
import VitaCoreDesign

// MARK: - Delete Flow State

private enum DeleteStep {
    case idle
    case step1
    case step2
    case step3
}

// MARK: - Main View

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var analyticsEnabled: Bool = false
    @State private var deleteStep: DeleteStep = .idle
    @State private var deleteConfirmText: String = ""
    @State private var showDeleteConfirm1 = false
    @State private var showDeleteConfirm2 = false

    // Mock storage data
    private let totalStorage: String = "1.2 GB"
    private let healthDataStorage: String = "800 MB"
    private let conversationsStorage: String = "200 MB"
    private let cacheStorage: String = "200 MB"

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    header

                    // Data Storage
                    sectionLabel("DATA STORAGE")
                    dataStorageCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Storage Breakdown
                    sectionLabel("STORAGE USAGE")
                    storageBreakdownCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Data Retention
                    sectionLabel("DATA RETENTION")
                    dataRetentionCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Analytics
                    sectionLabel("ANALYTICS & DIAGNOSTICS")
                    analyticsCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Delete section
                    sectionLabel("DANGER ZONE")
                    deleteCard
                        .padding(.horizontal, VCSpacing.xxl)

                    Spacer().frame(height: 40)
                }
                .padding(.top, VCSpacing.xxl)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) { backButton }
        // Step 1 alert
        .alert("Delete All Data?", isPresented: $showDeleteConfirm1) {
            Button("Cancel", role: .cancel) { deleteStep = .idle }
            Button("Continue", role: .destructive) {
                showDeleteConfirm1 = false
                showDeleteConfirm2 = true
            }
        } message: {
            Text("This will permanently erase all your VitaCore data including health readings, conversations, and episodes.")
        }
        // Step 2 alert
        .alert("Are you absolutely sure?", isPresented: $showDeleteConfirm2) {
            Button("Cancel", role: .cancel) { deleteStep = .idle }
            Button("I Understand", role: .destructive) {
                showDeleteConfirm2 = false
                deleteStep = .step3
            }
        } message: {
            Text("This will permanently delete:\n• 4,821 health readings\n• 38 AI conversations\n• 127 tracked episodes\n\nThis action cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer().frame(width: 44 + VCSpacing.lg)
            Text("Privacy")
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

    // MARK: - Data Storage Card

    private var dataStorageCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    Circle()
                        .fill(VCColors.safe.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "iphone.lock")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(VCColors.safe)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("All data stored on-device")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Your health data never leaves your iPhone unless you explicitly export it.")
                        .font(.system(size: 12))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.vertical, VCSpacing.xs)
        }
    }

    // MARK: - Storage Breakdown Card

    private var storageBreakdownCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                storageRow(label: "Total Usage", value: totalStorage, color: VCColors.primary, isTotal: true)
                Divider().background(VCColors.outlineVariant)
                storageRow(label: "Health Data", value: healthDataStorage, color: VCColors.secondary)
                Divider().background(VCColors.outlineVariant)
                storageRow(label: "Conversations", value: conversationsStorage, color: VCColors.tertiary)
                Divider().background(VCColors.outlineVariant)
                storageRow(label: "Cache", value: cacheStorage, color: VCColors.outline)

                // Visual bar
                storageBar
                    .padding(.top, VCSpacing.md)
            }
        }
    }

    private func storageRow(label: String, value: String, color: Color, isTotal: Bool = false) -> some View {
        HStack {
            HStack(spacing: 8) {
                if !isTotal {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.system(size: isTotal ? 15 : 14, weight: isTotal ? .semibold : .regular))
                    .foregroundStyle(isTotal ? VCColors.onSurface : VCColors.onSurfaceVariant)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: isTotal ? .bold : .medium, design: isTotal ? .default : .monospaced))
                .foregroundStyle(isTotal ? VCColors.primary : VCColors.onSurface)
        }
        .padding(.vertical, VCSpacing.sm)
        .frame(minHeight: 44)
    }

    private var storageBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(VCColors.secondary)
                    .frame(width: geo.size.width * 0.67)
                RoundedRectangle(cornerRadius: 2)
                    .fill(VCColors.tertiary)
                    .frame(width: geo.size.width * 0.17)
                RoundedRectangle(cornerRadius: 2)
                    .fill(VCColors.outline.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
        .padding(.bottom, VCSpacing.sm)
    }

    // MARK: - Data Retention Card

    private var dataRetentionCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                retentionRow(
                    icon: "waveform.path.ecg",
                    iconColor: VCColors.secondary,
                    title: "Raw Health Data",
                    policy: "90 days"
                )
                Divider().background(VCColors.outlineVariant)
                retentionRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: VCColors.tertiary,
                    title: "AI Conversations",
                    policy: "180 days"
                )
                Divider().background(VCColors.outlineVariant)
                retentionRow(
                    icon: "doc.text.fill",
                    iconColor: VCColors.primary,
                    title: "Summaries & Reports",
                    policy: "Forever"
                )
            }
        }
    }

    private func retentionRow(icon: String, iconColor: Color, title: String, policy: String) -> some View {
        HStack(spacing: VCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VCColors.onSurface)

            Spacer()

            HStack(spacing: 6) {
                Text(policy)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                Button("Edit") {}
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VCColors.primary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, VCSpacing.xs)
        .frame(minHeight: 44)
    }

    // MARK: - Analytics Card

    private var analyticsCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VCColors.outline.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VCColors.outline)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Analytics & Crash Reports")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Anonymous usage data helps improve the app. Disabled by default.")
                        .font(.system(size: 12))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: $analyticsEnabled)
                    .labelsHidden()
                    .tint(VCColors.primary)
            }
            .padding(.vertical, VCSpacing.sm)
            .frame(minHeight: 44)
        }
    }

    // MARK: - Delete Card

    private var deleteCard: some View {
        VStack(spacing: VCSpacing.md) {
            GlassCard(style: .standard) {
                VStack(alignment: .leading, spacing: VCSpacing.md) {
                    HStack(spacing: VCSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(VCColors.critical.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(VCColors.critical)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete All Data")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VCColors.critical)
                            Text("Permanently erase all VitaCore data from this device")
                                .font(.system(size: 12))
                                .foregroundStyle(VCColors.onSurfaceVariant)
                        }
                        Spacer()
                    }

                    if deleteStep == .step3 {
                        deleteConfirmationStep3
                    }

                    if deleteStep != .step3 {
                        Button {
                            deleteStep = .step1
                            showDeleteConfirm1 = true
                        } label: {
                            Text("Delete All Data")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(VCColors.critical)
                                .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                        }
                    }
                }
                .padding(.vertical, VCSpacing.xs)
            }

            Text("This action is irreversible. All health data, conversations, and episodes will be permanently erased.")
                .font(.system(size: 11))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.md)
        }
    }

    private var deleteConfirmationStep3: some View {
        VStack(alignment: .leading, spacing: VCSpacing.sm) {
            Text("Type DELETE to confirm")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VCColors.critical)

            TextField("Type DELETE", text: $deleteConfirmText)
                .font(.system(size: 15, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            HStack(spacing: VCSpacing.sm) {
                Button("Cancel") {
                    deleteStep = .idle
                    deleteConfirmText = ""
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VCColors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(VCColors.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: VCRadius.sm))

                Button("Permanently Delete") {
                    // Mock — would trigger real delete here
                    deleteStep = .idle
                    deleteConfirmText = ""
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(deleteConfirmText == "DELETE" ? VCColors.critical : VCColors.critical.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: VCRadius.sm))
                .disabled(deleteConfirmText != "DELETE")
            }
        }
        .padding(.top, VCSpacing.xs)
    }
}
