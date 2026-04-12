// HomeDashboardViewModel.swift
// VitaCore — Home Dashboard ViewModel
// Architecture: 5-layer OpenClaw | Sprint Phase 1

import SwiftUI
import Observation
import VitaCoreContracts
import VitaCoreDesign

@Observable
@MainActor
final class HomeDashboardViewModel {

    // MARK: - Health State

    var healthStateText: String = "Loading..."
    var healthStateColor: Color = .gray
    var lastUpdatedText: String = "—"

    // MARK: - Goal Rings

    var goalProgress: [GoalProgress] = []

    // MARK: - Hero Glucose

    var glucoseReading: Reading?
    var glucoseReadings: [Reading] = []   // 4-hour window for sparkline
    var glucoseTrend: TrendDirection = .stable
    var glucoseBand: ThresholdBand = .safe

    // MARK: - Metric Grid

    var bpSystolicReading: Reading?
    var bpDiastolicReading: Reading?
    var heartRateReading: Reading?
    var stepsReading: Reading?
    var sleepReading: Reading?

    // MARK: - Intelligence Card

    var prescriptionCard: PrescriptionCard?

    // MARK: - Alerts

    var recentAlerts: [AlertEvent] = []

    // MARK: - View State

    var viewState: ViewState<Void> = .loading

    // MARK: - Dependencies

    private let graphStore: GraphStoreProtocol
    private let personaEngine: PersonaEngineProtocol
    private let inferenceProvider: InferenceProviderProtocol
    private let alertRouter: AlertRouterProtocol

    // MARK: - Init

    init(
        graphStore: GraphStoreProtocol,
        personaEngine: PersonaEngineProtocol,
        inferenceProvider: InferenceProviderProtocol,
        alertRouter: AlertRouterProtocol
    ) {
        self.graphStore = graphStore
        self.personaEngine = personaEngine
        self.inferenceProvider = inferenceProvider
        self.alertRouter = alertRouter
    }

    // MARK: - Load

    func load() async {
        viewState = .loading

        do {
            // Fetch all data concurrently
            async let glucose        = try graphStore.getLatestReading(for: .glucose)
            async let glucoseRange   = try graphStore.getRangeReadings(
                for: .glucose,
                from: Date().addingTimeInterval(-4 * 3600),
                to: Date()
            )
            async let bpSys          = try graphStore.getLatestReading(for: .bloodPressureSystolic)
            async let bpDia          = try graphStore.getLatestReading(for: .bloodPressureDiastolic)
            async let hr             = try graphStore.getLatestReading(for: .heartRate)
            async let steps          = try graphStore.getLatestReading(for: .steps)
            async let sleep          = try graphStore.getLatestReading(for: .sleep)
            async let persona        = try personaEngine.getPersonaContext()
            async let alerts         = try alertRouter.getRecentAlerts(limit: 3)

            self.glucoseReading      = try await glucose
            self.glucoseReadings     = try await glucoseRange
            self.bpSystolicReading   = try await bpSys
            self.bpDiastolicReading  = try await bpDia
            self.heartRateReading    = try await hr
            self.stepsReading        = try await steps
            self.sleepReading        = try await sleep
            let resolvedPersona      = try await persona
            self.goalProgress        = resolvedPersona.goalProgress
            self.recentAlerts        = try await alerts

            // Build a minimal InferenceRequest to fetch latest prescription card.
            // Wrapped in try? so prescription card stays nil-tolerant.
            let snapshot = try? await graphStore.getCurrentSnapshot()
            if let snap = snapshot {
                let req = InferenceRequest(
                    persona: resolvedPersona,
                    snapshot: snap,
                    thresholdSet: ThresholdSet(thresholds: []),
                    recentEpisodes: [],
                    stalenessThreshold: 600,
                    conversationalOverride: nil,
                    temperatureHint: 0.7
                )
                self.prescriptionCard = try? await inferenceProvider.getLatestPrescriptionCard(for: req)
            }

            // Derive health state from active readings
            updateHealthState()

            // Classify glucose band
            if let value = self.glucoseReading?.value {
                switch value {
                case ..<70:    glucoseBand = .critical
                case 180...:   glucoseBand = .alert
                case 160...:   glucoseBand = .watch
                default:       glucoseBand = .safe
                }
            }

            if let trend = self.glucoseReading?.trendDirection {
                self.glucoseTrend = trend
            }

            viewState = .data(())

        } catch {
            viewState = .error(error)
        }
    }

    // MARK: - Helpers

    private func updateHealthState() {
        // Evaluate all latest readings and derive aggregate health state
        var issues: [String] = []

        if let glucose = glucoseReading?.value {
            if glucose < 70 || glucose > 180 { issues.append("glucose out of range") }
        }

        if let sys = bpSystolicReading?.value, sys > 140 {
            issues.append("elevated BP")
        }

        if let hr = heartRateReading?.value, hr > 100 {
            issues.append("elevated HR")
        }

        if issues.isEmpty {
            healthStateText  = "All metrics in safe range"
            healthStateColor = VCColors.safe
        } else if issues.count == 1 {
            healthStateText  = "\(issues[0].capitalized) — review recommended"
            healthStateColor = VCColors.watch
        } else {
            healthStateText  = "\(issues.count) metrics need attention"
            healthStateColor = VCColors.alertOrange
        }

        lastUpdatedText = relativeUpdateTime()
    }

    private func relativeUpdateTime() -> String {
        guard let ts = glucoseReading?.timestamp else { return "—" }
        let seconds = Int(Date().timeIntervalSince(ts))
        if seconds < 60    { return "Just now" }
        if seconds < 3600  { return "\(seconds / 60) min ago" }
        return "\(seconds / 3600) hr ago"
    }
}
