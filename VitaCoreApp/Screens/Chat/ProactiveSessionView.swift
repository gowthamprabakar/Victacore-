// ProactiveSessionView.swift
// VitaCore – Proactive Alert Session Screen
// Deep Space Bioluminescence · iOS 26 Liquid Glass

import SwiftUI
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation
import VitaCoreThreshold

// MARK: - ProactiveSessionView

struct ProactiveSessionView: View {
    // MARK: Inputs
    let urgency: AlertBand           // .info / .watch / .alert / .critical
    let alertTitle: String           // e.g. "Glucose High"
    let alertTimestamp: Date
    let triggerMessage: String       // Initial assistant message
    let onDismiss: () -> Void

    // MARK: Environment (Sprint 3.C — real inference)
    @Environment(\.inferenceProvider) private var inferenceProvider
    @Environment(\.personaEngine) private var personaEngine
    @Environment(\.graphStore) private var graphStore

    // MARK: State
    @State private var userInput: String = ""
    @State private var turns: [ConversationTurn] = []
    @State private var isStreaming: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    // Streaming dot animation phases
    @State private var dotScales: [CGFloat] = [1, 1, 1]

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            VStack(spacing: 0) {
                alertHeader

                Divider()
                    .background(urgencyColor.opacity(0.3))

                messageThread

                inputToolbar
            }
        }
        .navigationBarHidden(true)
        .onAppear { seedInitialTurn() }
    }

    // MARK: - Alert Context Header

    private var alertHeader: some View {
        HStack(spacing: VCSpacing.md) {
            // Urgency icon with animated glow for critical
            ZStack {
                Circle()
                    .fill(urgencyColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: urgencyIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(urgencyColor)
            }

            // Title + timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text("VitaCore Alert · \(alertTitle)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                    .lineLimit(1)

                Text("Triggered \(relativeTime(alertTimestamp))")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(VCColors.onSurfaceVariant)
            }

            Spacer()

            // Urgency pill badge
            urgencyBadge

            // Dismiss button (min 44pt touch target)
            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(VCColors.surfaceLow)
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VCColors.onSurfaceVariant)
                }
                .frame(width: 44, height: 44) // expanded tap target
            }
        }
        .padding(.horizontal, VCSpacing.lg)
        .padding(.vertical, VCSpacing.md)
        .background(
            Rectangle()
                .fill(urgencyColor.opacity(0.08))
                .overlay(
                    Rectangle()
                        .fill(urgencyColor)
                        .frame(height: 2),
                    alignment: .bottom
                )
        )
    }

    private var urgencyBadge: some View {
        Text(urgencyLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(urgencyColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(urgencyColor.opacity(0.15))
                    .overlay(Capsule().stroke(urgencyColor.opacity(0.4), lineWidth: 1))
            )
    }

    // MARK: - Message Thread

    private var messageThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: VCSpacing.md) {
                    ForEach(turns) { turn in
                        messageBubble(turn: turn)
                            .id(turn.id)
                    }

                    if isStreaming {
                        streamingIndicator
                            .id("streaming")
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, VCSpacing.lg)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, VCSpacing.md)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: turns.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isStreaming) { _, streaming in
                if streaming { scrollToBottom(proxy: proxy) }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(turn: ConversationTurn) -> some View {
        switch turn.role {
        case .assistant:
            assistantBubble(turn: turn)
        case .user:
            userBubble(turn: turn)
        case .system:
            systemLabel(turn: turn)
        }
    }

    private func assistantBubble(turn: ConversationTurn) -> some View {
        HStack(alignment: .bottom, spacing: VCSpacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [VCColors.primary.opacity(0.3), VCColors.tertiary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VCColors.primary)
            }

            GlassCard(style: .small) {
                VStack(alignment: .leading, spacing: VCSpacing.xs) {
                    Text(turn.content)
                        .font(.system(size: 15))
                        .foregroundColor(VCColors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)

                    // Action chips (if any)
                    if !turn.actions.isEmpty {
                        actionChips(turn.actions)
                    }

                    Text(shortTime(turn.timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(VCColors.outline)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)

            Spacer(minLength: VCSpacing.xxl)
        }
    }

    private func userBubble(turn: ConversationTurn) -> some View {
        HStack(alignment: .bottom, spacing: VCSpacing.sm) {
            Spacer(minLength: VCSpacing.xxl)

            VStack(alignment: .trailing, spacing: 3) {
                Text(turn.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, VCSpacing.md)
                    .padding(.vertical, VCSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.lg)
                            .fill(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)

                Text(shortTime(turn.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(VCColors.outline)
            }
        }
    }

    private func systemLabel(turn: ConversationTurn) -> some View {
        Text(turn.content)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(VCColors.onSurfaceVariant)
            .padding(.horizontal, VCSpacing.md)
            .padding(.vertical, VCSpacing.xs)
            .background(
                Capsule().fill(VCColors.surfaceLow)
            )
            .frame(maxWidth: .infinity)
    }

    // MARK: - Action Chips

    private func actionChips(_ actions: [ActionType]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VCSpacing.xs) {
                ForEach(actions, id: \.self) { action in
                    actionChip(action)
                }
            }
        }
    }

    private func actionChip(_ action: ActionType) -> some View {
        Button(action: {
            // Actions handled by parent ChatViewModel
        }) {
            Text(actionLabel(action))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VCColors.primary)
                .padding(.horizontal, VCSpacing.sm)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(VCColors.primaryContainer.opacity(0.4))
                        .overlay(Capsule().stroke(VCColors.primary.opacity(0.3), lineWidth: 1))
                )
        }
        .frame(minHeight: 28)
    }

    private func actionLabel(_ action: ActionType) -> String {
        switch action {
        case .logActivity:   return "Log Activity"
        case .remindLater:   return "Remind Later"
        case .dismiss:       return "Dismiss"
        default:             return action.rawValue.capitalized
        }
    }

    // MARK: - Streaming Indicator

    private var streamingIndicator: some View {
        HStack(alignment: .bottom, spacing: VCSpacing.sm) {
            // Avatar placeholder
            Circle()
                .fill(VCColors.primary.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(VCColors.primary)
                )

            GlassCard(style: .small) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(VCColors.primary)
                            .frame(width: 7, height: 7)
                            .scaleEffect(dotScales[i])
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.18),
                                value: dotScales[i]
                            )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
            .frame(width: 72)
            .onAppear { startDotAnimation() }

            Spacer()
        }
    }

    private func startDotAnimation() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) {
                dotScales[i] = 1.5
            }
        }
    }

    // MARK: - Input Toolbar

    private var inputToolbar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(VCColors.outlineVariant)

            HStack(spacing: VCSpacing.sm) {
                // Text field
                TextField("Reply to VitaCore…", text: $userInput, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(VCColors.onSurface)
                    .lineLimit(1...5)
                    .padding(.horizontal, VCSpacing.md)
                    .padding(.vertical, VCSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: VCRadius.lg)
                            .fill(VCColors.surfaceLow)
                            .overlay(
                                RoundedRectangle(cornerRadius: VCRadius.lg)
                                    .stroke(VCColors.outlineVariant, lineWidth: 1)
                            )
                    )

                // Send button (min 44pt)
                Button(action: sendMessage) {
                    Image(systemName: userInput.trimmingCharacters(in: .whitespaces).isEmpty
                          ? "arrow.up.circle"
                          : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            userInput.trimmingCharacters(in: .whitespaces).isEmpty
                            ? VCColors.outline
                            : VCColors.primary
                        )
                        .animation(.easeInOut(duration: 0.15), value: userInput.isEmpty)
                }
                .frame(width: 44, height: 44)
                .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty || isStreaming)
            }
            .padding(.horizontal, VCSpacing.lg)
            .padding(.vertical, VCSpacing.sm)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func seedInitialTurn() {
        guard turns.isEmpty else { return }
        let firstTurn = ConversationTurn(
            id: UUID(),
            role: .assistant,
            content: triggerMessage,
            intent: .healthStatus,
            actions: [.logActivity, .remindLater, .dismiss],
            timestamp: alertTimestamp
        )
        turns = [firstTurn]
    }

    private func sendMessage() {
        let text = userInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        userInput = ""

        let userTurn = ConversationTurn(
            id: UUID(),
            role: .user,
            content: text,
            intent: .conversational,
            actions: [],
            timestamp: Date()
        )
        turns.append(userTurn)

        // Sprint 3.C: real inference via InferenceProvider with full health context.
        isStreaming = true
        Task {
            // Build real InferenceRequest with persona + snapshot + thresholds.
            let persona = (try? await personaEngine.getPersonaContext()) ?? PersonaContext(userId: UUID())
            let snapshot = (try? await graphStore.getCurrentSnapshot()) ?? MonitoringSnapshot(dataQuality: .insufficient)
            let thresholds = ThresholdResolver().resolve(from: persona)

            let request = InferenceRequest(
                persona: persona,
                snapshot: snapshot,
                thresholdSet: thresholds,
                conversationalOverride: "Alert context: \(alertTitle). User asks: \(text)",
                temperatureHint: 0.5
            )

            let stream = inferenceProvider.sendMessage(text, request: request)
            var fullResponse = ""
            for await token in stream {
                fullResponse += token
            }

            let assistantTurn = ConversationTurn(
                id: UUID(),
                role: .assistant,
                content: fullResponse.isEmpty
                    ? "I'm monitoring the situation. Stay hydrated and follow your protocol."
                    : fullResponse,
                intent: .lifestyleAdvice,
                actions: [.remindLater],
                timestamp: Date()
            )
            isStreaming = false
            turns.append(assistantTurn)
        }
    }

    // MARK: - Computed helpers

    private var urgencyColor: Color {
        switch urgency {
        case .info:     return VCColors.tertiary
        case .watch:    return VCColors.watch
        case .alert:    return VCColors.alertOrange
        case .critical: return VCColors.critical
        }
    }

    private var urgencyIconName: String {
        switch urgency {
        case .info:     return "info.circle.fill"
        case .watch:    return "eye.fill"
        case .alert:    return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.2"
        }
    }

    private var urgencyLabel: String {
        switch urgency {
        case .info:     return "INFO"
        case .watch:    return "WATCH"
        case .alert:    return "ALERT"
        case .critical: return "CRITICAL"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60    { return "just now" }
        if seconds < 3_600 { return "\(seconds / 60) min ago" }
        return "\(seconds / 3_600)h ago"
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Previews

#if DEBUG
struct ProactiveSessionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProactiveSessionView(
                urgency: .alert,
                alertTitle: "Glucose High",
                alertTimestamp: Date().addingTimeInterval(-180),
                triggerMessage: "Your blood glucose is reading 14.2 mmol/L, which is above your personal target range. Would you like me to walk you through some immediate steps?",
                onDismiss: {}
            )
            .previewDisplayName("Alert – Glucose High")

            ProactiveSessionView(
                urgency: .critical,
                alertTitle: "Heart Rate Spike",
                alertTimestamp: Date().addingTimeInterval(-45),
                triggerMessage: "Your heart rate jumped to 178 bpm at rest. This is unusual for you. Are you experiencing any chest pain or dizziness?",
                onDismiss: {}
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Critical – Heart Rate")

            ProactiveSessionView(
                urgency: .watch,
                alertTitle: "Sleep Deficit",
                alertTimestamp: Date().addingTimeInterval(-3600),
                triggerMessage: "You've had less than 5 hours of sleep over the last 3 nights. Chronic sleep deficit can elevate cortisol and affect glucose regulation. Want tips for tonight?",
                onDismiss: {}
            )
            .previewDisplayName("Watch – Sleep Deficit")
        }
    }
}
#endif
