import SwiftUI
import UIKit
import VitaCoreContracts
import VitaCoreMock
import VitaCoreNavigation
import VitaCoreDesign
import VitaCoreGraph
import VitaCorePersona
import VitaCoreThreshold
import VitaCoreInference
import VitaCoreSkillBus
import VitaCoreHeartbeat
import VitaCoreMiroFish
#if DEMO_MODE
import VitaCoreSynthetic
#endif

@main
struct VitaCoreApp: App {

    @State private var tabRouter = TabRouter()
    @State private var navRouter = NavigationRouter()
    @State private var alertManager = AlertPresentationManager()

    // Dependency injection.
    // AD-01 (revised): GraphStore is now the real GRDB-backed implementation.
    // All other components remain mocked until their respective backend sprints.
    private let dataProvider = MockDataProvider.shared
    private let graphStore: GraphStoreProtocol
    private let personaEngine: PersonaEngineProtocol
    private let thresholdEngine: VitaCoreThresholdEngine
    private let inferenceProvider: InferenceProviderProtocol
    private let skillBus: SkillBusProtocol
    private let heartbeatEngine: HeartbeatEngine
    private let alertRouter: AlertRouterProtocol
    #if canImport(HealthKit)
    private var healthKitSkill: HealthKitSkill?
    #endif

