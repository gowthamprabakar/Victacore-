# VitaCore — Complete Gap Analysis & Sprint Plan to Market Fit

**Date:** April 2026
**Version:** 1.0
**Current state:** v0.10.0 | 13 packages | 12 commits | 209 tracked files | ~85 tests
**Basis:** Bevel competitive analysis + devil-critic findings + spec artifacts + code audit

---

## RECONCILIATION: What's Actually Done vs What Spec Says

The spec artifacts (`tasks.md`) show T030-T041 as "PENDING" but they were ALL FIXED in Sprint 0.A+0.B (committed in the initial commit `4a0bfc3`). The following are CONFIRMED DONE in the codebase:

| Task | Fix | Commit | Status |
|---|---|---|---|
| T030 | Data-adequacy gate (`InferenceDecision`) | `4a0bfc3` | DONE |
| T031 | Bootstrap race (`bootstrapIfNeeded()` actor method) | `4a0bfc3` | DONE |
| T032 | RMW race (`store.mutate()` actor method) | `4a0bfc3` | DONE |
| T033 | Unit drift (mmol/L → mg/dL normalisation) | `4a0bfc3` | DONE |
| T034 | Stable identity (`InstallIdentity` Keychain) | `4a0bfc3` | DONE |
| T035 | Schema drift (try/catch + re-bootstrap) | `4a0bfc3` | DONE |
| T036 | Threshold overrides synthesised | `4a0bfc3` | DONE |
| T037 | GoalProgress populated | `4a0bfc3` | DONE |
| T038 | Duplicate-source dedup | `4a0bfc3` | DONE |
| T039 | File protection on persona SQLite | `4a0bfc3` | DONE |
| T040 | Sensor-glitch hypo guard | `4a0bfc3` | DONE |
| T050-T065 | C14 ThresholdEngine (full implementation) | `d794e8a` | DONE |
| — | InferenceProvider real impl | `1efc724` | DONE |
| — | SkillBus + manual entry | `3aa921c` | DONE |
| — | HealthKitSkill | `bdefe25` | DONE |
| — | HeartbeatEngine | `69be052` | DONE |
| — | MiroFish + RCA | `b278e8b` | DONE |
| — | Chat/Alerts wiring | `0dd6a0b` | DONE |
| — | Integration tests + alert dispatch | `f6598a6` | DONE |

---

## ACTUAL REMAINING GAPS — Organised by Component/Phase

### COMPONENT 1: Food Intelligence System
**Gap severity: CRITICAL — biggest competitive weakness**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| F-01 | Food database has 15 items | Hardcoded array in `VitaCoreInferenceProvider.analyzeFood()` | USDA FoodData Central SQLite (50K+ items, ~15 MB) | 2 days |
| F-02 | Food photo → macro not connected | `CameraCaptureView` exists with camera chrome; `Gemma4Runtime.generate(prompt:image:)` accepts `CIImage`. NOT wired together. | Photo → Gemma VLM → structured food items + macros | 3 days |
| F-03 | No barcode scanning | Not implemented | `AVCaptureMetadataOutput` (standard iOS API) → USDA DB lookup | 1 day |
| F-04 | FoodFlowCoordinator not writing to SkillBus | `FoodFlowCoordinator.swift:237` has `// TODO: Write entries via SkillBus` | Wire confirmed food → `skillBus.logFoodEntry()` | 0.5 day |
| F-05 | No recipe creation | Not implemented | Combine multiple food items → composite macro calculation | 2 days |
| F-06 | Allergen warning not end-to-end | `AllergenWarningView.swift` exists, `MiroFish` checks peanut allergy. Not wired as continuous flow. | photo → identify → cross-ref allergies → warning → confirm | 1 day |
| F-07 | Medication interaction not end-to-end | `MedicationInteractionView.swift` exists. Not wired. | food → check med interactions (warfarin + vitamin K, etc.) → warning | 1 day |
| F-08 | Chat-based food logging not integrated | `analyzeFood()` is separate from chat flow | "I had dal roti" in chat → `analyzeFood()` + auto-log | 1 day |

**Sprint F: Food Intelligence (11.5 days total)**

---

