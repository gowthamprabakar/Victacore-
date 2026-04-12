---
description: "Wave 1 Foundation task list — C02 + C01 + C14"
---

# Tasks: VitaCore Wave 1 Foundation

**Input:** `specs/001-vitacore-wave1-foundation/` (spec.md, plan.md)
**Constitution:** `.specify/memory/constitution.md` v1.0.0

Task IDs are stable. `[P]` = parallelisable with other `[P]` tasks in the same phase. `[DONE]` = completed. `[BLOCKED]` = waiting on prior task or external gate. File paths are relative to project root `/Users/prabakarannagarajan/VISTACORE Healthcare /VitaCore/`.

---

## Phase W0 — Wave 0 Infrastructure PoCs (HISTORICAL, CLOSED)

- **T001 [DONE]** VitaCoreGraph Swift package scaffolded with GRDB 7.10 dependency
  - File: `Packages/VitaCoreGraph/Package.swift`
  - Satisfies: FR-001, FR-007
- **T002 [DONE]** GRDB schema migrator + Reading/Episode row types + indices
  - File: `Packages/VitaCoreGraph/Sources/VitaCoreGraph/Schema.swift`, `ReadingRow.swift`, `EpisodeRow.swift`
  - Satisfies: FR-002, FR-003
- **T003 [DONE]** `GRDBGraphStore` conforming to `GraphStoreProtocol` (10 methods)
  - File: `Packages/VitaCoreGraph/Sources/VitaCoreGraph/GRDBGraphStore.swift`
  - Satisfies: FR-001 through FR-005, FR-007
- **T004 [DONE]** `GRDBGraphStore.defaultStore()` factory → `Application Support/VitaCore/vitacore.sqlite`
  - File: `Packages/VitaCoreGraph/Sources/VitaCoreGraph/GRDBGraphStore+Default.swift`
  - Satisfies: FR-006, FR-007
- **T005 [DONE]** 8 unit tests for GRDBGraphStore (round-trip, range, aggregate, snapshot, episodes, type filter, purge, in-memory factory)
  - File: `Packages/VitaCoreGraph/Tests/VitaCoreGraphTests/GRDBGraphStoreTests.swift`
  - Satisfies: SC-008 (partially)
- **T006 [DONE]** VitaCoreInference package scaffolded with mlx-swift-examples 2.29.1 dependency
  - File: `Packages/VitaCoreInference/Package.swift`
- **T007 [DONE]** `Gemma4Runtime` actor with `load()` + streaming `generate(prompt:image:maxTokens:)` via `VLMModelFactory`
  - File: `Packages/VitaCoreInference/Sources/VitaCoreInference/Gemma4Runtime.swift`
- **T008 [DONE]** 7 unit tests for Gemma4Runtime (initial state, load errors, quantisation mapping, multimodal signature, unsupported flag)
  - File: `Packages/VitaCoreInference/Tests/VitaCoreInferenceTests/Gemma4RuntimeTests.swift`
- **T009 [DONE]** Metal Toolchain installed via `xcodebuild -downloadComponent MetalToolchain`
  - External: Xcode 26 component
- **T010 [DONE]** iOS app builds + links VitaCoreInference, launches on iPhone 17 Pro simulator
  - Satisfies: SC-008 (partially)
