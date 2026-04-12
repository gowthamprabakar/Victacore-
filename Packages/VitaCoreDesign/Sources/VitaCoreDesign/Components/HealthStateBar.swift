// HealthStateBar.swift
// VitaCoreDesign — Top-of-screen health-state status pill

import SwiftUI

// MARK: - HealthStateBar

/// A glass pill displayed near the top of the screen summarising overall health status.
///
/// Features a breathing dot animation and a monospace timestamp.
public struct HealthStateBar: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let statusText: String
    public let statusColor: Color
    /// Human-readable age of the last reading, e.g. "5 min ago".
    public let lastUpdated: String

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(
        statusText: String,
        statusColor: Color = VCColors.safe,
        lastUpdated: String
    ) {
        self.statusText   = statusText
        self.statusColor  = statusColor
        self.lastUpdated  = lastUpdated
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var dotScale: CGFloat = 1.0
    @State private var dotOpacity: Double = 1.0

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        HStack(spacing: VCSpacing.sm) {
            // Breathing status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(dotScale)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(VCAnimation.breathe) {
                        dotScale   = 1.35
                        dotOpacity = 0.55
                    }
                }

            Text(statusText)
                .vcFont(.subhead)
                .foregroundStyle(VCColors.onSurface)
                .lineLimit(1)

            Spacer()

            Text(lastUpdated)
                .vcFont(.mono)
                .foregroundStyle(VCColors.outline)
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.md)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(VCColors.glassBorder, lineWidth: 1)
        )
        .shadow(color: VCColors.glassShadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("HealthStateBar") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        VStack(spacing: VCSpacing.lg) {
            HealthStateBar(
                statusText: "All metrics in safe range",
                statusColor: VCColors.safe,
                lastUpdated: "5 min ago"
            )

            HealthStateBar(
                statusText: "Glucose trending high — watch",
                statusColor: VCColors.watch,
                lastUpdated: "2 min ago"
            )

            HealthStateBar(
                statusText: "Critical: glucose 42 mg/dL",
                statusColor: VCColors.critical,
                lastUpdated: "now"
            )
        }
        .padding(VCSpacing.xl)
    }
}
#endif
