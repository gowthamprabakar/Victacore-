# Feature Specification: VitaCore Wave 1 Foundation

**Feature:** `001-vitacore-wave1-foundation`
**Status:** Wave 0 complete; Wave 1 Sprint 1.1 (C01 PersonaEngine) implemented; Sprint 1.2 (C14 ThresholdEngine) next
**Version:** 0.1.0
**Owner:** Sole engineer, pre-commercial
**Source docs:** `VITACORE_IDEOLOGY_v2.0.docx`, `VITACORE_SPRINT_PLAN_v2.0.md`, `C01_PersonaEngine_v1.0.docx`, `C02_GraphitiStore_v1.0.docx`, `C14_ThresholdEngine_v1.0.docx`

---

## Overview / Context

VitaCore is a privacy-first on-device iOS health intelligence application. Wave 1 delivers the three foundation components on top of which every other wave depends:

- **C02 VitaCoreGraph** — the persistent, temporally-valid store of readings and episodes. Implemented in Wave 0 Sprint 0.1 as `VitaCoreGraph` package backed by GRDB/SQLite (pivoted from the original Kuzu target after kuzu-swift was archived).
- **C01 PersonaEngine** — the owner of the user's `PersonaContext` (conditions, goals, medications, allergies, preferences, threshold overrides, data-quality flags). Implemented in Wave 1 Sprint 1.1 as `VitaCorePersona` package with a graph-driven `PersonaInferencer` for first-launch bootstrap.
- **C14 ThresholdEngine** — the resolver of per-user metric bands (safe/watch/alert/critical) derived from the active persona's conditions and medications. **NOT YET IMPLEMENTED.** Scheduled for Wave 1 Sprint 1.2.

Wave 1's exit criterion: an authentic end-to-end path from a user's synthetic glucose reading in `VitaCoreGraph` → `PersonaInferencer` classification → `PersonaContext` persistence → `ThresholdEngine` resolution → a per-metric threshold set that the (future) `HeartbeatEngine` can consume.

## User Scenarios & Testing

### US-01 — First-launch bootstrap with existing HealthKit data [P1]

**Given** a user installs VitaCore on a fresh iPhone 15 Pro with 14 days of HealthKit glucose + heart-rate + sleep data already synced,
**When** the user opens the app for the first time and reaches the Home Dashboard,
**Then** VitaCore's `PersonaEngine` classifies the user into an appropriate archetype (likelyT1D / likelyT2D / prediabetic / healthy) based on their graph data, persists a starter `PersonaContext` with archetype-appropriate conditions + goals + threshold overrides, and the Home Dashboard renders realistic goal rings, live metric cards, and a glucose trend chart all bound to real data.

**Acceptance:** classification matches expected archetype for all four `VitaCoreSynthetic` cohorts; `vitacore_persona.sqlite` contains exactly one row after bootstrap; Home Dashboard never shows empty goal cards or placeholder "..." values for any metric present in the graph.

### US-02 — First-launch bootstrap with empty HealthKit [P1]

**Given** a user installs VitaCore on a fresh iPhone 15 Pro with zero HealthKit data yet synced,
**When** the user opens the app for the first time,
**Then** VitaCore MUST NOT silently commit a `healthyBaseline` persona to persistent storage. It MAY return a transient in-memory default, OR prompt the user to complete onboarding. Once HealthKit completes its back-fill and the graph crosses the data-adequacy threshold (≥ 3 glucose readings/day × ≥ 7 days OR ≥ 1 CGM source), the inferencer MUST re-run and produce a correct classification without requiring app reinstall.

**Acceptance:** an empty-graph install followed by a synthetic T1D cohort write does NOT leave the user permanently classified as `.healthy`.

### US-03 — Concurrent persona read during launch [P1]