### COMPONENT 2: Visual Design & Polish
**Gap severity: HIGH — affects first impression**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| D-01 | No dark mode | Light only (Ethereal Light theme) | Dark variant of VCColors, swap on `colorScheme` | 2 days |
| D-02 | No iOS 26 Liquid Glass | Custom glass morphism (good) but not native Liquid Glass | Adopt `.glassEffect` / native Liquid Glass on nav bar, tab bar, sheets | 1 day |
| D-03 | No app icon | None designed | Design + asset catalog in 3 sizes (60pt, 76pt, 1024pt) | 0.5 day |
| D-04 | No launch screen | Uses `INFOPLIST_KEY_UILaunchScreen_Generation` auto-gen | Custom LaunchScreen.storyboard or SwiftUI splash with logo | 0.5 day |

**Sprint D: Design Polish (4 days total)**

---

### COMPONENT 3: Monitoring Detail Hardcodes
**Gap severity: MEDIUM — demo data visible in production**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| M-01 | Thresholds card hardcoded | 4 static `ThresholdItem` entries at MonitoringDetailView:63-68 | Read from `ThresholdEngine.resolveActiveThresholdSet()` | 0.5 day |
| M-02 | Recent findings hardcoded | 10 static `FindingEntry` at MonitoringDetailView:98-109 | Query recent `monitoringResult` + `cgmGlucose` episodes from GraphStore | 1 day |
| M-03 | Cycle timing hardcoded | "3 min ago" / "in 2 min" at lines 212-216 | Read from HeartbeatEngine's actual last cycle time | 0.5 day |
| M-04 | Evidence lines hardcoded in ChatComponents | 3 static evidence strings in `EvidenceDisclosureView` | Pull from `CofactorAnalyser` output (cofactor.explanation) | 0.5 day |

**Sprint M: Monitoring Cleanup (2.5 days total)**

---

### COMPONENT 4: Notifications & Alert Delivery
**Gap severity: HIGH — users need real notifications**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| N-01 | No local notifications | HeartbeatEngine alerts routed to AlertPresentationManager (in-app only) | `UNNotificationRequest` with `.timeSensitive` for alert/critical bands | 1 day |
| N-02 | No notification quiet hours | PersonaContext has `notificationQuietHoursStart/End` but not consumed | Check quiet hours before dispatching notifications | 0.5 day |
| N-03 | No notification permission request | OnboardingPermissionsView uses mock toggle for notifications | Real `UNUserNotificationCenter.requestAuthorization()` | 0.5 day |
| N-04 | AlertRouterProtocol still mock | Last remaining mock protocol | Implement real `AlertRouter` backed by HeartbeatEngine + GraphStore episodes | 2 days |

**Sprint N: Notifications (4 days total)**

---

### COMPONENT 5: Onboarding & First-Run Experience
**Gap severity: MEDIUM — functional but not polished**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| O-01 | HealthKit auth is mock toggle | OnboardingPermissionsView simulates permission state | Real `HKHealthStore.requestAuthorization()` in onboarding | 1 day |
| O-02 | Gemma model download not wired | OnboardingDownloadView exists but doesn't call `Gemma4Runtime.load(progress:)` | Wire download button → model download with progress bar | 1 day |
| O-03 | No metric education | Users see metrics with no explanation | "What does this mean?" tooltip overlays on first metric view | 1 day |
| O-04 | No activity status | PersonaContext has no `.sick`/`.injured`/`.resting` state | Add `ActivityStatus` enum to PersonaContext, adjust MiroFish recommendations | 0.5 day |

**Sprint O: Onboarding Polish (3.5 days total)**

---

### COMPONENT 6: PersonaEngine Completion
**Gap severity: MEDIUM — architecture complete, features missing**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| P-01 | No ResponseProfile | Not implemented | `ResponseProfile` entity with 10-sample-minimum activation gate | 1 day |
| P-02 | No allergen semantic map | `PersonaContext.allergies` stores allergen name only | Map peanut → [groundnut, satay, peanut butter, arachis oil] | 0.5 day |
| P-03 | Notification quiet hours not consumed | Field exists in `PreferenceSummary` but not checked | Wire to notification dispatch path | 0.5 day |
| P-04 | No `getResponseProfileForContext()` | Not implemented | Accessor for C18 MiroFish consumption | 0.5 day |

**Sprint P: PersonaEngine Completion (2.5 days total)**

---

