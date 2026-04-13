// swift-tools-version: 5.9
// VitaCoreMiroFish — C18 MiroFish MVP + C19 Analytics Core.
//
// Sprint 3.B. Single MetabolismAgent (Gemma-powered) + deterministic
// multi-cofactor RCA engine. The core value proposition of VitaCore:
// correlate glucose, meals, sleep, exercise, medications across time
// to find root causes and generate actionable prescription cards.

import PackageDescription

let package = Package(
    name: "VitaCoreMiroFish",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VitaCoreMiroFish", targets: ["VitaCoreMiroFish"])
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph"),
        .package(path: "../VitaCoreSynthetic"),
        .package(path: "../VitaCorePersona"),
        .package(path: "../VitaCoreThreshold")
    ],
    targets: [
        .target(
            name: "VitaCoreMiroFish",
            dependencies: ["VitaCoreContracts"]
        ),
        .testTarget(
            name: "VitaCoreMiroFishTests",
            dependencies: [
                "VitaCoreMiroFish", "VitaCoreGraph",
                "VitaCoreSynthetic", "VitaCorePersona", "VitaCoreThreshold"
            ]
        )
    ]
)