**Given** the persona store is empty,
**When** two SwiftUI views both call `getPersonaContext()` on the `VitaCorePersonaEngine` concurrently during app launch,
**Then** exactly one persona row is written to `vitacore_persona.sqlite`, both views receive the same `PersonaContext` with the same `userId`, and no "lost update" or "duplicate row" state is possible.

**Acceptance:** test that fires N concurrent `getPersonaContext()` tasks on an empty store and asserts `loadContext()` returns exactly one row afterwards.

### US-04 — Medication add during goal edit [P2]

**Given** a persisted `PersonaContext` with 1 medication and 3 active goals,
**When** the user hits "Add Metformin" in one screen while simultaneously adjusting "Daily Steps" target in another,
**Then** both mutations succeed, no medication is lost, and no goal edit is lost. The persisted context reflects both changes atomically with no intermediate state visible to readers.

**Acceptance:** test that fires `addMedication` + `updateGoal` on parallel tasks and asserts both are present in the final persisted context.

### US-05 — Post-onboarding persona override [P2]

**Given** a user completed the auto-inferencer bootstrap and received `likelyT1D`,
**When** the user opens Settings → Persona and manually changes their condition to Prediabetes,
**Then** `updatePersonaContext(_:)` persists the override, and all subsequent `getPersonaContext()` calls return the user's explicit choice, not a re-run of the inferencer.

**Acceptance:** round-trip test; the inferencer MUST NOT re-override a manually-set persona.

### US-06 — Threshold resolution for a multi-condition user [P1]

**Given** a persona context with `type2Diabetes` + `hypertension` + active `betaBlocker` medication,
**When** the Home Dashboard fetches the current glucose threshold set via `C14 ThresholdEngine.resolveActiveThresholdSet(userId:)`,
**Then** the resolved thresholds reflect the **tighter** of T2D and Hypertension bands for any shared metric, and the beta-blocker heart-rate modifier is applied. The resolution runs in <50 ms cached or <200 ms uncached on an A17 Pro device.

**Acceptance:** unit test with synthetic multi-condition persona; verify priority stack (clinician > critical safety > most restrictive > goal > medication > age > population).

### US-07 — Synthetic cohort as a complete test substrate [P1]

**Given** any Wave 1 component that reads or writes graph data,
**When** its test suite runs under `swift test`,
**Then** tests MUST execute against `VitaCoreSynthetic` cohorts for all four locked personas (T1D pump, T2D oral/basal, prediabetic, healthy optimizer), not against hand-constructed mock data.

**Acceptance:** every Wave 1 component's test file imports `VitaCoreSynthetic` and exercises `CohortBuilder.buildCohort(...)`.

---

## Functional Requirements

### C02 — VitaCoreGraph (Wave 0 Sprint 0.1, IMPLEMENTED)

- **FR-001** The graph store MUST conform to `GraphStoreProtocol` exactly as frozen in `VitaCoreContracts`. No method signatures may change post-freeze.
- **FR-002** The graph store MUST persist `Reading` records keyed by `(metricType, timestamp, sourceSkillId)` and retrievable via `getLatestReading`, `getRangeReadings`, `getAggregatedMetric`, `getCurrentSnapshot`.
- **FR-003** The graph store MUST persist `Episode` records and retrieve them via `getEpisodes(from:to:types:)` filtered by `EpisodeType`.
- **FR-004** The graph store MUST support batch writes of at least 500 readings in one transaction via `writeReadings(_:)`.
- **FR-005** The graph store MUST support purging readings older than a given timestamp via `purgeReadings(for:olderThan:)`.
- **FR-006** The graph store MUST apply iOS file-protection class `NSFileProtectionCompleteUnlessOpen` to the SQLite file, WAL file, and SHM file.
- **FR-007** The graph store MUST provide both a file-backed factory (`defaultStore()` → `Application Support/VitaCore/vitacore.sqlite`) and an in-memory factory (`inMemory()`) for tests.

### C01 — PersonaEngine (Wave 1 Sprint 1.1, IMPLEMENTED with outstanding Critical/High devil-critic findings)

