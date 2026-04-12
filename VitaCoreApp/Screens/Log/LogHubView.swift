// LogHubView.swift
// VitaCore — Log Tab (Tab 3)

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign
import VitaCoreNavigation

// MARK: - ViewModel

@Observable
@MainActor
final class LogHubViewModel {
    var recentEpisodes: [Episode] = []
    var viewState: ViewState<Void> = .loading

    private let graphStore: GraphStoreProtocol

    init(graphStore: GraphStoreProtocol) {
        self.graphStore = graphStore
    }

    func load() async {
        viewState = .loading
        do {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let episodes = try await graphStore.getEpisodes(
                from: startOfDay.addingTimeInterval(-86400),
                to: now,
                types: []
            )
            self.recentEpisodes = Array(
                episodes.sorted { $0.referenceTime > $1.referenceTime }.prefix(8)
            )
            viewState = recentEpisodes.isEmpty ? .empty : .data(())
        } catch {
            viewState = .error(error)
        }
    }
}

// MARK: - Episode Display Helpers

private extension EpisodeType {
    var displayName: String {
        switch self {
        case .cgmGlucose, .manualGlucose: return "Glucose"
        case .bpReading:                  return "Blood Pressure"
        case .nutritionEvent:             return "Meal"
        case .fluidEvent:                 return "Fluid"
        case .weightReading:              return "Weight"
        case .symptomNote:                return "Note"
        default:                          return "Activity"
        }
    }

    var iconName: String {
        switch self {
        case .cgmGlucose, .manualGlucose: return "drop.fill"
        case .bpReading:                  return "heart.fill"
        case .nutritionEvent:             return "fork.knife"
        case .fluidEvent:                 return "cup.and.saucer.fill"
        case .weightReading:              return "scalemass.fill"
        case .symptomNote:                return "note.text"
        default:                          return "figure.walk"
        }
    }

    var accentColor: Color {
        switch self {
        case .cgmGlucose, .manualGlucose: return VCColors.primary
        case .bpReading:                  return VCColors.secondary
        case .nutritionEvent:             return VCColors.watch
        case .fluidEvent:                 return VCColors.tertiary
        case .weightReading:              return VCColors.primary
        case .symptomNote:                return VCColors.outline
        default:                          return VCColors.safe
        }
    }
}

// MARK: - Quick Log Button Model

private struct QuickLogItem {
    let sheet: LogHubView.LogSheetType
    let label: String
    let icon: String
    let color: Color
}

private let quickLogItems: [QuickLogItem] = [
    .init(sheet: .food,    label: "Food",    icon: "fork.knife",           color: VCColors.watch),
    .init(sheet: .fluid,   label: "Fluid",   icon: "drop.fill",            color: VCColors.tertiary),
    .init(sheet: .glucose, label: "Glucose", icon: "drop.fill",            color: VCColors.primary),
    .init(sheet: .bp,      label: "BP",      icon: "heart.fill",           color: VCColors.secondary),
    .init(sheet: .weight,  label: "Weight",  icon: "scalemass.fill",       color: VCColors.primary),
    .init(sheet: .note,    label: "Note",    icon: "note.text",            color: VCColors.onSurfaceVariant),
]

// MARK: - Main View

struct LogHubView: View {
    @Environment(\.graphStore) var graphStore
    @Environment(NavigationRouter.self) var navRouter
    @State private var viewModel: LogHubViewModel?
    @State private var presentingSheet: LogSheetType?

    enum LogSheetType: String, Identifiable {
        case food, fluid, glucose, bp, weight, note
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            BackgroundMesh().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VCSpacing.xl) {
                    headerSection

                    sectionLabel("QUICK LOG")
                    quickLogGrid

                    sectionLabel("TODAY'S LOGS")
                    timelineContent
                }
                .padding(.horizontal, VCSpacing.xxl)
                .padding(.top, VCSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = LogHubViewModel(graphStore: graphStore)
            }
            await viewModel?.load()
        }
        .sheet(item: $presentingSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: LogSheetType) -> some View {
        switch sheet {
        case .food:
            Text("Food Entry — Coming Soon")
                .font(.headline)
                .foregroundStyle(VCColors.onSurface)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .fluid:
            FluidEntrySheet(onDismiss: { presentingSheet = nil })
        case .glucose:
            GlucoseEntrySheet(onDismiss: { presentingSheet = nil })
        case .bp:
            BPEntrySheet(onDismiss: { presentingSheet = nil })
        case .weight:
            WeightEntrySheet(onDismiss: { presentingSheet = nil })
        case .note:
            NoteEntrySheet(onDismiss: { presentingSheet = nil })
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: VCSpacing.xs) {
            Text("Log")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(VCColors.onSurface)

            Text(todayDateString)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(VCColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(VCColors.onSurfaceVariant)
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Log Grid

    private var quickLogGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: VCSpacing.md),
                GridItem(.flexible(), spacing: VCSpacing.md),
                GridItem(.flexible(), spacing: VCSpacing.md),
            ],
            spacing: VCSpacing.md
        ) {
            ForEach(quickLogItems, id: \.label) { item in
                quickLogButton(item)
            }
        }
    }

    private func quickLogButton(_ item: QuickLogItem) -> some View {
        Button {
            presentingSheet = item.sheet
        } label: {
            GlassCard(style: .small) {
                VStack(spacing: VCSpacing.sm) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(item.color)
                        .frame(width: 32, height: 32)

                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VCSpacing.md)
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline Content

    @ViewBuilder
    private var timelineContent: some View {
        if let vm = viewModel {
            switch vm.viewState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VCSpacing.xxl)

            case .data, .stale:
                timelineSection(episodes: vm.recentEpisodes)

            case .empty:
                emptyTimelineState

            case .error:
                errorState
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, VCSpacing.xxl)
        }
    }

    // MARK: - Timeline Section

    private func timelineSection(episodes: [Episode]) -> some View {
        VStack(spacing: VCSpacing.sm) {
            ForEach(episodes) { episode in
                episodeRow(episode)
            }
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        GlassCard(style: .small) {
            HStack(spacing: VCSpacing.md) {
                // Timestamp
                Text(timeString(from: episode.referenceTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .frame(width: 52, alignment: .leading)

                // Icon
                Image(systemName: episode.episodeType.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(episode.episodeType.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(episode.episodeType.accentColor.opacity(0.12))
                    )

                // Label + value summary
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.episodeType.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VCColors.onSurface)

                    if let summary = episode.valueSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(VCColors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, VCSpacing.sm)
            .padding(.horizontal, VCSpacing.md)
            .frame(minHeight: 44)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Empty State

    private var emptyTimelineState: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.md) {
                Image(systemName: "tray")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(VCColors.onSurfaceVariant.opacity(0.6))

                Text("No logs yet today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VCColors.onSurface)

                Text("Tap a Quick Log button above to record your first entry.")
                    .font(.system(size: 13))
                    .foregroundStyle(VCColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(VCSpacing.xxl)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        GlassCard(style: .standard) {
            VStack(spacing: VCSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(VCColors.alertOrange)

                Text("Could not load logs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VCColors.onSurface)

                Button("Try Again") {
                    Task { await viewModel?.load() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VCColors.primary)
            }
            .padding(VCSpacing.xxl)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Episode value summary helper
// Episode is expected to expose a `valueSummary: String?` computed property
// or equivalent from VitaCoreContracts. If not present, the row gracefully
// omits the subtitle line.
private extension Episode {
    var valueSummary: String? { nil }   // replaced by real implementation from VitaCoreContracts
}
