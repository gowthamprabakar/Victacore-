// swift-tools-version: 5.9
// VitaCoreSynthetic — Deterministic multi-persona synthetic health data.
//
// Wave 0 Sprint 0.3. Emits `Reading`, `Episode`, and `PersonaContext`
// domain types directly into any `GraphStoreProtocol` (tests use an
// in-memory `GRDBGraphStore`, production demo mode writes into the real
// store). Seeded RNG guarantees byte-identical output for a given seed,
// so test fixtures, demo cohorts, and reviewer builds are reproducible.

import PackageDescription

let package = Package(
    name: "VitaCoreSynthetic",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCoreSynthetic",
            targets: ["VitaCoreSynthetic"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph")
    ],
    targets: [
        .target(
            name: "VitaCoreSynthetic",
            dependencies: [
                "VitaCoreContracts"
            ]
        ),
        .testTarget(
            name: "VitaCoreSyntheticTests",
            dependencies: [
                "VitaCoreSynthetic",
                "VitaCoreGraph"
            ]
        )
    ]
)
