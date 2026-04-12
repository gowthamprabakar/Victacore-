// ChatComponents.swift
// VitaCore — Chat Screen Reusable Sub-Views
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Architecture: 5-layer OpenClaw | Sprint Phase 2

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts

// MARK: - UserMessageBubble

struct UserMessageBubble: View {
    let turn: ConversationTurn

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 4) {
                Text(turn.content)
                    .font(.system(size: 15))
                    .foregroundColor(VCColors.onSurface)
                    .lineSpacing(3)
                    .padding(.horizontal, VCSpacing.lg)
                    .padding(.vertical, VCSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VCColors.primaryContainer,
                                        VCColors.primaryContainer.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(VCColors.primary.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: 280, alignment: .trailing)

                Text(turn.timestamp, style: .time)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(VCColors.outline.opacity(0.7))
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, VCSpacing.lg)
    }
}

// MARK: - AssistantMessageBubble

struct AssistantMessageBubble: View {
    let turn: ConversationTurn
    let evidenceExpanded: Bool
    let onToggleEvidence: () -> Void
    let onAction: (ActionType) -> Void

    private let evidenceLines = [
        "CGM reading · 2 min ago",
        "ResponseProfile (n=147) · 94% confidence",
        "Last meal log · 2h 14m ago"
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: VCSpacing.sm) {
            // VitaCore logo avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VCColors.primary, VCColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .semibold))
                )
                .shadow(color: VCColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: VCSpacing.sm) {
                // Message bubble
                GlassCard(style: .small) {
                    Text(turn.content)
                        .font(.system(size: 15))
                        .foregroundColor(VCColors.onSurface)
                        .lineSpacing(3)
                        .frame(maxWidth: 280, alignment: .leading)
                }

                // Timestamp
                Text(turn.timestamp, style: .time)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(VCColors.outline.opacity(0.7))
                    .padding(.leading, 4)

                // Action buttons
                if !turn.actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VCSpacing.sm) {
                            ForEach(Array(turn.actions.enumerated()), id: \.offset) { index, action in
                                ChatActionButton(
                                    action: action,
                                    isPrimary: index == 0,
                                    onTap: { onAction(action) }
                                )
                            }
                        }
                    }
                }

                // Evidence disclosure
                EvidenceToggleButton(
                    isExpanded: evidenceExpanded,
                    onToggle: onToggleEvidence
                )

                if evidenceExpanded {
                    EvidenceDisclosureView(evidence: evidenceLines)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, VCSpacing.lg)
    }
}

// MARK: - SystemMessageView

struct SystemMessageView: View {
    let turn: ConversationTurn

    var body: some View {
        HStack {
            Spacer()
            Text(turn.content)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(VCColors.outline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VCSpacing.xxl)
            Spacer()
        }
        .padding(.vertical, VCSpacing.xs)
    }
}

// MARK: - StreamingBubble

struct StreamingBubble: View {
    let content: String
    @State private var cursorVisible: Bool = true

    var body: some View {
        HStack(alignment: .bottom, spacing: VCSpacing.sm) {
            // VitaCore logo avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VCColors.primary, VCColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .semibold))
                )
                .shadow(color: VCColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)

            GlassCard(style: .small) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(content.isEmpty ? " " : content)
                        .font(.system(size: 15))
                        .foregroundColor(VCColors.onSurface)
                        .lineSpacing(3)

                    Text("▌")
                        .font(.system(size: 15))
                        .foregroundColor(VCColors.primary)
                        .opacity(cursorVisible ? 1.0 : 0.0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                            value: cursorVisible
                        )
                }
                .frame(maxWidth: 280, alignment: .leading)
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, VCSpacing.lg)
        .onAppear {
            cursorVisible = false
        }
    }
}

// MARK: - ChatActionButton

struct ChatActionButton: View {
    let action: ActionType
    let isPrimary: Bool
    let onTap: () -> Void

    var label: String {
        switch action {
        case .logActivity:      return "Log activity"
        case .logFluid:         return "Log fluid"
        case .remindLater:      return "Remind me"
        case .dismiss:          return "Dismiss"
        case .contactClinician: return "Contact doctor"
        case .emergencyCall:    return "Call 911"
        }
    }

    var icon: String {
        switch action {
        case .logActivity:      return "figure.walk"
        case .logFluid:         return "drop.fill"
        case .remindLater:      return "bell.fill"
        case .dismiss:          return "xmark"
        case .contactClinician: return "phone.fill"
        case .emergencyCall:    return "phone.badge.waveform"
        }
    }

    var accentColor: Color {
        switch action {
        case .emergencyCall:    return VCColors.critical
        case .contactClinician: return VCColors.alertOrange
        default:                return VCColors.primary
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isPrimary ? .white : accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        isPrimary
                            ? LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isPrimary ? Color.clear : accentColor.opacity(0.6),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Capsule())
    }
}

// MARK: - EvidenceToggleButton

struct EvidenceToggleButton: View {
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(isExpanded ? "Hide evidence" : "See evidence")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(VCColors.onSurfaceVariant.opacity(0.7))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 24)
        .padding(.leading, 4)
    }
}

// MARK: - EvidenceDisclosureView

struct EvidenceDisclosureView: View {
    let evidence: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: VCSpacing.xs) {
            Text("Data sources")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(VCColors.outline)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(evidence, id: \.self) { line in
                HStack(spacing: VCSpacing.xs) {
                    Circle()
                        .fill(VCColors.tertiary.opacity(0.5))
                        .frame(width: 4, height: 4)
                    Text(line)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }
            }
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                .fill(VCColors.surfaceLow.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                        .strokeBorder(VCColors.outlineVariant.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.leading, 4)
    }
}

// MARK: - HealthContextPill

struct HealthContextPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(VCColors.onSurface)
                Text(unit)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(VCColors.outline)
            }
        }
    }
}

// MARK: - LoadingSkeletonView

struct ChatLoadingSkeletonView: View {
    @State private var shimmer: Bool = false

    var body: some View {
        VStack(spacing: VCSpacing.lg) {
            // Assistant skeleton
            HStack(alignment: .bottom, spacing: VCSpacing.sm) {
                Circle()
                    .fill(VCColors.surfaceLow)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    skeletonLine(width: 220, height: 14)
                    skeletonLine(width: 160, height: 14)
                    skeletonLine(width: 100, height: 14)
                }
                Spacer()
            }

            // User skeleton
            HStack {
                Spacer()
                skeletonLine(width: 140, height: 14)
            }

            // Assistant skeleton
            HStack(alignment: .bottom, spacing: VCSpacing.sm) {
                Circle()
                    .fill(VCColors.surfaceLow)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: VCSpacing.sm) {
                    skeletonLine(width: 260, height: 14)
                    skeletonLine(width: 200, height: 14)
                }
                Spacer()
            }
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.top, VCSpacing.xl)
        .onAppear { shimmer = true }
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: VCRadius.sm)
            .fill(
                LinearGradient(
                    colors: [
                        VCColors.outlineVariant.opacity(0.4),
                        VCColors.outlineVariant.opacity(0.15),
                        VCColors.outlineVariant.opacity(0.4)
                    ],
                    startPoint: shimmer ? .leading : .trailing,
                    endPoint: shimmer ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: false),
                value: shimmer
            )
    }
}
