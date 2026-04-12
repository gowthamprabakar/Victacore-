// swift-tools-version: 5.9
// VitaCoreSkillBus — C03 SkillBus + Manual Entry Skills.
//
// Phase 2 Sprint 2.A. Owns the data-entry pipeline: manual log
// methods write Reading/Episode records to GraphStoreProtocol.
// Device skills (HealthKit, Dexcom, etc.) register as SkillDescriptors
// and are managed through activate/deactivate/sync lifecycle.

import PackageDescription

let package = Package(
    name: "VitaCoreSkillBus",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VitaCoreSkillBus", targets: ["VitaCoreSkillBus"])
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph"),
        .package(path: "../VitaCoreSynthetic")
    ],
    targets: [
        .target(
            name: "VitaCoreSkillBus",
            dependencies: ["VitaCoreContracts"]
        ),
        .testTarget(
            name: "VitaCoreSkillBusTests",
            dependencies: ["VitaCoreSkillBus", "VitaCoreGraph", "VitaCoreSynthetic"]
        )
    ]
)
