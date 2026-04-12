# VitaCore Constitution

**Project:** VitaCore — Privacy-first on-device AI health intelligence for iOS
**Version:** 1.0.0
**Ratified:** 2026-04-11
**Last Amended:** 2026-04-11
**Source:** `VITACORE_IDEOLOGY_v2.0.docx` + locked architectural decisions AD-01 through AD-10 from `VITACORE_SPRINT_PLAN_v2.0.md`

---

## Core Principles

### I. Privacy First, On-Device Always (NON-NEGOTIABLE)

VitaCore MUST run all inference, classification, rule evaluation, and decision logic on the user's device. Personal Health Information (PHI) — conditions, medications, glucose readings, heart rate, sleep, allergies, personal identifiers — MUST NOT cross the network boundary during normal operation.

Permitted network touchpoints (exhaustive list):
- **Initial model weight download** from HuggingFace / Apple-hosted CDN, one-time, user-gated with explicit consent, over Wi-Fi only by default. Weights cached in app sandbox; inference is offline thereafter.
- **OAuth handshakes** for source connectors (Dexcom, Fitbit, Withings, Whoop, Oura) that push data *into* the device. The handshake itself transmits no PHI; data flows inbound only.
- **App Store updates** through Apple's standard channel.

Forbidden:
- Cloud LLM inference (OpenAI, Anthropic, Google — remote). All LLM calls MUST use the on-device `Gemma4Runtime` (Gemma 4 E4B target; Gemma 3n E4B interim until MLX upstream ships gemma4 architecture support).
- Transmitting raw readings, persona context, food photos, voice logs, or conversation turns to any remote service.
- Cloud-based analytics, error reporting, or crash telemetry that includes PHI-adjacent data.
- Any third-party SDK that phones home with user-identifying payloads.

This principle supersedes convenience, speed, and feature completeness. When in doubt, prefer the on-device path even at the cost of a larger app binary or slower first-launch.

### II. Frozen Interface Contracts, Evolving Implementations (NON-NEGOTIABLE)

Before any component implementation begins, three interface contracts MUST be frozen and MUST NOT change except through a constitutional amendment:

1. **VitaCoreGraph storage API** — `GraphStoreProtocol` (write/read readings + episodes, range queries, aggregations, snapshots, purges)
2. **PersonaContext schema** — `PersonaContext` struct (conditions, goals, medications, allergies, preferences, response profiles, threshold overrides, data-quality flags, goal progress)
3. **InferenceRequest + PrescriptionCard** — the payload shape between `HeartbeatEngine` → `Gemma4Runtime` → `MiroFishEngine` → `AlertRouter`

Implementations below the contract line are free to pivot. The *original* plan specified Kuzu for the graph store; reality pivoted to GRDB/SQLite (`VitaCoreGraph` package) when upstream kuzu-swift was archived. This pivot was permitted precisely BECAUSE the frozen contract is `GraphStoreProtocol`, not "Kuzu". Similar rule: Gemma 4 E4B is the target, but the runtime MAY substitute Gemma 3n E4B via MLXVLM until upstream `mlx-swift-examples` ships a `gemma4` architecture module.

### III. Component Ownership of Storage

Each component that owns persistent state owns its own SQLite file. `VitaCoreGraph` owns `vitacore.sqlite`. `VitaCorePersona` owns `vitacore_persona.sqlite`. Future components (`VitaCoreInference` model cache, `BackupEngine`, `ExportEngine`) extend the same pattern.

Rationale: independent purgeability (one component's corruption is not the whole app's corruption), independent testability (each package tests its store in isolation), and clean decoupling (no cross-table joins means no schema-coupled migrations).

Forbidden: shared tables across components, foreign keys spanning SQLite files, cross-component SQL queries. Components talk through protocol interfaces, not shared database rows.

### IV. Protocol-Driven Wave Execution

Components ship in waves. Each wave freezes its contracts and delivers working protocol implementations before the next wave begins:

- **Wave 0 — Infrastructure PoCs:** Graph store (Sprint 0.1), LLM runtime (Sprint 0.2), synthetic data (Sprint 0.3). Must prove the platform can host the component before the component is built.
- **Wave 1 — Foundation:** `C02 VitaCoreGraph`, `C14 ThresholdEngine`, `C01 PersonaEngine`. The three bedrock components.
- **Wave 2 — Skills layer:** `C03 SkillBus`, `C04 HealthKitSkill`, `C06 CGMSkill`, `C07 BPSkill`, `C05 FitbitSkill`, `C08 ManualEntrySkills`, `C20 DataConnectors`, Shell-Lite onboarding UI.
- **Wave 3 — Intelligence + Monitoring:** `C10 Gemma4Runtime`, `C09 HeartbeatEngine`, `C18 MiroFishEngine`, `C11 ConversationEngine`, `C12 FoodVisionPipeline`, `C19 AnalyticsIntelligenceEngine`.
- **Wave 4 — Alert Delivery + Data Ops:** `C13 AlertRouter`, `C16 BackupEngine`, `C17 ExportEngine`.
- **Wave 5 — Full UI:** `C15 SwiftUIShell`.

Waves MUST be executed in dependency order. Within a wave, components that share no dependencies MAY be parallelised. The dependency graph is captured in `VITACORE_SPRINT_PLAN_v2.0.md` under "Dependency Graph (Post-Override)".

### V. Test Against Real Data Substrates (NON-NEGOTIABLE)

Every component that reads, writes, or reasons about health data MUST be tested against realistic multi-persona, multi-metric, multi-timestamp synthetic cohorts produced by `VitaCoreSynthetic`. Mock-in-a-box tests that return canned single values are permitted only for pure-function unit tests.

The four locked personas are: **T1D on pump + CGM**, **T2D on oral ± basal insulin**, **Prediabetic / metabolic syndrome**, **Healthy optimizer on Apple Watch**. Anything past Wave 1 MUST run its test suite against all four cohorts.

Rationale: VitaCore's correctness is fundamentally statistical. Classification rules, threshold detection, episode labelling, persona inference, and agent prompting all depend on realistic signal distributions. Testing on mocks gives false confidence and mis-classifies real users in production (see Sprint 1.1 devil-critic finding C4: unit drift → false T1D diagnosis).

### VI. Safety Before Completeness

Patient-safety-critical decisions MUST be conservative by default:

- **Thresholds default to the tighter value.** A user with both T1D and Hypertension inherits the tighter of both threshold sets, not the looser.
- **Inference outputs are framed as "patterns" and "insights", not "medical advice".** C10 Gemma4Runtime system prompts MUST enforce this framing at turn 1, 5, and 20 via hardcoded safety constraints (adversarial prompt test suite required).
- **Fast-path hypo/irregular-heartbeat alerts bypass all batching.** A glucose < 70 or an irregular pulse flag MUST reach the user with no more than one cycle of delay, even if the full AlertRouter is not yet deployed (use a fast-path stub during wave transitions).
- **Unknown archetype = healthy baseline with broad safe ranges.** When the inferencer has insufficient data it MUST NOT guess a diabetic classification; but it also MUST NOT lock the user into a persona silently — it MUST re-run the inferencer whenever new graph data crosses the data-adequacy threshold.

### VII. Minimum Device Floor

VitaCore targets **iPhone 15 Pro (A17 Pro, 8 GB RAM)** as the minimum supported device. Older devices are unsupported. This is non-negotiable because Gemma 4 E4B INT4 (~2.5–4 GB loaded) plus the graph store, persona store, SwiftUI UI, HealthKit observers, and background tasks require 8 GB headroom.

### VIII. FDA Framing (Until Cleared Otherwise)

Until VitaCore has an explicit FDA clearance or enforcement-discretion letter, all user-facing language in alerts, prescription cards, chat responses, and exports MUST use wellness framing ("pattern", "insight", "suggestion", "consider") rather than medical framing ("diagnosis", "treatment", "prescription"). Alert urgency uses Apple's `.timeSensitive` class, not `.critical` (which Apple reserves for FDA-cleared medical devices per AD-05).

---

## Architectural Decisions (Locked)

The following decisions are ratified as part of this constitution and are changed only by constitutional amendment, not by sprint-level decisions:

| # | Decision | Status |
|---|---|---|
| AD-01 | Graph store implemented via `GraphStoreProtocol`. **Original target:** Kuzu (kuzu-swift). **Current implementation:** GRDB/SQLite with custom nodes/edges/readings/episodes schema and recursive-CTE multi-hop traversal (Wave 0 Sprint 0.1 pivot after kuzu-swift archival). **Forbidden:** PythonKit, Graphiti Python, Neo4j. | IMPLEMENTED |
| AD-02 | Minimum device: iPhone 15 Pro (A17 Pro, 8 GB). Older devices unsupported. | LOCKED |
| AD-03 | MiroFish = 1 LLM agent (`MetabolismAgent` via `Gemma4Runtime`) + 4 deterministic Swift agents (Muscle, Hydration, Recovery, Sleep), 3 trajectories (T0 baseline, T1 primary, T4 rest), T0 cached 15 min. Target: <10 s response. | LOCKED |
| AD-04 | Triple-path monitoring: HealthKit observer (primary, 1–5 min) + `BGAppRefreshTask` (absence checks, 15–30 min) + `UNNotificationRequest` (exact-time reminders). Event-driven alone is insufficient — absence-of-event rules are first-class. | LOCKED |
| AD-05 | Alert class: `.timeSensitive` (not `.critical`). Critical reserved for FDA-cleared devices. In-app CRITICAL experience (full-screen red modal, heavy haptic) unchanged. | LOCKED |
| AD-06 | HealthKit bridge is PRIMARY for Abbott Libre, Omron, Garmin. Direct API partnerships deferred to v1.1. | LOCKED |
| AD-07 | `C09 HeartbeatEngine` → Phase 3 (was Phase 4). | LOCKED |
| AD-08 | `C13 AlertRouter` → Phase 4 (was Phase 5). Fast-path stub handles alerts from C06/C07 in the Phase 2–3 gap. | LOCKED |
| AD-09 | Shell-Lite extracted from C15 → Phase 2. Onboarding + device pairing UI needed early. | LOCKED |
| AD-10 | FDA: fly under enforcement discretion. Wellness framing. Safety constraints in C10 enforced. Regulatory consultant review pre-launch. | LOCKED |
| AD-11 | **LLM runtime:** MLX-Swift via `VLMModelFactory` (mlx-swift-examples 2.29.1+). Interim target model: `mlx-community/gemma-3n-E4B-it-4bit` (full multimodal: text + vision + audio) via MLXVLM. Swap to `gemma-4-e4b-it-4bit` the moment `mlx-swift-examples` ships a `gemma4` architecture module. Metal Toolchain (Xcode 26 component) required for iOS linkage. | IMPLEMENTED (Wave 0 Sprint 0.2) |
| AD-12 | **Synthetic data substrate:** `VitaCoreSynthetic` Swift package with SplitMix64 seeded RNG, 4 persona archetypes, physiologically-grounded generators (glucose with circadian + dawn + gamma meal response + exercise dips + Bernoulli hypos + Gaussian noise), `EpisodeLabeler` for ground-truth oracle, `CohortBuilder.buildCohort(...)` → writes into any `GraphStoreProtocol`. | IMPLEMENTED (Wave 0 Sprint 0.3) |

---

## Quality Gates

Every wave MUST satisfy all of these before the next wave begins:

1. **Contracts frozen.** No protocol method signatures change after the sprint that introduces them.
2. **Unit tests.** Every new component has a `swift test` suite that runs in under 10 s and covers happy path, error paths, and at least one concurrency scenario.
3. **Synthetic-cohort tests.** Every component that reads or writes health data is tested against all four `VitaCoreSynthetic` personas.
4. **Devil-critic review.** Every component implementation passes a structured adversarial review before it is considered "done". Critical findings block; High findings require an explicit written acknowledgement and timeline.
5. **iOS build green.** `xcodebuild -scheme VitaCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` exits 0 after the sprint. A new package linking into the app is not "done" until the app builds and launches with it linked in.
6. **On-disk verification.** For any component that persists state, the wave exit criteria include locating the actual SQLite file on disk (or model cache, or export artefact) and inspecting its contents — not just relying on unit tests.

---

## Governance

- This constitution supersedes all sprint-level decisions, component spec doc claims, and prior plan documents (`VITACORE_SPRINT_PLAN_v2.0.md` and earlier versions). Where those documents conflict with the constitution, the constitution wins.
- Amendments require: (a) explicit rationale tied to a specific reality-forcing event (like the Kuzu archival), (b) a new AD-## entry in the "Architectural Decisions" table, (c) a version bump, and (d) an update to `MEMORY.md` memory index.
- `speckit-analyze` is the cross-artefact consistency check that MUST run before any new wave starts coding. Constitutional violations it flags are automatically CRITICAL and block wave kickoff.
- `devil-critic` is the component-level adversarial review that MUST run before marking any component "done".

**Version**: 1.0.0 | **Ratified**: 2026-04-11 | **Last Amended**: 2026-04-11
