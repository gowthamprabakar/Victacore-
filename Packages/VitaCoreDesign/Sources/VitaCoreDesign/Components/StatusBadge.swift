// StatusBadge.swift
// VitaCoreDesign — Clinical health-state pill badge

import SwiftUI

// MARK: - StatusBadge

/// A compact pill badge that communicates a clinical threshold band.
///
/// The `.critical` band adds a repeating scale-pulse for urgency.
public struct StatusBadge: View {

    // -------------------------------------------------------------------------
    // MARK: Band

    public enum Band: String, CaseIterable {
        case safe
        case watch
        case alert
        case critical

        var backgroundColor: Color {
            switch self {
            case .safe:     return VCColors.safeDim
            case .watch:    return VCColors.watchDim
            case .alert:    return VCColors.alertOrange.opacity(0.15)
            case .critical: return VCColors.criticalDim
            }
        }

        var foregroundColor: Color {
            switch self {
            case .safe:     return VCColors.safe
            case .watch:    return VCColors.watch
            case .alert:    return VCColors.alertOrange
            case .critical: return VCColors.critical
            }
        }

        var defaultLabel: String {
            switch self {
            case .safe:     return "Safe"
            case .watch:    return "Watch"
            case .alert:    return "Alert"
            case .critical: return "Critical"
            }
        }

        var icon: String {
            switch self {
            case .safe:     return "checkmark.circle.fill"
            case .watch:    return "exclamationmark.circle.fill"
            case .alert:    return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    public let band: Band
    /// Optional label override. Defaults to the band's canonical name.
    public let text: String?

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(band: Band, text: String? = nil) {
        self.band = band
        self.text = text
    }

    // -------------------------------------------------------------------------
    // MARK: Private state
    // -------------------------------------------------------------------------

    @State private var pulseScale: CGFloat = 1.0

    private var displayText: String {
        text ?? band.defaultLabel
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    public var body: some View {
        HStack(spacing: VCSpacing.xs) {
            Image(systemName: band.icon)
                .font(.system(size: 10, weight: .bold))

            Text(displayText)
                .vcFont(.badge)
                .textCase(.uppercase)
        }
        .foregroundStyle(band.foregroundColor)
        .padding(.horizontal, VCSpacing.sm)
        .padding(.vertical, VCSpacing.xs)
        .background(band.backgroundColor, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(band.foregroundColor.opacity(0.3), lineWidth: 0.5)
        )
        .scaleEffect(pulseScale)
        .onAppear {
            guard band == .critical else { return }
            withAnimation(VCAnimation.criticalPulse) {
                pulseScale = 1.04
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("StatusBadge") {
    ZStack {
        VCColors.background.ignoresSafeArea()
        VStack(spacing: VCSpacing.lg) {
            ForEach(StatusBadge.Band.allCases, id: \.self) { band in
                StatusBadge(band: band)
            }
            StatusBadge(band: .safe, text: "In Range")
            StatusBadge(band: .critical, text: "Hypoglycaemia")
        }
        .padding()
    }
}
#endif