- **T011 [DONE]** VitaCoreSynthetic package with SplitMix64 `SeededGenerator`
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/SeededGenerator.swift`
- **T012 [DONE]** `PersonaArchetype` enum + 4 trait profiles (T1D pump, T2D oral/basal, prediabetic, healthy optimizer)
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/PersonaArchetype.swift`
- **T013 [DONE]** `GlucoseGenerator` (diurnal + dawn + gamma meal response + exercise dips + Bernoulli hypos + Gaussian noise)
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/Generators/GlucoseGenerator.swift`
- **T014 [DONE]** Secondary generators (Meal, FoodLog, HeartRate, Step, Sleep, BP, Weight)
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/Generators/SecondaryGenerators.swift`
- **T015 [DONE]** `EpisodeLabeler` producing ground-truth `Episode` records from reading streams
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/EpisodeLabeler.swift`
- **T016 [DONE]** `CohortBuilder.buildCohort(archetype:days:endingAt:seed:) → SyntheticCohort` + `write(to: GraphStoreProtocol)`
  - File: `Packages/VitaCoreSynthetic/Sources/VitaCoreSynthetic/CohortBuilder.swift`
  - Satisfies: US-07
- **T017 [DONE]** 7 cohort builder tests (determinism, seed divergence, persona range sanity, T1D episode presence, GRDB round-trip, labeler agreement)
  - File: `Packages/VitaCoreSynthetic/Tests/VitaCoreSyntheticTests/CohortBuilderTests.swift`
  - Satisfies: US-07, SC-007 (partially)
- **T018 [DONE]** `DEMO_MODE` build-flag seeder in `VitaCoreApp.init` (first-launch, UserDefaults guard)
  - File: `VitaCoreApp/VitaCoreApp.swift`
- **T019 [DONE]** End-to-end verified on iPhone 17 Pro sim: 5694 readings + 88 episodes persisted to `vitacore.sqlite`
  - Satisfies: SC-008

## Phase W1-S1.1 — C01 PersonaEngine (COMPLETED WITH OUTSTANDING FINDINGS)

- **T020 [DONE]** VitaCorePersona package scaffolded with GRDB 7.10 + VitaCoreGraph + VitaCoreSynthetic (test-only) deps
  - File: `Packages/VitaCorePersona/Package.swift`
- **T021 [DONE]** `PersonaMigrator` + `persona_context` single-row schema + `PersonaContextRow` binding
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/Schema.swift`
  - Satisfies: FR-011
- **T022 [DONE]** `GRDBPersonaStore` actor with `DatabaseWriter` abstraction (DatabasePool for file, DatabaseQueue for in-memory)
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/GRDBPersonaStore.swift`
  - Satisfies: FR-011
- **T023 [DONE]** `PersonaInferencer` with rule-based glucose classifier + BP hypertension tie-breaker + context synthesiser
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: FR-012, FR-013
- **T024 [DONE]** `VitaCorePersonaEngine` conforming to `PersonaEngineProtocol` (10 methods)
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/VitaCorePersonaEngine.swift`
  - Satisfies: FR-010
- **T025 [DONE]** 10 unit tests (round-trip, empty store, 4 synthetic cohort classifications, empty-graph baseline, engine bootstrap+persist, updateGoal, med mutations)
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/VitaCorePersonaEngineTests.swift`
  - Satisfies: FR-013, SC-001
- **T026 [DONE]** Wire `VitaCorePersonaEngine` into `VitaCoreApp` replacing `MockDataProvider.personaEngine`
  - File: `VitaCoreApp/VitaCoreApp.swift`
  - Satisfies: FR-010
- **T027 [DONE]** iOS app builds + launches with real persona engine, `vitacore_persona.sqlite` created on disk, T1D condition inferred from synthetic cohort
  - Satisfies: SC-008
- **T028 [DONE]** Devil-critic review of Sprint 1.1 C01 — surfaced 6 Critical, 7 High, 9 Medium, 4 Low findings

## Phase W1-S1.1-CLEANUP — Fix Critical + High devil-critic findings (CURRENT PRIORITY)

Per constitution Quality Gate #4, Critical findings block wave progression. These tasks are prerequisites for Sprint 1.2.

- **T030** Fix **C1** — empty-graph locks healthy forever. Add data-adequacy gate (≥ 3 glucose/day × ≥ 7 days OR ≥ 1 CGM source); return transient in-memory healthy default until gate crossed; re-run inferencer on subsequent `getPersonaContext()` calls until persisted.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`, `VitaCorePersonaEngine.swift`
  - Satisfies: FR-014, US-02, EC-05