### COMPONENT 7: ThresholdEngine Completion
**Gap severity: MEDIUM — 5/17 conditions, 3/8 med modifiers**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| T-01 | Only 5 of 17 condition profiles | Healthy, T1D, T2D, prediabetes, hypertension | Add 12 more: HTN-S2, cardiac risk, elderly65+, hypothyroid, hyperthyroid, CKD, COPD, obesity, PCOS, iron deficiency, vitamin D deficiency, heart failure | 2 days |
| T-02 | Only 3 of 8 medication modifiers | Insulin, beta-blocker, ACE inhibitor | Add 5 more: statin, SGLT2, GLP1, diuretic, sulfonylurea | 1 day |
| T-03 | No composite rules as Swift types | CofactorAnalyser handles correlation; no formal PredicateTree | Scaffold PostMealSpike, HypoTrajectory, DehydrationGlucose, etc. as evaluable types | 2 days |

**Sprint T: ThresholdEngine Completion (5 days total)**

---

### COMPONENT 8: Testing & Quality Gaps
**Gap severity: HIGH — constitution Gate #3 violated**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| Q-01 | VitaCoreGraph tests don't use VitaCoreSynthetic | 8 tests with hand-constructed fixtures | Add cohort round-trip tests for all 4 personas (Constitution Gate #3 / Principle V) | 1 day |
| Q-02 | No dedicated concurrency test file | T031/T032 fixes are in code but not stress-tested | `ConcurrencyTests.swift`: N parallel `getPersonaContext()` + N parallel `addMedication()` | 0.5 day |
| Q-03 | No dedicated schema-drift test | T035 fix is in code but not regression-tested | `SchemaDriftTests.swift`: write v1 blob, load with v2 decoder | 0.5 day |
| Q-04 | No unit-drift test | T033 fix is in code but not regression-tested | `UnitDriftTests.swift`: mmol/L cohort → classifier → healthy (not T1D) | 0.5 day |
| Q-05 | 10 edge cases from spec untested | EC-01 through EC-10 defined but no test coverage | Write at least 5 highest-priority EC tests | 1 day |
| Q-06 | No performance benchmarks | No latency measurements on real device | Benchmark ThresholdEngine resolve (<50ms) + GraphStore getLatestReading (<20ms) | 1 day |

**Sprint Q: Quality & Testing (4.5 days total)**

---

### COMPONENT 9: LLM Runtime & Model Management
**Gap severity: HIGH — the model never actually runs**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| L-01 | No on-device LLM benchmark | `Gemma4Runtime` compiles and passes smoke tests but model was NEVER loaded | Benchmark on iPhone 15 Pro: load time, tok/s, peak RAM, first-token latency | 2 days |
| L-02 | Model download UX not wired | `OnboardingDownloadView` exists; `Gemma4Runtime.load(progress:)` exists. Not connected. | Wire download button → model download → progress bar → completion | 1 day |
| L-03 | No model management settings | No way to delete/re-download model from Settings | Add model management section to Settings: status, size, delete, re-download | 1 day |
| L-04 | Tiered model strategy not implemented | `Quantisation` enum has `.gemma3n_q4` and `.gemma4_e2b` but no runtime switching logic | Implement `unload()` + model swap between E2B (chat) and E4B (RCA) | 2 days |

**Sprint L: LLM Runtime (6 days total)**

---

### COMPONENT 10: Ship-Readiness
**Gap severity: CRITICAL — can't submit without these**

| # | Gap | Current State | Target | Effort |
|---|---|---|---|---|
| S-01 | No code signing | `DEVELOPMENT_TEAM: ""` in project.yml | Set team ID, provisioning profile | 0.5 day |
| S-02 | No privacy manifest | No `PrivacyInfo.xcprivacy` file | Declare HealthKit usage, model download, notifications | 0.5 day |
| S-03 | No data retention policy | T091 not implemented | 90-day raw reading purge via `purgeReadings(olderThan:)` | 0.5 day |
| S-04 | Security audit not done | No systematic check for PHI in logs/crashes/URL params | Audit all `print()` statements, verify no PHI leaks | 1 day |
| S-05 | Regulatory language not audited | Constitution AD-10 requires wellness framing | Audit all Gemma system prompts + UI strings for "diagnosis"/"prescription"/"treatment" | 0.5 day |
| S-06 | No TestFlight submission | Not attempted | App Store Connect setup, first TestFlight build | 1 day |

**Sprint S: Ship (4 days total)**

---

## PHASED SPRINT PLAN: 10 Sprints to Market Fit

