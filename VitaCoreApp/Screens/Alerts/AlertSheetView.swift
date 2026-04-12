// AlertSheetView.swift
// VitaCore — ALERT-level bottom sheet (.medium detent).
//
// Design intent: Glass morphism with amber accent strip at top.
// BackgroundMesh visible behind. Swipe-down to dismiss (acknowledged).

import SwiftUI
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - AlertSheetView

struct AlertSheetView: View {

    let data: AlertSheetData

    @Environment(AlertPresentationManager.self) private var alertManager
    @Environment(TabRouter.self) private var tabRouter

    @State private var didFireHaptic = false

    var body: some View {
        ZStack {
            // Background mesh blurs through the sheet
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Amber accent strip ────────────────────────────────────────
                Rectangle()
                    .fill(VCColors.alertOrange)
                    .frame(height: 4)
                    .clipShape(
                        .rect(topLeadingRadius: VCRadius.lg, topTrailingRadius: VCRadius.lg)
                    )

                // ── Drag handle ───────────────────────────────────────────────
                Capsule()
                    .fill(VCColors.outlineVariant)
                    .frame(width: 36, height: 4)
                    .padding(.top, VCSpacing.md)
                    .padding(.bottom, VCSpacing.lg)

                // ── Icon + title row ─────────────────────────────────────────
                HStack(alignment: .center, spacing: VCSpacing.md) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(VCColors.alertOrange)
                        .symbolEffect(.pulse, options: .speed(0.6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(VCColors.onSurface)
                            .lineLimit(2)

                        Text(relativeTime(data.triggeredAt))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(VCColors.outline)
                    }

                    Spacer()
                }
                .padding(.horizontal, VCSpacing.xxl)

                // ── Metric summary ─────────────────────────────────────────────
                if let value = data.metricValue {
                    HStack(alignment: .lastTextBaseline, spacing: VCSpacing.xs) {
                        Text(metricValueString(value))
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(VCColors.alertOrange)
                        if let unit = data.metricUnit {
                            Text(unit)
                                .font(.system(.title3, design: .rounded, weight: .medium))
                                .foregroundStyle(VCColors.alertOrange.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.top, VCSpacing.md)
                }

                // ── Body text ─────────────────────────────────────────────────
                Text(data.body)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(VCColors.onSurface)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.top, VCSpacing.lg)

                Spacer()

                // ── Action buttons (side by side) ─────────────────────────────
                HStack(spacing: VCSpacing.md) {
                    // Primary: Open in Chat
                    Button {
                        alertManager.acknowledgeAlert()
                        tabRouter.selectedTab = .chat
                    } label: {
                        Text("Open in Chat")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [VCColors.alertOrange, VCColors.alertOrange.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: VCSpacing.tapTarget)

                    // Secondary: Dismiss
                    Button {
                        alertManager.acknowledgeAlert()
                    } label: {
                        Text("Dismiss")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(VCColors.alertOrange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: VCRadius.md, style: .continuous)
                                    .strokeBorder(VCColors.alertOrange, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: VCSpacing.tapTarget)
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.bottom, VCSpacing.xxxl)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: VCRadius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.xl, style: .continuous)
                        .strokeBorder(VCColors.alertOrange.opacity(0.2), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: VCRadius.xl, style: .continuous))
        .onAppear {
            if !didFireHaptic {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                didFireHaptic = true
            }
        }
    }

    private func metricValueString(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60    { return "just now" }
        if seconds < 3600  { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Alert Sheet — BP Elevated") {
    Color.gray.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            AlertSheetView(
                data: AlertSheetData(
                    alertId: UUID(),
                    title: "Blood Pressure Elevated",
                    body: "Your blood pressure reading of 158/98 mmHg exceeds your alert threshold. Consider resting and re-measuring in 10 minutes.",
                    metricValue: 158,
                    metricUnit: "mmHg"
                )
            )
            .environment(AlertPresentationManager())
            .environment(TabRouter())
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}
#endif