- **T031** Fix **C2** — bootstrap race. Move `loadContext → inferContext → saveContext` into a single `GRDBPersonaStore.bootstrapIfNeeded(inferencer:graphStore:)` actor-isolated method. Remove bootstrap logic from engine.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/GRDBPersonaStore.swift`, `VitaCorePersonaEngine.swift`
  - Satisfies: FR-015, US-03
- **T032** Fix **C3** — read-modify-write race on mutations. Add `GRDBPersonaStore.mutate(_ transform: (PersonaContext) -> PersonaContext) async throws` actor method; rewrite `updateGoal`, `addMedication`, `removeMedication` on the engine to call it.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/GRDBPersonaStore.swift`, `VitaCorePersonaEngine.swift`
  - Satisfies: FR-016, US-04
- **T033** Fix **C4** — unit drift (mmol/L → false T1D). Normalise every `Reading.value` to mg/dL by inspecting `Reading.unit` in `PersonaInferencer.classifyGlucose(readings:)`. Reject readings whose unit is unrecognised.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: FR-017, EC-01
- **T034** Fix **C5** — fresh UUID per bootstrap. Add `VitaCoreInstallIdentity` helper that reads/writes a stable `UUID` to the iOS Keychain (survives reinstall). Inferencer uses it instead of `UUID()`.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/InstallIdentity.swift` (NEW)
  - Satisfies: FR-018, EC-06
- **T035** Fix **C6** — JSON decode failure on schema drift. Add `blob_version INTEGER` column; wrap decode in try/catch; on failure log + delete row + re-bootstrap.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/Schema.swift`, `GRDBPersonaStore.swift`
  - Satisfies: FR-019, EC-08
- **T036** Fix **H1** — empty `thresholdOverrides`. `PersonaInferencer.synthesiseContext(...)` emits archetype-specific threshold overrides (T1D: glucose lower 70, upper 180; T2D: glucose lower 70, upper 180; prediabetic: glucose upper 140; healthy: glucose upper 140).
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: FR-021
- **T037** Fix **H1 / goalProgress** — populate `goalProgress` alongside `activeGoals` in synthesised context so Home Dashboard goal cards render.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: FR-022
- **T038** Fix **H2** — duplicate-source double counting. Dedup readings on `(timestamp rounded to 1s, metricType, round(value, 1))` OR require single preferred source before classification.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: EC-02
- **T039** Fix **H5** — persona SQLite file protection. Apply `NSFileProtectionCompleteUnlessOpen` to `.sqlite`, `-wal`, `-shm` after `DatabasePool` creation. Match `VitaCoreGraph` pattern.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/GRDBPersonaStore.swift`
  - Satisfies: FR-020
- **T040** Fix **H6** — sensor-glitch hypo. Require `hypoCount >= 2` AND `Reading.confidence >= 0.8` in Rule 1 of `classifyGlucose`.
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: EC-03
- **T041** Fix **H3** — minimum sample-size gate (ties into T030 data-adequacy gate).
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/PersonaInferencer.swift`
  - Satisfies: EC-05
- **T042 [P]** Add concurrency tests: N parallel `getPersonaContext()` on empty store → exactly one row; N parallel `addMedication` → all meds present.
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/ConcurrencyTests.swift` (NEW)
  - Satisfies: SC-002
- **T043 [P]** Add schema-drift test: write v1 blob, load with v2 decoder, assert re-bootstrap.
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/SchemaDriftTests.swift` (NEW)
  - Satisfies: SC-003
- **T044 [P]** Add unit-drift test: cohort with mmol/L readings → classifier produces healthy (not T1D).
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/UnitDriftTests.swift` (NEW)
  - Satisfies: SC-004
- **T045 [P]** Add file-protection audit: after `defaultStore()`, assert `NSFileProtectionCompleteUnlessOpen` on `.sqlite` + `-wal` + `-shm`.
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/FileProtectionTests.swift` (NEW)
  - Satisfies: SC-005
- **T046** Re-run devil-critic on patched Sprint 1.1 — zero Critical findings required before Sprint 1.2 kickoff.
  - Gate: Quality Gate #4
  - Satisfies: SC-009

## Phase W1-S1.2 — C14 ThresholdEngine (NEXT SPRINT)

