# Contributing to VitaCore

## Prerequisites

- **Xcode 17+** (iOS 26.2 SDK)
- **Swift 5.9+**
- **xcodegen** — `brew install xcodegen`
- **Metal Toolchain** — `xcodebuild -downloadComponent MetalToolchain` (required for MLX-Swift)
- **Minimum sim/device:** iPhone 15 Pro (A17 Pro, 8 GB RAM)

## Getting Started

```bash
git clone https://github.com/gowthamprabakar/Victacore-.git
cd Victacore-
xcodegen generate
open VitaCore.xcodeproj
```

## Project Structure

```
VitaCore/
├── VitaCoreApp/                    # Main app target (SwiftUI screens)
│   ├── VitaCoreApp.swift           # @main entry, dependency injection
│   └── Screens/                    # 40+ UI screens grouped by feature
│       ├── Home/                   # Dashboard, metric cards, goal rings
│       ├── Chat/                   # AI conversation UI
│       ├── Log/                    # Manual entry sheets (glucose, BP, etc.)
│       ├── Alerts/                 # Critical/alert/watch panels
│       ├── Settings/               # Profile, connections, privacy
│       ├── Onboarding/             # 8-step onboarding flow
│       ├── MetricDetail/           # Per-metric detail views
│       ├── FoodFlow/               # Food logging + analysis
│       ├── Widgets/                # Widget gallery
│       └── Shared/                 # Reusable view components
├── Packages/                       # Swift Package Manager local packages
│   ├── VitaCoreContracts/          # Frozen protocols + model types (DO NOT MODIFY)
│   ├── VitaCoreDesign/             # Design system (colours, typography, glass cards)
│   ├── VitaCoreGraph/              # C02: GRDB/SQLite graph store
│   ├── VitaCorePersona/            # C01: PersonaEngine + inferencer
│   ├── VitaCoreThreshold/          # C14: ThresholdEngine + priority stack
│   ├── VitaCoreInference/          # C10: MLX-Swift Gemma runtime + InferenceProvider
│   ├── VitaCoreSkillBus/           # C03: SkillBus + HealthKitSkill + manual entry
│   ├── VitaCoreHeartbeat/          # C09: HeartbeatEngine monitoring loop
│   ├── VitaCoreSynthetic/          # Synthetic data (4 personas, 7 generators)
│   ├── VitaCoreMock/               # Mock implementations for UI preview
│   └── VitaCoreNavigation/         # Navigation router + tab management
├── specs/                          # Spec Kit feature specifications
├── screenshots/                    # Milestone screenshots
├── project.yml                     # xcodegen project definition
└── .specify/                       # Spec Kit templates + constitution
```

## Build Commands

```bash
# Regenerate Xcode project (REQUIRED after project.yml or Package.swift changes)
xcodegen generate

# Build for simulator
xcodebuild -project VitaCore.xcodeproj -scheme VitaCore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build with DEMO_MODE (seeds synthetic data on first launch)
xcodebuild -project VitaCore.xcodeproj -scheme VitaCore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG DEMO_MODE' build

# Run tests for a specific package
cd Packages/VitaCorePersona && swift test
cd Packages/VitaCoreThreshold && swift test
cd Packages/VitaCoreHeartbeat && swift test
```

## Branching Strategy

| Branch | Purpose | Merge Target |
|--------|---------|--------------|
| `main` | Production-ready code. Tagged releases only. | — |
| `develop` | Integration branch. All feature PRs merge here. | `main` via release PR |
| `feature/*` | Individual feature work. One branch per sprint task. | `develop` |
| `fix/*` | Bug fixes. | `develop` or `main` (hotfix) |
| `release/v*` | Release candidates. Cut from `develop`. | `main` + tag |

### Workflow

1. Create `feature/T###-description` from `develop`
2. Implement, write tests, ensure `swift test` passes
3. Open PR to `develop`
4. Reviewer checks: tests pass, no VitaCoreContracts changes, constitution compliance
5. Squash-merge to `develop`
6. When ready to release: cut `release/vX.Y.Z` from `develop`, test on device, merge to `main`, tag

## Architecture Rules (Constitution v1.0.0)

1. **Privacy first.** No PHI over the wire. All inference on-device.
2. **Frozen contracts.** `VitaCoreContracts/Protocols/` is LOCKED. Do not add/remove/rename methods.
3. **Component storage isolation.** Each package owns its own SQLite file. No cross-DB queries.
4. **Test against synthetic data.** All packages that read/write health data must test against `VitaCoreSynthetic` cohorts.
5. **Safety before completeness.** Default to tighter thresholds. Use wellness framing ("pattern", "insight"), not medical framing.

See `.specify/memory/constitution.md` for the full constitution.

## Code Style

- Swift 5.9, strict concurrency (`Sendable`, `actor`)
- `@Observable` view models (iOS 17+)
- SwiftUI only — no UIKit views (UIKit appearance config is the only exception)
- SF Symbols for icons
- Design tokens from `VitaCoreDesign` (VCColors, VCTypography, VCSpacing)
- File naming: `ComponentName.swift` (no prefixes, no `VC` prefix on types)