| Phase | Sprint | Component | Days | Cumulative |
|---|---|---|---|---|
| **4A** | Sprint F.1 | Food DB (USDA SQLite) + FoodFlow wiring | 3 | 3 |
| **4A** | Sprint D | Dark mode + app icon + launch screen | 4 | 7 |
| **4B** | Sprint N | Notifications + AlertRouter real | 4 | 11 |
| **4B** | Sprint M | Monitoring hardcode cleanup | 2.5 | 13.5 |
| **4C** | Sprint O | Onboarding polish (HealthKit auth, model download, tooltips) | 3.5 | 17 |
| **4C** | Sprint Q | Testing gaps (synthetic cohort tests, concurrency, edge cases) | 4.5 | 21.5 |
| **4D** | Sprint S | Ship-readiness (signing, privacy, security, regulatory, TestFlight) | 4 | 25.5 |
| **v1.1** | Sprint F.2 | Food photo vision + barcode + allergen flow | 5 | 30.5 |
| **v1.1** | Sprint L | LLM benchmark + model download UX + tiered strategy | 6 | 36.5 |
| **v1.1** | Sprint P+T | PersonaEngine + ThresholdEngine completion | 7.5 | 44 |

### Phase 4A: Critical Gaps (Week 1-2)
**Sprint F.1 + Sprint D = 7 days**
- Bundle USDA FoodData Central as SQLite (F-01)
- Wire FoodFlowCoordinator → SkillBus (F-04)
- Chat-based food logging (F-08)
- Dark mode color tokens (D-01)
- App icon + launch screen (D-03, D-04)
- Liquid Glass adoption (D-02)

### Phase 4B: Notifications + Polish (Week 2-3)
**Sprint N + Sprint M = 6.5 days**
- Local notifications with `.timeSensitive` (N-01)
- Real AlertRouter replacing last mock (N-04)
- Notification quiet hours (N-02, N-03)
- MonitoringDetailView real thresholds + findings (M-01, M-02, M-03)
- Evidence lines from real RCA data (M-04)

### Phase 4C: Onboarding + Quality (Week 3-4)
**Sprint O + Sprint Q = 8 days**
- Real HealthKit auth in onboarding (O-01)
- Model download in onboarding (O-02)
- Metric education tooltips (O-03)
- Activity status (O-04)
- VitaCoreGraph synthetic tests (Q-01)
- Concurrency + schema-drift + unit-drift tests (Q-02-Q04)
- Edge case tests (Q-05)

### Phase 4D: Ship (Week 4-5)
**Sprint S = 4 days**
- Code signing + provisioning (S-01)
- Privacy manifest (S-02)
- Data retention (S-03)
- Security audit (S-04)
- Regulatory language audit (S-05)
- TestFlight submission (S-06)

### Post-MVP (v1.1)

**Sprint F.2: Food Vision + Barcode (5 days)**
- F-02: Food photo → Gemma VLM vision tower
- F-03: Barcode scanning via AVCaptureMetadataOutput
- F-05: Recipe creation with composite macros
- F-06: Allergen warning end-to-end flow
- F-07: Medication interaction checking flow

**Sprint L: LLM Runtime (6 days)**
- L-01: On-device benchmark (load time, tok/s, peak RAM on physical iPhone)
- L-02: Model download UX (OnboardingDownloadView → Gemma4Runtime.load)
- L-03: Model management settings (status, size, delete, re-download)
- L-04: Tiered model strategy (E2B chat ↔ E4B RCA swap)

**Sprint P+T: Engine Completion (7.5 days)**
- P-01: ResponseProfile entity (10-sample-minimum activation)
- P-02: Allergen semantic map (peanut → groundnut, satay, etc.)
- T-01: 12 more condition profiles
- T-02: 5 more medication modifiers
- T-03: Composite rule types (PostMealSpike, HypoTrajectory, etc.)

---

## COMPONENT 11: Wellness Features (Previously Missing From Plan)

**These were identified in the Bevel competitive analysis Feature Completeness
table but NOT included in any sprint. Adding them now.**

### Features to BUILD (clinically relevant for metabolic health)

