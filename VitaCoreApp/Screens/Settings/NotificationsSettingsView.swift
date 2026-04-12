import SwiftUI
import VitaCoreDesign

// MARK: - Sound / Vibration Enums

enum NotificationSound: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case soft      = "Soft"
    case urgent    = "Urgent"
    case none      = "None"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .default: return "speaker.wave.2"
        case .soft:    return "speaker.wave.1"
        case .urgent:  return "speaker.wave.3"
        case .none:    return "speaker.slash"
        }
    }
}

enum NotificationVibration: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case subtle    = "Subtle"
    case strong    = "Strong"
    case none      = "None"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .default: return "iphone.radiowaves.left.and.right"
        case .subtle:  return "iphone"
        case .strong:  return "iphone.badge.play"
        case .none:    return "iphone.slash"
        }
    }
}

// MARK: - Main View

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // All preferences are local @State (mock — no persistence yet)
    @State private var backgroundAlertsEnabled: Bool = true
    @State private var quietHoursEnabled: Bool = false
    @State private var quietStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var criticalOverrideEnabled: Bool = true
    @State private var alertPreviewEnabled: Bool = true
    @State private var selectedSound: NotificationSound = .default
    @State private var selectedVibration: NotificationVibration = .default

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    // Header
                    header

                    // Background Alerts
                    sectionLabel("BACKGROUND ALERTS")
                    GlassCard(style: .standard) {
                        toggleRow(
                            icon: "bell.badge.fill",
                            iconColor: VCColors.watch,
                            title: "Background Alerts",
                            description: "Receive critical health alerts when the app is in the background",
                            isOn: $backgroundAlertsEnabled
                        )
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    // Quiet Hours
                    sectionLabel("QUIET HOURS")
                    GlassCard(style: .standard) {
                        VStack(spacing: 0) {
                            toggleRow(
                                icon: "moon.fill",
                                iconColor: VCColors.primary,
                                title: "Quiet Hours",
                                description: "Suppress non-critical alerts during specified hours",
                                isOn: $quietHoursEnabled
                            )

                            if quietHoursEnabled {
                                Divider()
                                    .background(VCColors.outlineVariant)
                                    .padding(.vertical, VCSpacing.xs)

                                VStack(spacing: VCSpacing.sm) {
                                    timePickerRow(label: "Start Time", selection: $quietStart)
                                    Divider().background(VCColors.outlineVariant)
                                    timePickerRow(label: "End Time", selection: $quietEnd)
                                }
                                .padding(.vertical, VCSpacing.xs)
                                .animation(.easeInOut, value: quietHoursEnabled)
                            }
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .animation(.easeInOut, value: quietHoursEnabled)

                    // Critical Override
                    sectionLabel("CRITICAL ALERTS")
                    GlassCard(style: .standard) {
                        toggleRow(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: VCColors.alertOrange,
                            title: "Critical Override",
                            description: "Critical alerts (hypoglycemia, BP crisis) bypass quiet hours and Do Not Disturb",
                            isOn: $criticalOverrideEnabled
                        )
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    // Alert Preview
                    sectionLabel("DISPLAY")
                    GlassCard(style: .standard) {
                        toggleRow(
                            icon: "eye.fill",
                            iconColor: VCColors.tertiary,
                            title: "Alert Preview",
                            description: "Show alert content in notifications (vs. just the title)",
                            isOn: $alertPreviewEnabled
                        )
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    // Sound
                    sectionLabel("SOUND & HAPTICS")
                    GlassCard(style: .standard) {
                        VStack(spacing: 0) {
                            pickerSection(
                                icon: "speaker.wave.2.fill",
                                iconColor: VCColors.secondary,
                                title: "Sound",
                                options: NotificationSound.allCases,
                                selectedOption: $selectedSound
                            )

                            Divider()
                                .background(VCColors.outlineVariant)
                                .padding(.vertical, VCSpacing.xs)

                            pickerSection(
                                icon: "iphone.radiowaves.left.and.right",
                                iconColor: VCColors.primary,
                                title: "Vibration",
                                options: NotificationVibration.allCases,
                                selectedOption: $selectedVibration
                            )
                        }
                    }
                    .padding(.horizontal, VCSpacing.xxl)

                    // Preview Card
                    sectionLabel("PREVIEW")
                    alertPreviewCard
                        .padding(.horizontal, VCSpacing.xxl)

                    Spacer().frame(height: 40)
                }
                .padding(.top, VCSpacing.xxl)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer().frame(width: 44 + VCSpacing.lg)
            Text("Notifications")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VCColors.onSurface)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, 60)
    }

    // MARK: - Back Button

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

    // MARK: - Section Label

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

    // MARK: - Toggle Row

    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: VCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VCColors.onSurface)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(VCColors.primary)
        }
        .padding(.vertical, VCSpacing.sm)
        .frame(minHeight: 44)
    }

    // MARK: - Time Picker Row

    private func timePickerRow(label: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VCColors.onSurface)
            Spacer()
            DatePicker(
                "",
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(VCColors.primary)
        }
        .padding(.horizontal, VCSpacing.lg)
        .frame(minHeight: 44)
    }

    // MARK: - Picker Section

    private func pickerSection<T: CaseIterable & Identifiable & RawRepresentable & Hashable>(
        icon: String,
        iconColor: Color,
        title: String,
        options: [T],
        selectedOption: Binding<T>
    ) -> some View where T.RawValue == String, T.AllCases == [T] {
        HStack(spacing: VCSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VCColors.onSurface)

            Spacer()

            Picker(title, selection: selectedOption) {
                ForEach(options) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(VCColors.primary)
        }
        .padding(.vertical, VCSpacing.sm)
        .frame(minHeight: 44)
    }

    // MARK: - Alert Preview Card

    private var alertPreviewCard: some View {
        GlassCard(style: .enhanced) {
            VStack(alignment: .leading, spacing: VCSpacing.md) {
                // Mock notification banner
                HStack(spacing: VCSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(VCColors.alertOrange)
                            .frame(width: 40, height: 40)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("VitaCore")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("now")
                            .font(.system(size: 11))
                            .foregroundStyle(VCColors.outline)
                    }

                    Spacer()
                }

                if alertPreviewEnabled {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("⚠️ Blood Glucose Alert")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VCColors.onSurface)
                        Text("Your glucose reading of 58 mg/dL is below your low threshold. Tap to review.")
                            .font(.system(size: 13))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }
                } else {
                    Text("VitaCore Health Alert")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                }

                HStack(spacing: VCSpacing.sm) {
                    Text("Sound: \(selectedSound.rawValue)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VCColors.outline)
                    Text("·")
                        .foregroundStyle(VCColors.outline)
                    Text("Vibration: \(selectedVibration.rawValue)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VCColors.outline)
                }
            }
            .padding(VCSpacing.sm)
        }
    }
}
