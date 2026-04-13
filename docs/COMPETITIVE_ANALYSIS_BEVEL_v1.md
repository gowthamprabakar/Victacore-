# VitaCore vs Bevel Health — Component-by-Component Gap Analysis

**Date:** April 2026
**Version:** 1.0
**Analyst:** Speckit PMO
**Purpose:** Identify every gap between VitaCore and Bevel Health, prioritise fixes, and define market-fit action plan.

---

## Competitor Profile: Bevel Health

| Metric | Value |
|---|---|
| Company | Finerpoint, Inc. (~20 employees) |
| Users | ~500,000 |
| App Store | 4.8 stars, 7,678 ratings |
| Version | 2.5.9 (launched mid-2025) |
| Pricing | Free core; AI Intelligence $9.99/mo or $79.99/yr |
| Platform | iOS + watchOS |
| Legal | Being sued by WHOOP for trade dress/UI IP (Mar 2026) |

---

## Component-by-Component Comparison

### 1. RECOVERY & READINESS SCORING

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Recovery score | HRV (RMSSD) + resting HR + wrist temp → 0-100% score | Not implemented | MISSING |
| Readiness indicator | Push/rest recommendation based on recovery | ThresholdEngine classifies safe/watch/alert/critical but no "readiness" composite | PARTIAL |
| Algorithm transparency | Opaque (users complain they can't see what drove the score) | ThresholdResolver shows exactly which condition/med/override determined each band | VitaCore BETTER on transparency |
| User feedback | "Recovery rarely exceeds 50%, feels inaccurate" | N/A | Bevel has a known weakness here |

**Priority:** MEDIUM — VitaCore's market is diabetics/metabolic patients, not athletes. A "readiness" score is nice-to-have, not core.

**Action (v1.1):** Compute a `MetabolicReadiness` score from: sleep quality + glucose time-in-range + HRV trend + medication adherence. Display on Home Dashboard where Bevel shows Recovery. More clinically meaningful than Bevel's generic recovery.

---

### 2. STRAIN / ACTIVITY TRACKING

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Strain score | Active (HR during workouts) + passive (steps, movement) | Steps tracked via HealthKit. No composite strain metric. | MISSING |
| Cardio Load | 6-state training status (detraining → overtraining) | Not implemented | MISSING |
| Target Strain | Personalised daily strain recommendation | Not implemented | MISSING |
| Activity detection | Auto-detects workouts | Relies on HealthKit workout detection | PARTIAL |

**Priority:** LOW for MVP — VitaCore's users are metabolic patients, not athletes optimising training load.

**Action (v2.0):** Consider a "Metabolic Activity Score" that combines steps + exercise minutes + post-meal walking (which is clinically proven to lower glucose by 15-25 mg/dL). This positions activity tracking as a therapeutic tool, not a fitness metric.

---

### 3. SLEEP INTELLIGENCE

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Sleep score | Quality %, stages, interruptions → single number | Sleep hours tracked from HealthKit. No score. | PARTIAL |
| Smart alarm | Wakes during light sleep phase | Not implemented | MISSING |
| Sleep-habit correlation | Journal entries → sleep quality changes over time | CofactorAnalyser: `poorSleep` cofactor when sleep < 6h correlates with elevated glucose | VitaCore DIFFERENT (clinical, not general) |
| Sleep stages | REM, deep, light visualised | Reads HealthKit stages but doesn't display analysis | PARTIAL |

**Priority:** MEDIUM — poor sleep directly impacts glucose and insulin sensitivity. VitaCore's clinical angle (sleep → glucose correlation) is more valuable than Bevel's general sleep score.

**Action (v1.1):** Add `SleepQualityScore` computed from: hours + deep sleep % + interruptions + glucose-overnight-stability. Display on Home and correlate with next-morning glucose in MiroFish analysis.

---

### 4. AI COMPANION / INTELLIGENCE

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Conversational AI | "Why was my recovery low?" → analysis from physiological data | `sendMessage()` with full PersonaContext + ThresholdSet + MonitoringSnapshot system prompt | VitaCore ARCHITECTURALLY STRONGER |
| Memory system | Core memory (who you are) + short-term (current goals, injuries) | PersonaContext persisted in GRDB (conditions, meds, allergies, goals, thresholds) | COMPARABLE — different approach |
| Activity status | Sick/Injured/On Break adjusts recommendations | Not implemented | MISSING (easy to add to PersonaContext) |
| On-screen awareness | AI answers about anything visible in the app | Not implemented | MISSING (novel feature) |
| Workout generation | "Give me a 30-min upper body home workout" | Not implemented (not core to metabolic health) | MISSING but LOW priority |
| Chat-based food logging | "I had chicken rice for lunch" → AI logs it | `analyzeFood()` exists but not chat-integrated (separate flow) | PARTIAL |
| Proactive insights | Alerts trigger AI sessions | HeartbeatEngine → MiroFish → ProactiveSessionView (WIRED) | VitaCore IMPLEMENTED |
| Price | $9.99/mo PAID | FREE (on-device, no API cost) | VitaCore WINS on cost |
| Privacy | Cloud-based (implied) | 100% on-device Gemma inference | VitaCore WINS on privacy |

**Priority:** HIGH — this is where both apps differentiate. VitaCore's architecture is stronger (real persona context, threshold-aware prompts, on-device privacy, zero cost) but Bevel's is more polished (memory, on-screen awareness, activity status).

**Action items:**
- **(v1.0, 1 day):** Add `ActivityStatus` enum to PersonaContext (`.active`, `.sick`, `.injured`, `.resting`). MiroFish adjusts recommendations when sick/injured.
- **(v1.1):** Chat-based food logging — when user types "I had dal roti", route to `analyzeFood()` + `skillBus.logFoodEntry()` inline in chat rather than separate Log flow.
- **(v2.0):** On-screen awareness — the model receives the current screen's state in the system prompt. Novel but low-priority.

---

### 5. NUTRITION / FOOD ANALYSIS

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Food database | 5-6M verified items | 15 hardcoded items | **333,000x gap** |
| Photo → macro | AI image recognition, editable components | Camera UI exists, vision tower NOT connected | CRITICAL GAP |
| Barcode scan | Working | Not implemented | CRITICAL GAP |
| Recipe creation | Combine ingredients → composite macro | Not implemented | MISSING |
| Text search | Search across 6M items | 15-item pattern match | CRITICAL GAP |
| Glucose impact | Dexcom/Libre → per-meal nutrition score | CofactorAnalyser: post-meal spike detection (tested, works) | VitaCore DIFFERENT (clinical, not scoring) |
| Allergen safety | Not prominently featured | Architecture exists (AllergenWarningView, peanut check in MiroFish) | VitaCore LEADS conceptually |
| Med interaction | Not featured | MedicationInteractionView exists (not wired) | VitaCore LEADS conceptually |
| Accuracy | "50%+ barcode errors" per user reports | Hardcoded values (accurate for 15 items, useless for rest) | BOTH HAVE ACCURACY ISSUES |

**Priority:** CRITICAL — this is VitaCore's biggest gap. The 15-item lookup is not a product feature.

**Action plan:**
- **(v1.0 — Sprint 4.A, 2 days):** Bundle USDA FoodData Central as a SQLite file. 50K+ foods, ~15 MB. Replace the 15-item lookup with real text search. This 100x the food DB overnight.
- **(v1.1 — 3 days):** Wire `CameraCaptureView.onImageCaptured` → `Gemma4Runtime.generate(prompt:image:)` via MLXVLM. The vision tower infrastructure exists — connect it.
- **(v1.1 — 1 day):** Add barcode scanning via `AVCaptureMetadataOutput` → USDA DB lookup.
- **(v1.2):** Allergen warning end-to-end: photo → identify → cross-reference `PersonaContext.allergies` → warning screen → confirm/reject.
- **(v2.0):** Recipe creation with composite macro computation.

---

### 6. APPLE WATCH / watchOS

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Watch app | Full watchOS app | None | CRITICAL GAP |
| Complications | Strain, Recovery, Sleep, Nutrition, Stress | None | CRITICAL GAP |
| Workout tracking on Watch | Yes (with sync to phone, has bugs) | HealthKit reads Watch data after the fact | MAJOR GAP |
| Background data | Watch collects continuously | HealthKit background delivery (HKObserverQuery) | PARTIAL |

**Priority:** MEDIUM for MVP — VitaCore's primary data comes from CGMs (phone-connected) and HealthKit (background sync). A Watch app adds real-time HR/steps on the wrist but isn't required for the metabolic intelligence pipeline.

**Action (v2.0):** Add a watchOS companion app with: current glucose + trend arrow complication, heart rate complication, hypo alert notification, and a "Log Fluid" quick action. This is ~2 weeks of work for a focused watchOS developer.

---

### 7. ONBOARDING

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Flow length | Long, personalised, conversion-optimised | 8 steps (welcome, profile, conditions, meds, goals, allergies, permissions, download) | VitaCore MORE thorough |
| Post-onboarding | Blank dashboard (users complain) | DEMO_MODE seeds 14 days of synthetic data | VitaCore BETTER |
| Metric education | None (users request it) | Not implemented | BOTH MISSING |
| HealthKit auth | Integrated into onboarding | Mock toggle (auth triggers on app launch separately) | PARTIAL |
| Persona inference | Not mentioned | Auto-classifies T1D/T2D/prediabetic/healthy from graph data | VitaCore UNIQUE |

**Priority:** MEDIUM — VitaCore's onboarding is architecturally better (condition collection → persona inference → threshold resolution). Bevel's is psychologically better (conversion-optimised, soft paywall). VitaCore needs metric education added.

**Action (v1.1):** Add a "What does this mean?" explainer for each metric on first view (tooltip overlay, one-time). This addresses Bevel's most complained-about onboarding gap and is 1 day of work.

---

### 8. ENERGY BANK / STRESS / JOURNALING

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Energy Bank | Composite of recovery + sleep + strain + stress → depletes during day | Not implemented | MISSING |
| Stress monitoring | Current stress level from HRV | `stressIndicator` cofactor in RCA (elevated resting HR = stress signal) | PARTIAL |
| Habit journaling | Log habits → correlate with outcomes over time | Not implemented | MISSING |
| Caffeine timing | Alerts for late caffeine → sleep impact | Not implemented | MISSING |

**Priority:** LOW — VitaCore's users are metabolic patients. "Energy Bank" is a wellness concept. The clinically meaningful equivalent for VitaCore is "Metabolic Load" (glucose variability + medication adherence + sleep quality + activity). If implemented, it should use clinical framing.

**Action (v2.0):** Consider a "Metabolic Load" composite metric that maps to VitaCore's clinical focus. Not a priority for MVP.

---

### 9. DESIGN & VISUAL LANGUAGE

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Design system | Dark + light themes, Liquid Glass adoption, WHOOP-inspired | Ethereal Light: glass morphism, 3-layer shadows, WCAG AAA | DIFFERENT, both strong |
| Liquid Glass (iOS 26) | Already adopted across buttons, nav, sheets | Designed for iOS 26 but not Liquid Glass specifically | Bevel AHEAD on platform currency |
| Dashboard animations | Animated headers on scroll for each metric section | Shimmer loading, staggered entrance, spring cards, breathing dots | COMPARABLE |
| Dark mode | Full dark + light themes | Light theme only (Ethereal Light). Dark mode incomplete. | Bevel AHEAD |
| Accessibility | Not prominently featured | WCAG AAA, VoiceOver groundwork, 44x44pt targets | VitaCore AHEAD |

**Priority:** MEDIUM — VitaCore's design is distinctive and accessible. Missing dark mode is a real gap. Liquid Glass adoption would signal platform maturity.

**Action items:**
- **(v1.0):** Add dark mode variant to VitaCoreDesign color tokens. Swap palette based on `@Environment(\.colorScheme)`. 2 days of work.
- **(v1.1):** Adopt Liquid Glass for navigation bar, tab bar, and sheet presentations via iOS 26 SDK APIs.

---

### 10. ALERTS & NOTIFICATIONS

| Dimension | Bevel | VitaCore | Gap |
|---|---|---|---|
| Alert system | Not prominently featured | 3-tier: critical (full-screen) / alert (sheet) / watch (banner) with HeartbeatEngine 60s monitoring | VitaCore LEADS significantly |
| Fast-path hypo | Not featured (not their market) | Glucose < 70 → immediate critical alert | VitaCore UNIQUE |
| Notification class | Standard | `.timeSensitive` (bypasses Focus, per AD-05) | VitaCore AHEAD |
| Alert-to-chat handoff | Not featured | ProactiveSessionView → real inference with alert context | VitaCore UNIQUE |
| Alert fatigue management | Not featured | Planned (crossing dedup, cooldowns) | VitaCore AHEAD |

**Priority:** This is VitaCore's MOAT. Bevel has no clinical alert system. VitaCore has a 3-tier alert pipeline with fast-path hypo alerts, threshold-crossing detection, and proactive AI sessions. This is the #1 reason a diabetic user would choose VitaCore over Bevel.

**Action:** Already implemented and tested. Ship it.

---

## Gap Priority Matrix

| Priority | Component | Gap | Action | Sprint |
|---|---|---|---|---|
| **CRITICAL** | Food database | 15 items vs 5M | Bundle USDA FoodData Central SQLite (50K+) | v1.0 |
| **CRITICAL** | Food photo | Camera UI exists but vision not connected | Wire CameraCaptureView → Gemma VLM | v1.1 |
| **HIGH** | Dark mode | Light only | Add dark color tokens | v1.0 |
| **HIGH** | AI memory | No activity status awareness | Add ActivityStatus to PersonaContext | v1.0 |
| **HIGH** | Barcode scan | Not implemented | AVCaptureMetadataOutput → USDA DB | v1.1 |
| **MEDIUM** | Sleep score | Hours only, no score | SleepQualityScore composite | v1.1 |
| **MEDIUM** | Recovery/Readiness | No composite | MetabolicReadiness score | v1.1 |
| **MEDIUM** | Metric education | No explainers | Tooltip overlays on first view | v1.1 |
| **MEDIUM** | watchOS | No Watch app | Companion app with glucose complication | v2.0 |
| **LOW** | Strain score | No composite | MetabolicActivityScore | v2.0 |
| **LOW** | Energy Bank | Not implemented | MetabolicLoad composite | v2.0 |
| **LOW** | Habit journal | Not implemented | Consider if clinical value exists | v2.0 |
| **LOW** | Workout tracking | Not implemented | Not core to metabolic health market | v2.0+ |

---

## Where VitaCore Already BEATS Bevel (Ship These as Marketing Points)

1. **Multi-cofactor RCA** — Bevel tells you WHAT happened. VitaCore tells you WHY.
2. **Privacy** — Bevel runs 5 ad trackers. VitaCore sends zero data off-device.
3. **Clinical alerting** — 3-tier threshold-crossing alerts with fast-path hypo. Bevel has nothing.
4. **Condition-aware thresholds** — T1D gets different bands than T2D. Bevel uses one-size-fits-all.
5. **Medication-aware reasoning** — Insulin shifts glucose thresholds. Beta-blocker shifts HR. Bevel doesn't do this.
6. **Allergen safety in food** — Architecture to flag peanut-containing food to a user with peanut allergy.
7. **Free AI** — On-device Gemma = $0/month. Bevel Intelligence = $120/year.
8. **Persona inference** — Auto-classifies the user from their data. Bevel doesn't classify.
9. **Prescription cards** — Ranked, evidence-based, timed action recommendations with contraindications.
10. **Accessibility** — WCAG AAA, VoiceOver, 44x44 tap targets. Bevel doesn't mention accessibility.

---

## Conclusion

**VitaCore is NOT a Bevel competitor.** They serve different markets:
- **Bevel** = fitness enthusiasts who want a WHOOP replacement on their Apple Watch
- **VitaCore** = people with metabolic conditions (diabetes, prediabetes, hypertension) who need clinical-grade intelligence

**VitaCore's strategic position:** The app that Bevel users graduate to when they get a diabetes diagnosis. Or the app a doctor recommends alongside a CGM prescription. The clinical depth (multi-cofactor RCA, condition-aware thresholds, medication interactions, allergen safety, fast-path hypo alerts) is VitaCore's moat. Bevel can't copy it without rebuilding their entire architecture.

**What VitaCore MUST fix to be market-ready:** Food database (CRITICAL), dark mode (HIGH), and food photo analysis (v1.1). Everything else is either implemented, architecturally ahead of Bevel, or not relevant to VitaCore's target market.