| # | Gap | What Bevel Has | What VitaCore Needs | Why It Matters for Metabolic Patients | Effort |
|---|---|---|---|---|---|
| **W-01** | MetabolicReadiness Score | HRV + RHR + temp → 0-100% recovery | Compute from: sleep quality + glucose time-in-range + HRV trend + medication adherence → 0-100% | Poor readiness → insulin resistance → elevated glucose next day. Clinically actionable. | 2 days |
| **W-02** | SleepQualityScore | Quality %, stages, baseline comparison | Compute from: hours + deep sleep % + interruptions + overnight glucose stability + comparison to 7-day avg | Sleep < 6h → 40% increased insulin resistance (published evidence). Direct glucose predictor. | 2 days |
| **W-03** | StressLevel (discrete) | Current stress level tracked | Elevate from RCA cofactor to discrete metric. Compute from: resting HR variance + HRV drop + time-of-day. Display on Home Dashboard. | Cortisol → hepatic glucose output. Stress is a first-order glucose confounder. | 1.5 days |
| **W-04** | HealthJournal | Log habits → correlate with outcomes | Targeted metabolic journal: what I ate, how I moved, how I slept, did I take meds? Auto-correlate each entry with glucose readings in the ±4h window via CofactorAnalyser. | Unlike Bevel's generic journal, VitaCore's is clinically focused: every entry feeds the RCA engine. | 3 days |
| **W-05** | VO2 Max display | Tracked from HealthKit | Read `HKQuantityType.vo2Max` from HealthKit. Display on Home Dashboard as a cardiovascular fitness indicator. | Cardiovascular fitness inversely correlates with metabolic syndrome risk. Easy value add. | 0.5 day |

**Sprint W: Wellness Intelligence (9 days total)**

### Features to DEFER (not core to metabolic health)

| # | Feature | Bevel Has | Why Defer | Target |
|---|---|---|---|---|
| **W-D1** | Strain Score / Cardio Load | Active + passive strain, 6-state training status | Metabolic patients aren't optimising training load. Activity impact on glucose already handled by CofactorAnalyser. | v2.0 |
| **W-D2** | Strength Training | 700+ exercises, AI workouts | Not clinically relevant for metabolic health MVP. | v2.0+ |
| **W-D3** | Smart Alarm | Wake during light sleep | Nice-to-have, not therapeutic. | v2.0 |
| **W-D4** | Energy Bank | Composite of recovery + sleep + strain + stress | MetabolicReadiness (W-01) serves the same purpose with clinical framing. | Replaced by W-01 |

---

## REVISED TOTAL EFFORT SUMMARY

| Scope | Gaps | Days | Weeks |
|---|---|---|---|
| **v1.0 (TestFlight)** | 28 gaps | 25.5 days | ~5 weeks |
| **v1.1 (App Store)** | 15 gaps + 5 wellness features | 28 days | ~6 weeks |
| **v2.0 (Competitive)** | watchOS + Strain + Strength + Smart Alarm | TBD | TBD |
| **TOTAL to market fit** | 48 gaps | 53.5 days | ~11 weeks |

### Revised v1.1 Sprint Sequence

| Sprint | Content | Days |
|---|---|---|
| F.2 | Food vision + barcode + allergen + med interaction | 5 |
| L | LLM benchmark + download UX + tiered model | 6 |
| **W** | **MetabolicReadiness + SleepScore + StressLevel + HealthJournal + VO2Max** | **9** |
| P+T | PersonaEngine + ThresholdEngine completion | 7.5 |
| **v1.1 TOTAL** | | **27.5 days** |

---

## COMPLETE GAP INVENTORY (All IDs)

| ID Range | Component | Count |
|---|---|---|
| F-01 to F-08 | Food Intelligence | 8 |
| D-01 to D-04 | Design & Polish | 4 |
| M-01 to M-04 | Monitoring Hardcodes | 4 |
| N-01 to N-04 | Notifications | 4 |
| O-01 to O-04 | Onboarding | 4 |
| P-01 to P-04 | PersonaEngine Completion | 4 |
| T-01 to T-03 | ThresholdEngine Completion | 3 |
| Q-01 to Q-06 | Testing & Quality | 6 |
| L-01 to L-04 | LLM Runtime | 4 |
| S-01 to S-06 | Ship-Readiness | 6 |
| **W-01 to W-05** | **Wellness Intelligence (NEW)** | **5** |
| W-D1 to W-D4 | Deferred (v2.0) | 4 |
| **TOTAL** | | **52 active + 4 deferred** |

---

## TRACKING

Each gap has a unique ID (F-01 through W-05). Sprint assignments are fixed. Mark each [DONE] as it lands. Re-run `/speckit-analyze` after each phase completes.