- **FR-010** `VitaCorePersonaEngine` MUST conform exactly to the frozen `PersonaEngineProtocol` (10 methods: 5 read + 5 write).
- **FR-011** The engine MUST persist `PersonaContext` in its own SQLite file `vitacore_persona.sqlite`, decoupled from the graph store.
- **FR-012** The engine MUST bootstrap from graph data on first read of an empty store using the rule-based `PersonaInferencer`, and MUST classify the user into one of four `InferredArchetype` values (`likelyT1D`, `likelyT2D`, `prediabetic`, `healthy`).
- **FR-013** The inferencer MUST classify the four `VitaCoreSynthetic` cohorts correctly to their respective archetypes (test-verifiable, currently passing for all 4).
- **FR-014** The inferencer MUST NOT persist a provisional persona classification when the graph contains insufficient data to classify. **NOT YET SATISFIED — devil-critic Critical C1.**
- **FR-015** Concurrent `getPersonaContext()` calls on an empty store MUST result in exactly one persisted persona row. **NOT YET SATISFIED — devil-critic Critical C2.**
- **FR-016** Concurrent mutations (`addMedication` / `updateGoal` / `removeMedication`) MUST be atomic read-modify-write with no lost updates. **NOT YET SATISFIED — devil-critic Critical C3.**
- **FR-017** The inferencer MUST normalise every glucose reading to mg/dL by inspecting `Reading.unit` before applying thresholds. **NOT YET SATISFIED — devil-critic Critical C4.**
- **FR-018** The inferencer MUST derive `PersonaContext.userId` from a stable install-level identity (Keychain-backed UUID that survives reinstall), not a fresh `UUID()` per bootstrap call. **NOT YET SATISFIED — devil-critic Critical C5.**
- **FR-019** The engine MUST recover gracefully from JSON decode failure on schema drift (log + re-bootstrap, not app-bricking throw). **NOT YET SATISFIED — devil-critic Critical C6.**
- **FR-020** The persona SQLite file MUST have `NSFileProtectionCompleteUnlessOpen` applied to the file, WAL, and SHM. **NOT YET SATISFIED — devil-critic High H5.**
- **FR-021** The inferencer MUST synthesise archetype-appropriate `thresholdOverrides` entries so C14 ThresholdEngine receives tighter bounds for diabetic users rather than population defaults. **NOT YET SATISFIED — devil-critic High H1.**
- **FR-022** The inferencer MUST synthesise initial `goalProgress` entries bound to the synthesised `activeGoals`, so Home Dashboard goal cards render with real values. **NOT YET SATISFIED — known bug surfaced by real engine wiring.**

### C14 — ThresholdEngine (Wave 1 Sprint 1.2, NOT YET IMPLEMENTED)

- **FR-030** `VitaCoreThreshold` package MUST provide `ThresholdEngineProtocol` with `resolveActiveThresholdSet(userId:) → ThresholdSet` as its primary method.
- **FR-031** The engine MUST support at least 5 core condition profiles at Sprint 1.2 completion: `HEALTHY_BASELINE`, `TYPE2_DIABETES`, `TYPE1_DIABETES`, `HYPERTENSION`, `CARDIAC_RISK`. Remaining 12 profiles land in Sprint 1.5.
- **FR-032** The engine MUST implement a priority stack: clinician override > critical safety > most restrictive condition > goal > medication modifier > age > population default.
- **FR-033** The engine MUST support medication modifiers for at least: `BETA_BLOCKER` (lowers HR targets), `INSULIN` (raises hypo fast-path priority), `ACE_INHIBITOR` (lowers BP targets).
- **FR-034** The engine MUST cache resolved threshold sets with a 60 s TTL, invalidated on `PersonaContext` mutation.
- **FR-035** The engine MUST emit `ThresholdOverride` events to `VitaCoreGraph.writeEpisode(...)` as an audit trail.
- **FR-036** `resolveActiveThresholdSet(...)` MUST complete within <50 ms P95 (cached) and <200 ms P95 (uncached) on iPhone 17 Pro simulator.
- **FR-037** The engine MUST consume `PersonaContext.thresholdOverrides` from C01 so user/clinician-specific overrides win over computed defaults.