- **T050** Scaffold `VitaCoreThreshold` Swift package with `VitaCoreContracts` + `VitaCorePersona` + `VitaCoreGraph` deps (test-only on graph)
  - File: `Packages/VitaCoreThreshold/Package.swift` (NEW)
  - Satisfies: FR-030
- **T051** Define `ThresholdEngineProtocol` in `VitaCoreContracts` with `resolveActiveThresholdSet(userId:)` method
  - File: `Packages/VitaCoreContracts/Sources/VitaCoreContracts/Protocols/ThresholdEngineProtocol.swift` (NEW)
  - Satisfies: FR-030
- **T052** Implement 5 core condition profiles (`HEALTHY_BASELINE`, `TYPE1_DIABETES`, `TYPE2_DIABETES`, `HYPERTENSION`, `CARDIAC_RISK`) as static `ThresholdSet` constants
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/ConditionProfiles.swift` (NEW)
  - Satisfies: FR-031
- **T053** Implement priority stack resolver (clinician > critical safety > tighter condition > goal > medication > age > population)
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/PriorityStackResolver.swift` (NEW)
  - Satisfies: FR-032, US-06
- **T054** Implement medication modifiers for `BETA_BLOCKER`, `INSULIN`, `ACE_INHIBITOR`
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/MedicationModifiers.swift` (NEW)
  - Satisfies: FR-033
- **T055** Implement `VitaCoreThresholdEngine` class conforming to `ThresholdEngineProtocol` with 60 s TTL in-memory cache + mutation invalidation
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/VitaCoreThresholdEngine.swift` (NEW)
  - Satisfies: FR-030, FR-034, FR-037
- **T056** Consume `PersonaContext.thresholdOverrides` — user/clinician overrides win over all computed bands
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/VitaCoreThresholdEngine.swift`
  - Satisfies: FR-037
- **T057** Emit `ThresholdOverride` episodes to graph via `writeEpisode(...)` as audit trail
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/VitaCoreThresholdEngine.swift`
  - Satisfies: FR-035
- **T058 [P]** Unit tests for each of the 5 condition profiles (range sanity, correct priority ordering)
  - File: `Packages/VitaCoreThreshold/Tests/VitaCoreThresholdTests/ConditionProfilesTests.swift` (NEW)
  - Satisfies: FR-031, SC-006
- **T059 [P]** Priority stack tests (T2D + Hypertension → tighter glucose band; multi-condition edge cases)
  - File: `Packages/VitaCoreThreshold/Tests/VitaCoreThresholdTests/PriorityStackTests.swift` (NEW)
  - Satisfies: FR-032, US-06
- **T060 [P]** Medication modifier tests (BETA_BLOCKER lowers HR targets; INSULIN raises hypo priority)
  - File: `Packages/VitaCoreThreshold/Tests/VitaCoreThresholdTests/MedicationModifierTests.swift` (NEW)
  - Satisfies: FR-033
- **T061 [P]** Cohort tests — resolve thresholds for all 4 `VitaCoreSynthetic` personas, verify ranges make sense
  - File: `Packages/VitaCoreThreshold/Tests/VitaCoreThresholdTests/CohortThresholdsTests.swift` (NEW)
  - Satisfies: US-07, SC-006
- **T062** Cache P95 latency benchmark (target <50 ms cached, <200 ms uncached)
  - File: `Packages/VitaCoreThreshold/Tests/VitaCoreThresholdTests/LatencyTests.swift` (NEW)
  - Satisfies: FR-036
- **T063** Wire `VitaCoreThresholdEngine` into `VitaCoreApp` as `.environment(\.thresholdEngine, ...)` (protocol needs to exist in `VitaCoreContracts` first)
  - File: `VitaCoreApp/VitaCoreApp.swift`, `project.yml`
  - Satisfies: SC-008
- **T064** Regenerate Xcode project + iOS build + launch + verify `ThresholdSet` visible in debugger for synthetic T1D cohort
  - Satisfies: SC-008