    init() {
        // Initialise ALL stored properties first (Swift init rules).

        // Wire up the real GRDB graph store; fall back to mock on failure.
        let graph: GraphStoreProtocol
        do {
            graph = try GRDBGraphStore.defaultStore()
            print("✅ VitaCoreGraph: GRDB store initialised at Application Support/VitaCore/vitacore.sqlite")
        } catch {
            print("⚠️ VitaCoreGraph: GRDB init failed (\(error)) — falling back to mock")
            graph = MockDataProvider.shared.graphStore
        }
        self.graphStore = graph

        // C01 PersonaEngine — real GRDB-backed persona store with a
        // graph-driven inferencer for first-launch bootstrap. Falls
        // back to mock on failure so the UI never loses its source.
        let persona: PersonaEngineProtocol
        do {
            let personaStore = try GRDBPersonaStore.defaultStore()
            persona = VitaCorePersonaEngine(store: personaStore, graphStore: graph)
            print("✅ VitaCorePersona: engine initialised at Application Support/VitaCore/vitacore_persona.sqlite")
        } catch {
            print("⚠️ VitaCorePersona: init failed (\(error)) — falling back to mock")
            persona = MockDataProvider.shared.personaEngine
        }
        self.personaEngine = persona

        // C14 ThresholdEngine — resolves per-user metric bands from
        // persona conditions + medications + clinician overrides.
        // 60s cache TTL, invalidate on persona mutation.
        self.thresholdEngine = VitaCoreThresholdEngine(personaEngine: persona)
        print("✅ VitaCoreThreshold: engine initialised with 60s cache TTL")

        // C10/C11 InferenceProvider — on-device Gemma runtime with
        // conversation persistence. Falls back to rule-based insights
        // when the model isn't downloaded yet (no crash, no blank UI).
        let inference: InferenceProviderProtocol
        do {
            let gemmaRuntime = Gemma4Runtime(quantisation: .gemma3n_q4)
            let convStore = try ConversationStore.defaultStore()
            inference = VitaCoreInferenceProvider(
                runtime: gemmaRuntime,
                conversationStore: convStore
            )
            print("✅ VitaCoreInference: provider initialised (model download deferred to onboarding)")
        } catch {
            print("⚠️ VitaCoreInference: init failed (\(error)) — falling back to mock")
            inference = MockDataProvider.shared.inferenceProvider
        }
        self.inferenceProvider = inference

        // C03 SkillBus — manual entry skills write directly to GraphStore.
        // 5/5 frozen protocols now have real implementations.
        let bus = VitaCoreSkillBus(graphStore: graph)

        // C04 HealthKitSkill — registers as a device skill in the bus.
        // Authorization is deferred to onboarding (OnboardingPermissionsView).
        #if canImport(HealthKit)
        let hkSkill = HealthKitSkill(graphStore: graph, skillBus: bus)
        // Store reference so onboarding can call requestAuthorization().
        self.healthKitSkill = hkSkill
        print("✅ HealthKitSkill: registered (auth deferred to onboarding)")
        #endif

        self.skillBus = bus
        print("✅ VitaCoreSkillBus: \(bus.registeredSkillCount) skills registered")

        // C09 HeartbeatEngine — foreground monitoring loop.
        let heartbeat = HeartbeatEngine(
            graphStore: graph,
            thresholdEngine: self.thresholdEngine,
            cycleInterval: 60
        )
        self.heartbeatEngine = heartbeat

        // Sprint 2 N-04: Real AlertRouter — LAST mock replaced.
        // ALL 5 frozen protocols now have real implementations.
        let router = VitaCoreAlertRouter(graphStore: graph)
        self.alertRouter = router
        // Sprint 2 N-02: set quiet hours from persona preferences.
        Task {
            if let ctx = try? await persona.getPersonaContext() {
                router.quietHoursStart = ctx.preferences.notificationQuietHoursStart
                router.quietHoursEnd = ctx.preferences.notificationQuietHoursEnd
            }
        }
        print("✅ VitaCoreAlertRouter: real alert routing + notification dispatch")

        // Wire HeartbeatEngine → MiroFish: threshold crossing triggers
        // multi-cofactor RCA + prescription card generation.
        let miroFish = MiroFishEngine()
        heartbeat.onInferenceRequest = { [weak heartbeat] request in
            guard let graphRef = heartbeat?.graphStore else { return }
            Task {
                do {
                    let trigger = Reading(
                        metricType: .glucose,
                        value: request.snapshot.glucose?.value ?? 0,
                        unit: "mg/dL",
                        timestamp: Date(),
                        sourceSkillId: "engine.heartbeat",
                        confidence: 1.0
                    )
                    let (analysis, card) = try await miroFish.analyseAndPrescribe(
                        trigger: trigger,
                        graphStore: graphRef,
                        persona: request.persona,
                        thresholdSet: request.thresholdSet
                    )
                    print("🧠 MiroFish: \(analysis.cofactors.count) cofactors → \(card.prescriptions.count) prescriptions")
                    print("   Top: \(card.prescriptions.first?.actionVerb ?? "none") — \(card.prescriptions.first?.actionDetail ?? "")")
                } catch {
                    print("⚠️ MiroFish analysis failed: \(error)")
                }
            }
        }
        heartbeat.start()
        print("✅ HeartbeatEngine + MiroFish: monitoring + RCA pipeline active")

        // Now that all stored properties are set, it's safe to call instance methods.
        configureAppearance()

        // Sprint 2: HeartbeatEngine alerts → AlertRouter (persistence +
        // local notifications) + AlertPresentationManager (in-app UI).
        let alertMgr = self.alertManager
        let alertRtr = router
        heartbeat.onAlert = { @Sendable alert in
            // 1. Route through AlertRouter for persistence + push notification.
            let alertEvent = AlertEvent(
                urgency: AlertBand(rawValue: alert.level.rawValue) ?? .watch,
                metricType: alert.metricType,
                value: alert.value,
                trendDirection: .stable,
                explanation: alert.message,
                evidence: ["\(Int(alert.value)) \(alert.unit)"]
            )
            let payload = AlertDeliveryPayload(
                event: alertEvent,
                autoDismiss: alert.level == .watch,
                autoDismissDelay: 5
            )
            Task { await alertRtr.route(payload) }

            // 2. Route to in-app UI presentation.
            Task { @MainActor in
                switch alert.level {
                case .critical:
                    alertMgr.presentCritical(CriticalAlertData(
                        alertId: alert.id,
                        title: alert.metricType.displayName,
                        body: alert.message,
                        metricValue: alert.value,
                        metricUnit: alert.unit
                    ))
                case .alert:
                    alertMgr.presentAlert(AlertSheetData(
                        alertId: alert.id,
                        title: "\(alert.metricType.displayName) Alert",
                        body: alert.message,
                        metricValue: alert.value,
                        metricUnit: alert.unit
                    ))
                case .watch:
                    alertMgr.presentWatch(WatchBannerData(
                        alertId: alert.id,
                        title: alert.message,
                        subtitle: "\(Int(alert.value)) \(alert.unit)",
                        iconName: alert.metricType.icon
                    ))
                }
            }
        }

        // Sprint 2 N-03: request notification permission on first launch.
        Task.detached {
            let granted = await NotificationPermission.requestAuthorization()
            print(granted ? "✅ Notifications: authorised" : "⚠️ Notifications: denied")
        }

        // Sprint 7 S-03: 90-day data retention. Purge old readings on launch.
        Task.detached {
            let cutoff = Date().addingTimeInterval(-90 * 86400)
            for metric in MetricType.allCases {
                try? await graph.purgeReadings(for: metric, olderThan: cutoff)
            }
            print("✅ Data retention: purged readings older than 90 days")
        }

        // Sprint 2.B: HealthKit authorization + backfill on first launch.
        // The system dialog shows once; subsequent launches are no-ops.
        #if canImport(HealthKit)
        if let hk = self.healthKitSkill {
            Task.detached {
                do {
                    let granted = try await hk.requestAuthorization()
                    if granted {
                        hk.startObserving()
                        await hk.performBackfill(days: 14)
                        print("✅ HealthKit: authorised + backfill complete")
                    }
                } catch {
                    print("⚠️ HealthKit: auth failed (\(error))")
                }
            }
        }
        #endif

        #if DEMO_MODE
        // Sprint 0.3 demo-mode seeding: on first DEMO_MODE launch, populate
        // the real GRDB store with a synthetic 14-day T1D cohort so the UI
        // has a realistic dataset for screenshots / reviewer builds.
        Self.seedDemoCohortIfNeeded(store: graph)
        #endif
    }

