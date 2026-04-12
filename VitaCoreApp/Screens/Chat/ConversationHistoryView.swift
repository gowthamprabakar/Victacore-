// ConversationHistoryView.swift
// VitaCore – Conversation History Screen
// Deep Space Bioluminescence · iOS 26 Liquid Glass

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - ViewModel

@Observable
@MainActor
final class ConversationHistoryViewModel {
    var allSessions: [ConversationSession] = []
    var filteredSessions: [ConversationSession] = []
    var searchText: String = ""
    var viewState: ViewState<Void> = .loading

    private let inferenceProvider: InferenceProviderProtocol

    init(inferenceProvider: InferenceProviderProtocol) {
        self.inferenceProvider = inferenceProvider
    }

    func load() async {
        viewState = .loading
        do {
            let sessions = try await inferenceProvider.getSessions()
            self.allSessions = sessions.sorted { $0.startedAt > $1.startedAt }
            applyFilter()
            viewState = allSessions.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }

    func applyFilter() {
        if searchText.isEmpty {
            filteredSessions = allSessions
        } else {
            filteredSessions = allSessions.filter { session in
                session.turns.contains { turn in
                    turn.content.localizedCaseInsensitiveContains(searchText)
                } || (session.sessionSummary?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    func deleteSession(_ session: ConversationSession) async {
        do {
            try await inferenceProvider.deleteSession(id: session.sessionId)
            allSessions.removeAll { $0.sessionId == session.sessionId }
            applyFilter()
            if allSessions.isEmpty { viewState = .empty }
        } catch {
            viewState = .error(error)
        }
    }

    func groupedSessions() -> [(title: String, sessions: [ConversationSession])] {
        let calendar = Calendar.current
        let now = Date()

        var today: [ConversationSession] = []
        var yesterday: [ConversationSession] = []
        var thisWeek: [ConversationSession] = []
        var earlier: [ConversationSession] = []

        for session in filteredSessions {
            let daysAgo = calendar.dateComponents([.day], from: session.startedAt, to: now).day ?? 0
            if calendar.isDateInToday(session.startedAt) {
                today.append(session)
            } else if calendar.isDateInYesterday(session.startedAt) {
                yesterday.append(session)
            } else if daysAgo < 7 {
                thisWeek.append(session)
            } else {
                earlier.append(session)
            }
        }

        var groups: [(String, [ConversationSession])] = []
        if !today.isEmpty    { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty  { groups.append(("This Week", thisWeek)) }
        if !earlier.isEmpty   { groups.append(("Earlier", earlier)) }
        return groups
    }

    func sessionTitle(_ session: ConversationSession) -> String {
        if let summary = session.sessionSummary { return summary }
        if let firstUser = session.turns.first(where: { $0.role == .user }) {
            return String(firstUser.content.prefix(60))
        }
        switch session.initiatedBy {
        case .proactiveAlert:  return "Health Alert"
        case .proactiveDigest: return "Daily Check-in"
        case .proactiveWeekly: return "Weekly Review"
        case .user:            return "New Chat"
        }
    }

    func sessionSnippet(_ session: ConversationSession) -> String {
        guard let lastNonSystem = session.turns.reversed().first(where: { $0.role != .system }) else {
            return "No messages yet"
        }
        return String(lastNonSystem.content.prefix(100))
    }

    func sessionIcon(_ session: ConversationSession) -> (icon: String, color: Color) {
        switch session.initiatedBy {
        case .user:            return ("sparkles",                     VCColors.primary)
        case .proactiveAlert:  return ("exclamationmark.triangle.fill", VCColors.alertOrange)
        case .proactiveDigest: return ("chart.bar.fill",               VCColors.primary)
        case .proactiveWeekly: return ("calendar",                     VCColors.secondary)
        }
    }

    func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60      { return "\(seconds)s" }
        if seconds < 3_600   { return "\(seconds / 60)m" }
        if seconds < 86_400  { return "\(seconds / 3_600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return "\(seconds / 604_800)w"
    }
}

// MARK: - ConversationHistoryView

struct ConversationHistoryView: View {
    @Environment(\.inferenceProvider) private var inferenceProvider
    @Environment(\.dismiss) private var dismiss

    /// Set by the parent when the user taps a row or creates a new session.
    var onOpenSession: ((ConversationSession) -> Void)?
    var onNewSession: (() -> Void)?

    @State private var viewModel: ConversationHistoryViewModel?

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            VStack(spacing: 0) {
                topNav
                searchBar
                content
            }
        }
        .navigationBarHidden(true)
        .task {
            if viewModel == nil {
                viewModel = ConversationHistoryViewModel(inferenceProvider: inferenceProvider)
            }
            await viewModel?.load()
        }
    }

    // MARK: Top navigation bar

    private var topNav: some View {
        HStack(spacing: 0) {
            // Back
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, VCSpacing.sm)

            Spacer()

            Text("Conversations")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VCColors.onSurface)

            Spacer()

            // New conversation
            Button(action: { onNewSession?() }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VCColors.primary, VCColors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .padding(.trailing, VCSpacing.lg)
        }
        .frame(height: 56)
        .padding(.top, VCSpacing.sm)
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: VCSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VCColors.outline)
                .font(.system(size: 15))

            if let vm = viewModel {
                TextField("Search conversations", text: Bindable(vm).searchText)
                    .font(.system(size: 15))
                    .foregroundColor(VCColors.onSurface)
                    .autocorrectionDisabled()
                    .onChange(of: vm.searchText) { _, _ in
                        vm.applyFilter()
                    }

                if !vm.searchText.isEmpty {
                    Button(action: {
                        vm.searchText = ""
                        vm.applyFilter()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VCColors.outline)
                            .font(.system(size: 14))
                    }
                    .frame(width: 28, height: 28)
                }
            }
        }
        .padding(.horizontal, VCSpacing.md)
        .padding(.vertical, 10)
        .background(Capsule().fill(VCColors.surfaceLow))
        .overlay(Capsule().stroke(VCColors.outlineVariant, lineWidth: 1))
        .padding(.horizontal, VCSpacing.xxl)
        .padding(.top, VCSpacing.sm)
        .padding(.bottom, VCSpacing.xs)
    }

    // MARK: Content router

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel {
            switch vm.viewState {
            case .loading:
                loadingView
            case .empty:
                emptyState
            case .data:
                sessionList(vm: vm)
            case .stale:
                sessionList(vm: vm)
            case .error(let err):
                errorView(err)
            }
        } else {
            loadingView
        }
    }

