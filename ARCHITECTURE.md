# VitaCore Architecture

## System Overview

VitaCore is a privacy-first on-device AI health intelligence app for iOS. Every computation — inference, classification, threshold resolution, monitoring — runs on the user's device. No PHI crosses the network.

## Package Dependency Graph

```
VitaCoreContracts (zero deps — frozen protocols + model types)
  ├── VitaCoreDesign (design tokens, glass components)
  ├── VitaCoreNavigation (routing, tabs, sheets)
  ├── VitaCoreMock (fake implementations for SwiftUI preview)
  ├── VitaCoreGraph (GRDB/SQLite graph store)
  │     └── VitaCoreSynthetic (4-persona test data generators)
  │           └── VitaCorePersona (PersonaEngine + graph-driven inferencer)
  │                 └── VitaCoreThreshold (priority stack resolver + 5 condition profiles)
  ├── VitaCoreInference (MLX-Swift Gemma runtime + InferenceProvider + conversation store)
  ├── VitaCoreSkillBus (manual entry + HealthKit skill)
  └── VitaCoreHeartbeat (monitoring loop + fast-path alerts)
```

## Frozen Protocol Surface (5 contracts)

| Protocol | Real Implementation | Package |
|----------|-------------------|---------|
| `GraphStoreProtocol` | `GRDBGraphStore` | VitaCoreGraph |
| `PersonaEngineProtocol` | `VitaCorePersonaEngine` | VitaCorePersona |
| `InferenceProviderProtocol` | `VitaCoreInferenceProvider` | VitaCoreInference |
| `SkillBusProtocol` | `VitaCoreSkillBus` | VitaCoreSkillBus |
| `AlertRouterProtocol` | Mock (HeartbeatEngine handles alerts) | VitaCoreMock |

## Storage Topology

Each component owns its own SQLite file (Constitution Principle III):

| Component | File | Content |
|-----------|------|---------|
| VitaCoreGraph | `vitacore.sqlite` | Readings, episodes, nodes, edges |
| VitaCorePersona | `vitacore_persona.sqlite` | PersonaContext JSON blob |
| VitaCoreInference | `vitacore_conversations.sqlite` | Conversation sessions |

All files in `Application Support/VitaCore/`. File protection: `NSFileProtectionCompleteUnlessOpen`.

## Data Flow

```
HealthKit / Manual Entry
         │
         ▼
    VitaCoreSkillBus ──► GraphStore (readings + episodes)
                              │
                              ├──► PersonaInferencer (classifies user on first launch)
                              │         │
                              │         ▼
                              │    PersonaContext (conditions, goals, meds, allergies)
                              │         │
                              │         ▼
                              │    ThresholdEngine (resolves safe/watch/alert/critical bands)
                              │         │
                              ▼         ▼
                         HeartbeatEngine (60s cycle, evaluates readings vs thresholds)
                              │
                              ├──► Fast-path alerts (glucose <70, HR >120/<40)
                              └──► InferenceRequest → InferenceProvider → Gemma → PrescriptionCard
```

## LLM Strategy (AD-13)

| Device | Model | RAM |
|--------|-------|-----|
| iPhone 15 Pro (8 GB) | Gemma 3n E4B 4-bit via MLXVLM | ~3 GB |
| iPhone 16/17 Pro (12 GB) | Gemma 4 E4B 4-bit (when mlx-swift-lm merges) | ~5.2 GB |

One model loaded at a time. Rule-based fallback when model is not downloaded.

## Test Architecture

- **Framework:** Swift Testing (`@Test`, `#expect`)
- **Fixtures:** `VitaCoreSynthetic` — 4 persona archetypes with seeded RNG
- **Coverage:** ~107 test functions across 8 packages
- **Run:** `cd Packages/<pkg> && swift test`

## Key Architectural Decisions

See `.specify/memory/constitution.md` for AD-01 through AD-13.