    #if DEMO_MODE
    /// Seeds the given graph store with a deterministic synthetic cohort
    /// the first time it runs. Guarded by `UserDefaults` so we don't
    /// re-seed on every launch. Production builds do not compile this
    /// symbol (DEMO_MODE flag off).
    private static func seedDemoCohortIfNeeded(store: GraphStoreProtocol) {
        let defaultsKey = "VitaCore.demoCohortSeededAt"
        if UserDefaults.standard.object(forKey: defaultsKey) != nil {
            print("🎭 DEMO_MODE: cohort already seeded, skipping")
            return
        }
        Task.detached {
            do {
                let cohort = CohortBuilder().buildCohort(
                    archetype: .t1dPump,
                    days: 14,
                    seed: 20260411
                )
                try await cohort.write(to: store)
                UserDefaults.standard.set(Date(), forKey: defaultsKey)
                print("🎭 DEMO_MODE: seeded \(cohort.readingCount) readings + \(cohort.episodeCount) episodes for \(cohort.archetype.displayName)")
            } catch {
                print("⚠️ DEMO_MODE seeding failed: \(error)")
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            LaunchRouterView()
                .environment(tabRouter)
                .environment(navRouter)
                .environment(alertManager)
                // Inject protocol implementations as environment values
                .environment(\.graphStore, graphStore)        // ← REAL (GRDB)
                .environment(\.personaEngine, personaEngine)  // ← REAL (VitaCorePersonaEngine)
                .environment(\.inferenceProvider, inferenceProvider) // ← REAL (VitaCoreInferenceProvider)
                .environment(\.skillBus, skillBus)               // ← REAL (VitaCoreSkillBus)
                .environment(\.alertRouter, alertRouter)          // ← REAL (VitaCoreAlertRouter)
        }
    }

    // MARK: - UIKit appearance configuration

    /// Configures translucent-blur tab bar and navigation bar to match
    /// the Ethereal Light design system. Applied once at app launch.
    private func configureAppearance() {
        // Tab bar: translucent blur over the app background
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabAppearance.backgroundColor = UIColor(VCColors.background).withAlphaComponent(0.72)

        // Selected item: primary purple, bold
        let selectedItemColor = UIColor(VCColors.primary)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = selectedItemColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedItemColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Unselected item: muted onSurfaceVariant
        let unselectedItemColor = UIColor(VCColors.onSurfaceVariant)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = unselectedItemColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedItemColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar: translucent blur with primary tint
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        navAppearance.backgroundColor = UIColor(VCColors.background).withAlphaComponent(0.70)

        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(VCColors.onSurface),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(VCColors.onSurface),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(VCColors.primary)
    }
}