    // MARK: Session list

    private func sessionList(vm: ConversationHistoryViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                let groups = vm.groupedSessions()

                if groups.isEmpty && !vm.searchText.isEmpty {
                    noResultsView
                        .padding(.top, 60)
                } else {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            VStack(spacing: VCSpacing.xs) {
                                ForEach(group.sessions) { session in
                                    let iconInfo = vm.sessionIcon(session)
                                    SessionRow(
                                        session: session,
                                        iconName: iconInfo.icon,
                                        iconColor: iconInfo.color,
                                        title: vm.sessionTitle(session),
                                        snippet: vm.sessionSnippet(session),
                                        time: vm.relativeTime(session.startedAt),
                                        onTap: { onOpenSession?(session) }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await vm.deleteSession(session) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, VCSpacing.lg)
                            .padding(.bottom, VCSpacing.md)
                        } header: {
                            sectionHeader(title: group.title)
                        }
                    }
                }
            }
            .padding(.top, VCSpacing.sm)
            .padding(.bottom, VCSpacing.xxl)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(VCColors.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, VCSpacing.xl)
        .padding(.vertical, VCSpacing.xs)
        .background(VCColors.background.opacity(0.92))
    }

    // MARK: Empty / error / loading / no-results states

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: VCColors.primary))
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VCColors.primaryContainer.opacity(0.35))
                    .frame(width: 100, height: 100)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(VCColors.primary)
            }

            VStack(spacing: VCSpacing.xs) {
                Text("No conversations yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)

                Text("Start a new chat or let VitaCore\nreach out proactively.")
                    .font(.system(size: 14))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button(action: { onNewSession?() }) {
                HStack(spacing: VCSpacing.sm) {
                    Image(systemName: "square.and.pencil")
                    Text("New Conversation")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, VCSpacing.xl)
                .padding(.vertical, VCSpacing.md)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VCColors.primary, VCColors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .frame(minHeight: 44)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VCSpacing.xxl)
    }

    private var noResultsView: some View {
        VStack(spacing: VCSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(VCColors.outline)

            Text("No results")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VCColors.onSurface)

            Text("Try a different search term.")
                .font(.system(size: 14))
                .foregroundColor(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: VCSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VCColors.alertOrange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(VCColors.alertOrange)
            }

            VStack(spacing: VCSpacing.xs) {
                Text("Something went wrong")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VCColors.onSurface)
                Text(error.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundColor(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { await viewModel?.load() }
            }) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, VCSpacing.xl)
                    .padding(.vertical, VCSpacing.md)
                    .background(Capsule().fill(VCColors.primary))
            }
            .frame(minHeight: 44)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VCSpacing.xxl)
    }
}

// MARK: - SessionRow

struct SessionRow: View {
    let session: ConversationSession
    let iconName: String
    let iconColor: Color
    let title: String
    let snippet: String
    let time: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(style: .small) {
                HStack(spacing: VCSpacing.md) {
                    // Initiator icon badge
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(iconColor)
                    }

                    // Title + snippet
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(VCColors.onSurface)
                            .lineLimit(1)

                        Text(snippet)
                            .font(.system(size: 13))
                            .foregroundColor(VCColors.onSurfaceVariant)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: VCSpacing.sm)

                    // Time + status dot
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(time)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(VCColors.outline)

                        Circle()
                            .fill(session.status == .active ? VCColors.safe : VCColors.outline.opacity(0.5))
                            .frame(width: 7, height: 7)
                    }
                    .frame(minWidth: 32)
                }
                .padding(.vertical, VCSpacing.xs)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#if DEBUG
struct ConversationHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationHistoryView()
            .preferredColorScheme(.dark)
    }
}
#endif
