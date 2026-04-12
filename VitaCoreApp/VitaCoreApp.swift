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
        self.skillBus = VitaCoreSkillBus(graphStore: graph)
        print("✅ VitaCoreSkillBus: 6 manual entry skills registered")

        // Now that all stored properties are set, it's safe to call instance methods.
        configureAppearance()

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
                .environment(\.alertRouter, dataProvider.alertRouter) // mock until Phase 3
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
