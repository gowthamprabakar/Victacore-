// WatchBannerView.swift
// VitaCore — WATCH-level top banner (60pt tall, slides in from top).
//
// Design intent: Glass card with subtle amber tint border.
// Auto-dismisses per WatchBannerData.autoDismissSeconds (handled by AlertPresentationManager).
// Slide-in from top transition driven by ContentView overlay stack.

import SwiftUI
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - WatchBannerView

struct WatchBannerView: View {

    let data: WatchBannerData

    @Environment(AlertPresentationManager.self) private var alertManager
    @Environment(TabRouter.self) private var tabRouter

    @State private var didFireHaptic = false

    var body: some View {
        Button {
            // Tap → navigate to Alerts tab
            UISelectionFeedbackGenerator().selectionChanged()
            alertManager.dismissWatch()
            tabRouter.selectedTab = .alerts
        } label: {
            HStack(spacing: VCSpacing.md) {

                // ── Left: icon ────────────────────────────────────────────────
                Image(systemName: data.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VCColors.watch)
                    .frame(width: 28, height: 28)

                // ── Middle: title + subtitle ──────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(VCColors.onSurface)
                        .lineLimit(1)

                    if let subtitle = data.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // ── Right: chevron ────────────────────────────────────────────
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VCColors.outline)
            }
            .padding(.horizontal, VCSpacing.lg)
            .frame(height: 60)
        }
        .buttonStyle(.plain)
        // Glass card styling with amber tint
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                    .fill(VCColors.watch.opacity(0.06))

                RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: VCRadius.lg, style: .continuous)
                .strokeBorder(VCColors.watch.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: VCColors.glassShadow, radius: 12, x: 0, y: 4)
        .onAppear {
            if !didFireHaptic {
                UISelectionFeedbackGenerator().selectionChanged()
                didFireHaptic = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Watch Banner — Glucose") {
    ZStack(alignment: .top) {
        VCColors.background.ignoresSafeArea()

        VStack {
            WatchBannerView(
                data: WatchBannerData(
                    alertId: UUID(),
                    title: "Glucose 195 mg/dL",
                    subtitle: "Above your post-meal watch threshold",
                    iconName: "drop.fill",
                    autoDismissSeconds: 0
                )
            )
            .padding(.horizontal, VCSpacing.lg)
            .padding(.top, VCSpacing.lg)

            Spacer()
        }
    }
    .environment(AlertPresentationManager())
    .environment(TabRouter())
}

#Preview("Watch Banner — Inactivity") {
    ZStack(alignment: .top) {
        VCColors.background.ignoresSafeArea()

        VStack {
            WatchBannerView(
                data: WatchBannerData(
                    alertId: UUID(),
                    title: "95 min inactive after meal",
                    subtitle: "A short walk would help stabilise glucose",
                    iconName: "figure.walk",
                    autoDismissSeconds: 0
                )
            )
            .padding(.horizontal, VCSpacing.lg)
            .padding(.top, VCSpacing.lg)

            Spacer()
        }
    }
    .environment(AlertPresentationManager())
    .environment(TabRouter())
}
#endif
