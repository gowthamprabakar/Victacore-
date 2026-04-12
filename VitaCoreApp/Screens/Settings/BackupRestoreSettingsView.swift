import SwiftUI
import VitaCoreDesign

// MARK: - Mock Data Model

private struct BackupEntry: Identifiable {
    let id = UUID()
    let date: Date
    let sizeLabel: String
}

private let mockBackups: [BackupEntry] = {
    let cal = Calendar.current
    let now = Date()
    return [
        BackupEntry(date: now,                                              sizeLabel: "1.19 GB"),
        BackupEntry(date: cal.date(byAdding: .day, value: -1, to: now)!,   sizeLabel: "1.17 GB"),
        BackupEntry(date: cal.date(byAdding: .day, value: -3, to: now)!,   sizeLabel: "1.14 GB"),
        BackupEntry(date: cal.date(byAdding: .day, value: -7, to: now)!,   sizeLabel: "1.10 GB"),
        BackupEntry(date: cal.date(byAdding: .day, value: -14, to: now)!,  sizeLabel: "1.02 GB"),
    ]
}()

// MARK: - Main View

struct BackupRestoreSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var iCloudEnabled: Bool = true
    @State private var isBackingUp: Bool = false
    @State private var showRestoreAlert: Bool = false
    @State private var restoreConfirmText: String = ""
    @State private var selectedRestoreEntry: BackupEntry? = nil
    @State private var showRestoreInput: Bool = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    header

                    // iCloud Backup Toggle
                    sectionLabel("ICLOUD BACKUP")
                    iCloudCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Last Backup + Backup Now
                    sectionLabel("CURRENT BACKUP")
                    currentBackupCard
                        .padding(.horizontal, VCSpacing.xxl)

                    // Backup History
                    sectionLabel("BACKUP HISTORY")
                    backupHistorySection

                    // Encryption notice
                    encryptionNotice
                        .padding(.horizontal, VCSpacing.xxl)

                    Spacer().frame(height: 40)
                }
                .padding(.top, VCSpacing.xxl)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) { backButton }
        // Restore confirmation alert
        .alert("Restore from Backup?", isPresented: $showRestoreAlert) {
            Button("Cancel", role: .cancel) {
                selectedRestoreEntry = nil
                showRestoreInput = false
                restoreConfirmText = ""
            }
            Button("Proceed to Confirm", role: .destructive) {
                showRestoreAlert = false
                showRestoreInput = true
            }
        } message: {
            if let entry = selectedRestoreEntry {
                Text("Restoring from \(dateFormatter.string(from: entry.date)) (\(entry.sizeLabel)) will replace all current data. This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer().frame(width: 44 + VCSpacing.lg)
            Text("Backup & Restore")
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

    // MARK: - iCloud Card

    private var iCloudCard: some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VCColors.tertiary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VCColors.tertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("iCloud Backup")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text("Encrypted with your device key")
                        .font(.system(size: 12))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }

                Spacer()

                Toggle("", isOn: $iCloudEnabled)
                    .labelsHidden()
                    .tint(VCColors.primary)
            }
            .padding(.vertical, VCSpacing.sm)
            .frame(minHeight: 44)
        }
    }

    // MARK: - Current Backup Card

    private var currentBackupCard: some View {
        GlassCard(style: .standard) {
            VStack(spacing: 0) {
                // Last backup info
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(VCColors.safe.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(VCColors.safe)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Last Backup")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                        Text(dateFormatter.string(from: mockBackups[0].date))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VCColors.onSurface)
                        Text(mockBackups[0].sizeLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }

                    Spacer()
                }
                .frame(minHeight: 44)

                Divider()
                    .background(VCColors.outlineVariant)
                    .padding(.vertical, VCSpacing.sm)

                // Backup Now button
                Button {
                    Task {
                        isBackingUp = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isBackingUp = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isBackingUp {
                            ProgressView()
                                .scaleEffect(0.85)
                                .tint(.white)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(isBackingUp ? "Backing Up..." : "Backup Now")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [VCColors.primary, VCColors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.md))
                }
                .disabled(isBackingUp || !iCloudEnabled)
                .opacity(!iCloudEnabled ? 0.5 : 1)
            }
        }
    }

    // MARK: - Backup History

    private var backupHistorySection: some View {
        VStack(spacing: VCSpacing.md) {
            ForEach(mockBackups) { entry in
                backupRow(entry: entry)
            }

            if showRestoreInput, let entry = selectedRestoreEntry {
                restoreInputCard(entry: entry)
                    .padding(.horizontal, VCSpacing.xxl)
            }
        }
        .padding(.horizontal, VCSpacing.xxl)
    }

    private func backupRow(entry: BackupEntry) -> some View {
        GlassCard(style: .standard) {
            HStack(spacing: VCSpacing.md) {
                // Date info
                VStack(alignment: .leading, spacing: 3) {
                    Text(dateFormatter.string(from: entry.date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                    Text(entry.sizeLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(VCColors.onSurfaceVariant)
                }

                Spacer()

                // Restore button
                Button {
                    selectedRestoreEntry = entry
                    showRestoreInput = false
                    restoreConfirmText = ""
                    showRestoreAlert = true
                } label: {
                    Text("Restore")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VCColors.primary)
                        .padding(.horizontal, VCSpacing.md)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: VCRadius.sm)
                                .strokeBorder(VCColors.primary.opacity(0.5), lineWidth: 1)
                        )
                }
                .frame(minHeight: 44)

                // Delete (trash) icon
                Button {
                    // Mock delete
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(VCColors.critical.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    // MARK: - Restore Input Card

    private func restoreInputCard(entry: BackupEntry) -> some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(VCColors.alertOrange)
                    Text("Restoring from \(dateFormatter.string(from: entry.date))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                }

                Text("Type RESTORE to confirm")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VCColors.alertOrange)

                TextField("Type RESTORE", text: $restoreConfirmText)
                    .font(.system(size: 15, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                HStack(spacing: VCSpacing.sm) {
                    Button("Cancel") {
                        showRestoreInput = false
                        selectedRestoreEntry = nil
                        restoreConfirmText = ""
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(VCColors.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.sm))

                    Button("Restore from Backup") {
                        // Mock restore
                        showRestoreInput = false
                        selectedRestoreEntry = nil
                        restoreConfirmText = ""
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(restoreConfirmText == "RESTORE" ? VCColors.alertOrange : VCColors.alertOrange.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: VCRadius.sm))
                    .disabled(restoreConfirmText != "RESTORE")
                }
            }
        }
    }

    // MARK: - Encryption Notice

    private var encryptionNotice: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13))
                .foregroundStyle(VCColors.safe)
            Text("AES-256-GCM encrypted, end-to-end protected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VCSpacing.sm)
    }
}
