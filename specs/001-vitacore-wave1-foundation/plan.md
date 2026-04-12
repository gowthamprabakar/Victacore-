# Implementation Plan: VitaCore Wave 1 Foundation

**Branch:** `001-vitacore-wave1-foundation`
**Date:** 2026-04-11
**Spec:** `specs/001-vitacore-wave1-foundation/spec.md`
**Constitution:** `.specify/memory/constitution.md` v1.0.0

## Summary

Deliver the three Wave 1 foundation components (`C02 VitaCoreGraph`, `C01 PersonaEngine`, `C14 ThresholdEngine`) on top of which every other wave depends. C02 and C01 are already implemented (Wave 0 Sprint 0.1 and Wave 1 Sprint 1.1). C14 is next. Wave 1 also requires fixing six Critical and seven High findings from the Sprint 1.1 devil-critic review of C01 before it can be considered complete.

## Technical Context

### Language / Platform
- **Primary:** Swift 5.9, iOS 17.0 deployment target (iOS 26.2 SDK used during development)
- **Minimum device:** iPhone 15 Pro (A17 Pro, 8 GB RAM). Older devices unsupported.
- **Build:** xcodegen 2.x generates `VitaCore.xcodeproj` from `project.yml`. `xcodebuild -scheme VitaCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` is the canonical build command.
- **Package manager:** Swift Package Manager (local packages under `Packages/`, external packages pinned in each package's `Package.swift`).

### Architecture / Stack

VitaCore is composed of local Swift packages under `Packages/`. Each package is a component. Packages communicate only through protocols declared in `VitaCoreContracts`.

**Locked architecture (per constitution AD-01 through AD-12):**

| Layer | Technology | Package(s) | Status |
|---|---|---|---|
| Contracts | Pure Swift protocols + value types | `VitaCoreContracts` | LOCKED (frozen) |
| Graph store | GRDB.swift 7.10+ over SQLite (custom nodes/edges/readings/episodes schema, recursive-CTE multi-hop traversal) | `VitaCoreGraph` | IMPLEMENTED (Wave 0 Sprint 0.1) |
| LLM runtime | MLX-Swift via `VLMModelFactory` (mlx-swift-examples 2.29.1+), target `mlx-community/gemma-3n-E4B-it-4bit` via MLXVLM (interim, until mlx-swift-examples ships `gemma4` arch) | `VitaCoreInference` | POC IMPLEMENTED (Wave 0 Sprint 0.2), not wired into Wave 1 flow |
| Synthetic substrate | Swift package, SplitMix64 RNG, 4 personas, physiological generators, `EpisodeLabeler`, `CohortBuilder` | `VitaCoreSynthetic` | IMPLEMENTED (Wave 0 Sprint 0.3) |
| Persona | GRDB/SQLite (own DB file), rule-based inferencer, protocol conformance | `VitaCorePersona` | IMPLEMENTED (Wave 1 Sprint 1.1) with 6 Critical + 7 High findings outstanding |
| Threshold | Rule-based resolver over `PersonaContext` → `ThresholdSet`, 60 s cache | `VitaCoreThreshold` | NOT YET IMPLEMENTED (Wave 1 Sprint 1.2) |
| Design system | SwiftUI + custom glass tokens, ethereal-light palette | `VitaCoreDesign` | IMPLEMENTED (frontend sprints pre-Wave 0) |
| Navigation | SwiftUI NavigationStack + TabRouter | `VitaCoreNavigation` | IMPLEMENTED |
| Mock layer | Fake implementations of every protocol for UI preview + tests | `VitaCoreMock` | IMPLEMENTED (being replaced wave-by-wave) |

**Explicitly forbidden (per constitution):** PythonKit, Graphiti Python, Neo4j, cloud LLM inference, cloud analytics with PHI.

### Data Model References

Canonical types live in `Packages/VitaCoreContracts/Sources/VitaCoreContracts/Models/`:

- `Reading` (id, metricType, value, unit, timestamp, sourceSkillId, confidence, trendDirection, trendVelocity)
- `Episode` (id, episodeType, sourceSkillId, sourceConfidence, referenceTime, ingestionTime, payload)
- `PersonaContext` (userId, activeConditions, activeGoals, activeMedications, allergies, preferences, responseProfiles, thresholdOverrides, dataQualityFlags, goalProgress)
- `ThresholdSet` (per-metric bands: safe/watch/alert/critical)
- `MetricType` enum (15 metric types, unit + icon + displayName)
- `EpisodeType` enum (23 types: healthkitSteps, cgmGlucose, bpReading, nutritionEvent, etc.)
- `ConditionKey` enum (17 conditions: type1/type2/prediabetes, hypertension, cardiacRisk, elderly65Plus, etc.)
- `GoalType` enum (14 types: glucoseA1C, timeInRange, stepsDaily, weightTarget, etc.)
- `MedicationClass` enum (14 classes: metformin, insulin, betaBlocker, aceInhibitor, statin, etc.)

All types are `Sendable`, `Codable`, `Hashable`, value types. No classes, no inheritance.

### Storage Topology

Each persisted-state component owns its own SQLite file (constitution Principle III):

| Component | File | Status |
|---|---|---|
| `VitaCoreGraph` | `Application Support/VitaCore/vitacore.sqlite` (+ `-wal`, `-shm`) | Live on-device, file-protection attribute set |
| `VitaCorePersona` | `Application Support/VitaCore/vitacore_persona.sqlite` (+ `-wal`, `-shm`) | Live on-device, **file-protection attribute NOT YET set** (H5) |
| `VitaCoreThreshold` | TBD — likely no own file; computes from `PersonaContext` on demand with in-memory cache | NOT YET BUILT |
| `VitaCoreInference` | Weight cache under `Application Support/VitaCore/models/` (one-time download) | POC, not wired |

Forbidden: shared tables, foreign keys spanning files, cross-component SQL queries.

### Concurrency Model

- **Actors** guard every persistent store (`GRDBGraphStore`, `GRDBPersonaStore`, future `GRDBThresholdCache` if needed).
- **Read-modify-write mutations MUST be atomic** within a single actor method. The current `VitaCorePersonaEngine` mutation methods (`updateGoal`, `addMedication`, `removeMedication`) do read-modify-write across actor boundaries and are subject to lost-update races (devil-critic C3). Wave 1 Sprint 1.1 cleanup fixes this before closing the wave.
- **Bootstrap serialisation:** first-read bootstrap of an empty persona store MUST hold a lock across `loadContext → inferContext → saveContext`. Currently a race is possible (devil-critic C2). Same cleanup sprint.

### Performance Budgets

Per constitution Principle VII (iPhone 15 Pro minimum) and component spec docs:

| Operation | Target | Source |
|---|---|---|
| `getLatestReading(metricType)` | <20 ms P99 | C02 spec |
| `getRangeReadings(metricType, from, to)` | <80 ms P95 | C02 spec |
| `getAggregatedMetric(...)` | <100 ms P95 | C02 spec |
| `getCurrentSnapshot()` | <150 ms P95 (15 parallel reads) | C02 spec |
| `getPersonaContext()` (cached) | <50 ms P95 | C01 spec + FR-036 analog |
| `getPersonaContext()` (cold) | <200 ms P95 | C01 spec |
| `resolveActiveThresholdSet(userId)` | <50 ms P95 cached, <200 ms P95 uncached | C14 spec, FR-036 |
| `PersonaContext` compressed size (for Gemma 4 prompt injection) | <2,000 tokens | C01 spec |
| Gemma 3n/4 E4B model load | <30 s first boot, <5 s warm reload | C10 spec analog |
| Gemma 3n/4 E4B inference (text, 128 tokens) | <4 s on A17 Pro | C10 spec, Wave 0 Sprint 0.2 benchmarks pending |

### Phases (Wave 1 Scope Only)

**Phase A — Wave 1 Sprint 1.1 cleanup (CURRENT)**
Fix the 6 Critical + 7 High devil-critic findings from C01 Sprint 1.1 before starting C14. Adds ~10 new tests (concurrency, schema drift, unit drift, stable identity, file protection, data-adequacy gate). No new components built.

**Phase B — Wave 1 Sprint 1.2: C14 ThresholdEngine**
Build `VitaCoreThreshold` package. Deliverables match the Functional Requirements FR-030 through FR-037. Wire into `VitaCoreApp` replacing any placeholder threshold resolution. Tests against all 4 `VitaCoreSynthetic` cohorts.

**Phase C — Wave 1 Sprint 1.3: Semantic search scaffold (DEFERRED)**
The original sprint plan had semantic search in Sprint 1.3 (MiniLM-L6 + cosine similarity). This is **deferred to Wave 2 or later** because the current GRDB pivot makes Cypher-based graph traversal irrelevant, and semantic search on `Episode.payload` is not a Wave 1 dependency for any downstream component. Re-introduce when a consumer (C19 Analytics, C11 Conversation) actually needs it.

**Phase D — Wave 1 Sprint 1.4: PersonaEngine Completion**
Complete persona features that Sprint 1.1 deferred: `ResponseProfile` (min 10 samples before activation), allergen semantic map, `PreferenceProfile` with notification quiet hours wire-up, `getResponseProfileForContext(...)` accessor.

**Phase E — Wave 1 Sprint 1.5: ThresholdEngine Completion**
Remaining 12 condition profiles in C14 (prediabetes through heart_failure), medication modifier registry (8 drug classes), composite rule scaffolding (PostMealSpike, HypoTrajectory, etc. as Swift types — evaluated against graph readings).

**Phase F — Wave 1 Sprint 1.6: Integration + Phase Exit**
Full Wave 1 integration test suite per FR-040. Data retention policy (90-day raw pruning, 180-day conversation). Wave 1 devil-critic re-review. Wave 1 exit gate passed → proceed to Wave 2.

### Technical Constraints

1. **No git repo yet.** The VitaCore project is not under git version control (confirmed by environment detection during Spec Kit install). All source lives on local filesystem only. This is an explicit pre-commercial choice — add git when the project goes to its first external collaborator or TestFlight.
2. **No CI.** All tests run locally via `swift test` per-package and via `xcodebuild build` for the app target. CI pipeline is a post-MVP concern.
3. **No Xcode project check-in.** `VitaCore.xcodeproj` is generated from `project.yml` by xcodegen; regenerate after any `project.yml` or `Package.swift` change.
4. **Metal Toolchain required.** Xcode 26 split the Metal Toolchain into a separately-downloadable component (`xcodebuild -downloadComponent MetalToolchain`). Installed in Wave 0 Sprint 0.2. Required for `VitaCoreInference` package to link into the iOS binary.
5. **DEMO_MODE build flag.** Synthetic cohort seeding is guarded by `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEMO_MODE`. Production builds do not compile the seeder. Controlled via `xcodebuild ... SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG DEMO_MODE'`.
6. **Privacy-first constitution enforces no-cloud-LLM.** Any task or code review that proposes a cloud inference call is auto-rejected.
7. **No new UI work in Wave 1.** Wave 1 is backend-only. UI changes are limited to wiring existing screens to replace mock providers with real ones.
8. **iPhone 15 Pro RAM budget.** Combined on-device footprint (graph SQLite + persona SQLite + loaded Gemma model + SwiftUI runtime + HealthKit observers) must fit under 8 GB with ≥ 1 GB headroom for iOS.

### Dependency Graph (Wave 1 Components)

```
VitaCoreContracts (zero deps)
  └── VitaCoreGraph (contracts + GRDB)
        └── VitaCoreSynthetic (contracts; uses VitaCoreGraph in tests only)
              └── VitaCorePersona (contracts + GRDB; uses VitaCoreGraph + Synthetic in tests)
                    └── VitaCoreThreshold (contracts + VitaCorePersona reads; NOT BUILT)
```

Circular dep risk identified in Sprint 1.1 devil-critic M6: `PersonaInferencer` currently reads raw `Reading`s from `GraphStoreProtocol`. If a future version of the inferencer reads `Episode`s (written by C14 ThresholdEngine), a feedback loop emerges. **Locked rule:** the inferencer reads only raw readings, never episodes. Enforced via test + code review.