### Integration (Wave 1 Sprint 1.6, PENDING)

- **FR-040** An integration test suite MUST exercise the full Wave 1 path: create persona via inferencer → add condition via `updatePersonaContext` → verify ThresholdEngine writes thresholds → query resolved threshold set → add medication → verify thresholds modified → revoke condition → verify thresholds re-resolved.

## Success Criteria

- **SC-001** All 10 existing `VitaCorePersonaEngineTests` continue to pass after Critical/High devil-critic findings are fixed.
- **SC-002** A new concurrency test suite (fires N parallel `getPersonaContext()` + N parallel `addMedication` tasks) passes with zero duplicate rows and zero lost updates.
- **SC-003** A schema-drift test writes an old-shape blob to the persona store, loads with a new-shape decoder, and observes a successful re-bootstrap (not a thrown error).
- **SC-004** A unit-drift test writes a cohort with mmol/L unit tags, runs the inferencer, and observes that readings are correctly normalised before classification (healthy European user does NOT classify as T1D).
- **SC-005** An on-disk file-protection audit confirms `vitacore_persona.sqlite` + WAL + SHM all have `NSFileProtectionCompleteUnlessOpen` set.
- **SC-006** Wave 1 Sprint 1.2 delivers a working `VitaCoreThreshold` package that resolves thresholds for all 4 synthetic cohorts, with at least 80% P95 latency under 50 ms cached.
- **SC-007** Wave 1 Sprint 1.6 integration test passes end-to-end: create → classify → threshold-resolve → mutate → re-resolve, without touching mocks.
- **SC-008** iOS app builds cleanly and launches on iPhone 17 Pro simulator with all three (C02 + C01 + C14) real packages linked, with Home Dashboard rendering real data from the synthetic T1D cohort under `DEMO_MODE`.
- **SC-009** Every Wave 1 component passes a structured `devil-critic` review with zero outstanding Critical findings before the wave closes.

## Edge Cases

- **EC-01** User has a CGM that reports in mmol/L. Every glucose reading is 4–12. The inferencer MUST NOT classify these as hypos.
- **EC-02** User has both Dexcom native and HealthKit mirroring, producing duplicate glucose readings. The inferencer MUST dedupe before computing mean/range.
- **EC-03** User has a malfunctioning CGM that emits one sub-60 reading at sensor startup. The inferencer MUST NOT commit a T1D classification on a single noisy reading.
- **EC-04** User is a T2D patient on basal insulin who experiences 2–3 legitimate hypos in the 14-day window. The inferencer MUST still classify them as T2D, not T1D.
- **EC-05** User has only 14 fingerstick readings (1/day × 14 days) producing high mean-variance. The inferencer MUST require a minimum sample-size gate or mark the classification as provisional.
- **EC-06** User performs a factory reset + reinstalls VitaCore. The install-level identity MUST survive and re-bind to the same `PersonaContext.userId`.
- **EC-07** User's system clock is manually wrong. Readings fall outside the 14-day window. The inferencer MUST NOT silently classify as "healthy" in this case.
- **EC-08** User upgrades the app to a version where `PersonaContext` has gained a new non-optional field. The store MUST NOT crash on decode; it MUST log, re-bootstrap, and continue.
- **EC-09** User completes onboarding providing their own explicit `PersonaContext` before the inferencer runs. The engine MUST honour the explicit onboarding and NOT overwrite it on next launch.
- **EC-10** User has severe / anaphylactic allergies. Any mutation to the allergen list MUST go through a confirmation gate and emit an audit-trail episode.
