// ChatView.swift
// VitaCore — Conversational AI Interface (Tab 2)
// Design System: Deep Space Bioluminescence · iOS 26 Liquid Glass
// Architecture: 5-layer OpenClaw | Sprint Phase 2

import SwiftUI
import VitaCoreDesign
import VitaCoreContracts
import VitaCoreNavigation

// MARK: - ChatView

struct ChatView: View {

    // MARK: Environment

    @Environment(\.inferenceProvider) var inferenceProvider
    @Environment(\.graphStore) var graphStore
    @Environment(\.personaEngine) var personaEngine
    @Environment(\.skillBus) var skillBus
    @Environment(\.dismiss) var dismiss
    @Environment(NavigationRouter.self) var navRouter

    // MARK: State

    @State private var viewModel: ChatViewModel?
    @State private var scrollProxy: ScrollViewProxy?

    // MARK: Computed

    private var canSend: Bool {
        guard let vm = viewModel else { return false }
        return !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming
    }

    // MARK: Body

    var body: some View {
        ZStack {
            BackgroundMesh()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topNavBar
                    .zIndex(1)

                if let vm = viewModel {
                    healthContextBar(vm: vm)
                        .padding(.horizontal, VCSpacing.lg)
                        .padding(.top, VCSpacing.sm)
                        .padding(.bottom, VCSpacing.xs)
                        .zIndex(1)
                }

                messageThread

                inputToolbar
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = ChatViewModel(
                    inferenceProvider: inferenceProvider,
                    graphStore: graphStore,
                    personaEngine: personaEngine,
                    skillBus: skillBus
                )
            }
            await viewModel?.load()
        }
    }

    // MARK: - Top Nav Bar

    private var topNavBar: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, VCSpacing.xs)

            Spacer()

            Text("VitaCore")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)

            Spacer()

            // On-Device trust indicator
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("On-Device")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(VCColors.safe)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(VCColors.safe.opacity(0.12)))
            .overlay(Capsule().strokeBorder(VCColors.safe.opacity(0.3), lineWidth: 1))
            .padding(.trailing, VCSpacing.lg)
        }
        .padding(.top, VCSpacing.sm)
        .background(Color.clear)
    }

    // MARK: - Health Context Bar

    @ViewBuilder
    private func healthContextBar(vm: ChatViewModel) -> some View {
        VStack(spacing: VCSpacing.sm) {
            // Collapsed row — always visible
            GlassCard(style: .small) {
                HStack(spacing: VCSpacing.md) {
                    HealthContextPill(
                        icon: "drop.fill",
                        value: vm.glucoseDisplayValue,
                        unit: "mg/dL",
                        color: VCColors.tertiary
                    )

                    contextDivider

                    HealthContextPill(
                        icon: "waveform.path.ecg",
                        value: vm.heartRateDisplayValue,
                        unit: "bpm",
                        color: VCColors.secondary
                    )

                    contextDivider

                    HealthContextPill(
                        icon: "figure.walk",
                        value: vm.stepsDisplayValue,
                        unit: "steps",
                        color: VCColors.primary
                    )

                    contextDivider

                    HealthContextPill(
                        icon: "cup.and.saucer.fill",
                        value: vm.fluidDisplayValue,
                        unit: "fluid",
                        color: VCColors.tertiary
                    )

                    Spacer(minLength: 0)

                    Image(systemName: vm.isContextBarExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(VCColors.outline)
                        .frame(width: 20, height: 20)
                }
            }
            .onTapGesture { vm.toggleContextBar() }

            // Expanded panel
            if vm.isContextBarExpanded {
                GlassCard(style: .standard) {
                    VStack(spacing: VCSpacing.lg) {
                        Text("Current Readings")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VCColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: VCSpacing.md
                        ) {
                            expandedMetricTile(
                                icon: "drop.fill",
                                label: "Glucose",
                                value: vm.glucoseDisplayValue,
                                unit: "mg/dL",
                                color: VCColors.tertiary
                            )
                            expandedMetricTile(
                                icon: "waveform.path.ecg",
                                label: "Heart Rate",
                                value: vm.heartRateDisplayValue,
                                unit: "bpm",
                                color: VCColors.secondary
                            )
                            expandedMetricTile(
                                icon: "figure.walk",
                                label: "Steps",
                                value: vm.stepsDisplayValue,
                                unit: "today",
                                color: VCColors.primary
                            )
                            expandedMetricTile(
                                icon: "cup.and.saucer.fill",
                                label: "Fluid",
                                value: vm.fluidDisplayValue,
                                unit: "today",
                                color: VCColors.tertiary
                            )
                        }

                        Text("Tap any metric to see full history")
                            .font(.system(size: 11))
                            .foregroundColor(VCColors.outline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isContextBarExpanded)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(VCColors.outlineVariant.opacity(0.5))
            .frame(width: 1, height: 24)
    }

    private func expandedMetricTile(
        icon: String,
        label: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VCColors.onSurfaceVariant)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(VCColors.onSurface)
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(VCColors.outline)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(VCSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VCRadius.sm, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Message Thread

    private var messageThread: some View {
        Group {
            if let vm = viewModel {
                switch vm.viewState {
                case .loading:
                    ScrollView {
                        ChatLoadingSkeletonView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .error(let err):
                    errorView(error: err, vm: vm)

                case .data, .stale, .empty:
                    threadScrollView(vm: vm)
                }
            } else {
                ScrollView {
                    ChatLoadingSkeletonView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func threadScrollView(vm: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: VCSpacing.lg) {
                    // Spacer at top
                    Color.clear.frame(height: VCSpacing.sm)

                    ForEach(vm.turns) { turn in
                        messageBubble(for: turn, vm: vm)
                            .id(turn.id)
                    }

                    // Streaming bubble
                    if vm.isStreaming {
                        StreamingBubble(content: vm.streamingContent)
                            .id("streaming-cursor")
                            .transition(.opacity)
                    }

                    // Bottom anchor
                    Color.clear
                        .frame(height: VCSpacing.md)
                        .id("bottom-anchor")
                }
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: vm.turns.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: vm.isStreaming) { _, streaming in
                if streaming {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
            .onChange(of: vm.streamingContent) { _, _ in
                if vm.isStreaming {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(for turn: ConversationTurn, vm: ChatViewModel) -> some View {
        switch turn.role {
        case .user:
            UserMessageBubble(turn: turn)

        case .assistant:
            AssistantMessageBubble(
                turn: turn,
                evidenceExpanded: vm.expandedEvidence.contains(turn.id),
                onToggleEvidence: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.toggleEvidence(for: turn.id)
                    }
                },
                onAction: { action in
                    handleAction(action, vm: vm)
                }
            )

        case .system:
            SystemMessageView(turn: turn)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }

    // MARK: - Error View

    private func errorView(error: Error, vm: ChatViewModel) -> some View {
        VStack(spacing: VCSpacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(VCColors.alertOrange)

            VStack(spacing: VCSpacing.sm) {
                Text("Couldn't load conversation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                Text(error.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VCSpacing.xxl)
            }

            Button(action: {
                Task { await vm.load() }
            }) {
                Text("Try again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, VCSpacing.xxl)
                    .padding(.vertical, VCSpacing.md)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [VCColors.primary, VCColors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)

            Spacer()
        }
    }

    // MARK: - Input Toolbar

    private var inputToolbar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(VCColors.outlineVariant.opacity(0.3))

            HStack(spacing: VCSpacing.md) {
                // Camera button
                Button(action: {
                    navRouter.presentSheet(.foodEntry)
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(VCColors.primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(VCColors.primaryContainer.opacity(0.5)))
                }
                .buttonStyle(.plain)

                // Text input
                if let vm = viewModel {
                    TextField("Ask VitaCore...", text: Bindable(vm).inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                        .foregroundColor(VCColors.onSurface)
                        .tint(VCColors.primary)
                        .padding(.horizontal, VCSpacing.md)
                        .padding(.vertical, VCSpacing.sm)
                        .background(
                            Capsule()
                                .fill(VCColors.surfaceLow)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(VCColors.outlineVariant, lineWidth: 1)
                                )
                        )
                        .onSubmit {
                            Task { await vm.sendMessage() }
                        }
                } else {
                    // Placeholder while viewModel loads
                    RoundedRectangle(cornerRadius: VCRadius.pill)
                        .fill(VCColors.surfaceLow)
                        .frame(height: 38)
                        .overlay(
                            Text("Ask VitaCore...")
                                .font(.system(size: 15))
                                .foregroundColor(VCColors.outline)
                                .padding(.horizontal, VCSpacing.md),
                            alignment: .leading
                        )
                }

                // Send button
                Button(action: {
                    guard let vm = viewModel else { return }
                    Task { await vm.sendMessage() }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? VCColors.primary : VCColors.outline.opacity(0.4))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, VCSpacing.lg)
            .padding(.vertical, VCSpacing.sm)
            .background(.ultraThinMaterial)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Action Handler

    private func handleAction(_ action: ActionType, vm: ChatViewModel) {
        switch action {
        case .logActivity:
            // Navigate to activity log — currently uses foodEntry as placeholder
            // Replace with dedicated .activityEntry once SheetDestination is extended
            break
        case .logFluid:
            navRouter.presentSheet(.fluidEntry)
        case .remindLater:
            // Trigger local notification — handled by alert router
            break
        case .dismiss:
            // No-op: user acknowledged
            break
        case .contactClinician:
            // Open contact clinician sheet
            break
        case .emergencyCall:
            if let url = URL(string: "tel://911") {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Chat View") {
    NavigationStack {
        ChatView()
            .environment(NavigationRouter())
    }
}
#endif
