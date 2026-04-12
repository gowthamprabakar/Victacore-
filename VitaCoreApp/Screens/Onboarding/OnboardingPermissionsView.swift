// OnboardingPermissionsView.swift
// VitaCoreApp — OB-07: Permissions onboarding screen

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign

// MARK: - Permission State

private enum PermissionState {
    case idle
    case granted
    case denied
}

// MARK: - OnboardingPermissionsView

struct OnboardingPermissionsView: View {

    // -------------------------------------------------------------------------
    // MARK: External
    // -------------------------------------------------------------------------

    let onNext: () -> Void
    let onBack: () -> Void

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    @Environment(\.personaEngine) private var personaEngine

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    @State private var healthKitState: PermissionState = .idle
    @State private var notificationsState: PermissionState = .idle
    @State private var showHealthKitWarning: Bool = false

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    var body: some View {
        OnboardingContainer(
            step: 7,
            totalSteps: 8,
            title: "Connect Your Data",
            subtitle: "VitaCore needs access to your health data to provide insights.",
            showSkip: false,
            showBack: true,
            onNext: handleContinue,
            onSkip: nil,
            onBack: onBack
        ) {
            VStack(spacing: VCSpacing.xxl) {

                // ── Apple Health card ─────────────────────────────────────────
                PermissionCard(
                    icon: "heart.fill",
                    iconColor: VCColors.critical,
                    title: "Apple Health",
                    description: "Access steps, heart rate, sleep, SpO2, workouts, and more",
                    actionLabel: healthKitState == .idle ? "Connect" : nil,
                    isGranted: healthKitState == .granted
                ) {
                    requestHealthKit()
                }
                .fadeUpEntrance(delay: 0.05)

                // ── Notifications card ────────────────────────────────────────
                PermissionCard(
                    icon: "bell.fill",
                    iconColor: VCColors.primary,
                    title: "Notifications",
                    description: "Receive alerts for critical health events and medication reminders",
                    actionLabel: notificationsState == .idle ? "Enable" : nil,
                    isGranted: notificationsState == .granted
                ) {
                    requestNotifications()
                }
                .fadeUpEntrance(delay: 0.10)

                // ── Health Devices card ───────────────────────────────────────
                HealthDevicesCard()
                    .fadeUpEntrance(delay: 0.15)

                // ── HealthKit warning ─────────────────────────────────────────
                if showHealthKitWarning {
                    GlassCard(style: .small) {
                        HStack(spacing: VCSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(VCColors.watch)
                            VStack(alignment: .leading, spacing: VCSpacing.xs) {
                                Text("Health access not granted")
                                    .vcFont(.headline)
                                    .foregroundStyle(VCColors.onSurface)
                                Text("Some features will be limited. You can grant access later in Settings.")
                                    .vcFont(.caption)
                                    .foregroundStyle(VCColors.onSurfaceVariant)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .fadeUpEntrance(delay: 0)
                }
            }
            .padding(.horizontal, VCSpacing.xxl)
            .padding(.bottom, VCSpacing.xxl)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func requestHealthKit() {
        // Sprint 2.B: HealthKit authorization is triggered from VitaCoreApp.init
        // via HealthKitSkill. The onboarding UI shows the toggle flow; the actual
        // system permission dialog fires on first launch. Tight onboarding ↔ auth
        // coupling comes in a polish sprint.
        withAnimation(VCAnimation.cardEntrance) {
            switch healthKitState {
            case .idle:    healthKitState = .granted; showHealthKitWarning = false
            case .granted: healthKitState = .denied;  showHealthKitWarning = true
            case .denied:  healthKitState = .idle;    showHealthKitWarning = false
            }
        }
    }

    private func requestNotifications() {
        withAnimation(VCAnimation.cardEntrance) {
            switch notificationsState {
            case .idle:    notificationsState = .granted
            case .granted: notificationsState = .denied
            case .denied:  notificationsState = .idle
            }
        }
    }

    private func handleContinue() {
        if healthKitState == .denied {
            withAnimation(VCAnimation.cardEntrance) {
                showHealthKitWarning = true
            }
        }
        onNext()
    }
}

// MARK: - PermissionCard

private struct PermissionCard: View {

    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let actionLabel: String?
    let isGranted: Bool
    let onAction: () -> Void

    var body: some View {
        GlassCard(style: .standard) {
            HStack(alignment: .top, spacing: VCSpacing.lg) {

                // Icon badge
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    HStack {
                        Text(title)
                            .vcFont(.headline)
                            .foregroundStyle(VCColors.onSurface)

                        Spacer()

                        // Status indicator
                        if isGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(VCColors.safe)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(description)
                        .vcFont(.subhead)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)

                    if let label = actionLabel {
                        Button(action: onAction) {
                            Text(label)
                                .vcFont(.headline)
                                .foregroundStyle(.white)
                                .frame(height: VCSpacing.tapTarget)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [VCColors.primary, VCColors.primaryDim],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous))
                        }
                        .padding(.top, VCSpacing.xs)
                    }
                }
            }
        }
        .animation(VCAnimation.cardEntrance, value: isGranted)
    }
}

// MARK: - HealthDevicesCard

private struct HealthDevicesCard: View {

    private let deviceIcons: [(name: String, symbol: String)] = [
        ("CGM",      "waveform.path.ecg"),
        ("BP",       "heart.text.square.fill"),
        ("Fitbit",   "figure.run.circle"),
        ("Oura",     "moon.circle.fill")
    ]

    var body: some View {
        GlassCard(style: .standard) {
            HStack(alignment: .top, spacing: VCSpacing.lg) {

                // Icon badge
                ZStack {
                    Circle()
                        .fill(VCColors.tertiary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sensor.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(VCColors.tertiary)
                }

                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    Text("Health Devices")
                        .vcFont(.headline)
                        .foregroundStyle(VCColors.onSurface)

                    Text("Connect CGM, blood pressure monitors, Fitbit, Whoop, or Oura")
                        .vcFont(.subhead)
                        .foregroundStyle(VCColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)

                    // Device icons row
                    HStack(spacing: VCSpacing.md) {
                        ForEach(deviceIcons, id: \.name) { device in
                            VStack(spacing: VCSpacing.xs) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                                        .fill(VCColors.tertiaryContainer.opacity(0.25))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: device.symbol)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(VCColors.tertiary)
                                }
                                Text(device.name)
                                    .vcFont(.badge)
                                    .foregroundStyle(VCColors.outline)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, VCSpacing.xs)

                    Button("Set Up Later") {}
                        .vcFont(.subhead)
                        .foregroundStyle(VCColors.primary)
                        .frame(height: VCSpacing.tapTarget)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        BackgroundMesh().ignoresSafeArea()
        OnboardingPermissionsView(
            onNext: {},
            onBack: {}
        )
    }
}
#endif