- **T065** Devil-critic review of Sprint 1.2 C14 — zero Critical required before Sprint 1.3 kickoff
  - Satisfies: SC-009, Quality Gate #4

## Phase W1-S1.3 — DEFERRED (semantic search scaffold moved to Wave 2+)

No tasks. See plan.md Phase C.

## Phase W1-S1.4 — C01 PersonaEngine Completion

- **T070** `ResponseProfile` entity with 10-sample-minimum activation gate
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/ResponseProfile.swift` (NEW)
- **T071** Allergen semantic map — peanut → [groundnut, satay, peanut butter, arachis oil]
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/AllergenSemanticMap.swift` (NEW)
- **T072** `PreferenceProfile` notification quiet hours wire-up (end-to-end from Settings UI to alert suppression path — stub until C09 exists)
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/VitaCorePersonaEngine.swift`
- **T073** `getResponseProfileForContext(userId:relevantMetrics:)` accessor for future C18 consumption
  - File: `Packages/VitaCorePersona/Sources/VitaCorePersona/VitaCorePersonaEngine.swift`

## Phase W1-S1.5 — C14 ThresholdEngine Completion

- **T080** Remaining 12 condition profiles (PREDIABETES, HYPERTENSION_S2, HEART_FAILURE, ELDERLY_65_PLUS, HYPOTHYROIDISM, HYPERTHYROIDISM, CKD, COPD, OBESITY, PCOS, IRON_DEFICIENCY, VITAMIN_D_DEFICIENCY)
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/ConditionProfiles.swift`
- **T081** Medication modifier registry expansion — 8 drug classes total (add STATIN, SGLT2_INHIBITOR, GLP1_AGONIST, DIURETIC, SULFONYLUREA)
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/MedicationModifiers.swift`
- **T082** Composite rule scaffolding as Swift types (PostMealSpike, HypoTrajectory, DehydrationGlucose, MorningBPSurge, ElderlyOrthostatic, HeartFailureFluidOverload, ExtendedInactivity)
  - File: `Packages/VitaCoreThreshold/Sources/VitaCoreThreshold/CompositeRules.swift` (NEW)

## Phase W1-S1.6 — Wave 1 Integration + Exit Gate

- **T090** Full Wave 1 integration test: create persona via inferencer → add condition via `updatePersonaContext` → verify threshold engine writes thresholds → query resolved set → add medication → verify thresholds modified → revoke condition → verify re-resolved
  - File: `Packages/VitaCorePersona/Tests/VitaCorePersonaTests/Wave1IntegrationTests.swift` (NEW)
  - Satisfies: FR-040, SC-007
- **T091** Data retention policy — 90-day raw reading pruning scheduled job (stub for now; scheduled task ownership is Wave 4 BackupEngine)
  - File: `Packages/VitaCoreGraph/Sources/VitaCoreGraph/GRDBGraphStore.swift`
- **T092** Wave 1 exit gate — devil-critic full re-review, constitution compliance check via `/speckit-analyze`, all SCs satisfied
  - Satisfies: SC-001 through SC-009

---

## Summary

- **Total tasks:** 73
- **Completed:** 29 (all of W0, all of W1-S1.1 except cleanup)
- **Current priority:** 17 tasks in W1-S1.1-CLEANUP (T030–T046) — BLOCKING Sprint 1.2
- **Pending Sprint 1.2 (C14):** 16 tasks (T050–T065)
- **Pending Sprint 1.4 (C01 completion):** 4 tasks (T070–T073)
- **Pending Sprint 1.5 (C14 completion):** 3 tasks (T080–T082)
- **Pending Sprint 1.6 (integration + exit):** 3 tasks (T090–T092)

**Parallelisable work:** Tasks marked `[P]` can run in parallel within the same phase. Within W1-S1.1-CLEANUP, T042/T043/T044/T045 (the new test files) are all `[P]` and can be written simultaneously.

**Critical path:** T030 (data-adequacy gate) → T031 (bootstrap race) → T050 (C14 scaffold) → T055 (C14 engine) → T063 (app wire) → T090 (integration test).
