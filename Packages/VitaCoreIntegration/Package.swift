// swift-tools-version: 5.9
// VitaCoreIntegration — Cross-package integration tests.
//
// Sprint 3.D. Proves the full VitaCore pipeline works end-to-end
// across all packages. This package has no source files — it exists
// solely to host integration tests that import every real package.

import PackageDescription

let package = Package(
    name: "VitaCoreIntegration",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph"),
        .package(path: "../VitaCoreSynthetic"),
        .package(path: "../VitaCorePersona"),
        .package(path: "../VitaCoreThreshold"),
        .package(path: "../VitaCoreSkillBus"),
        .package(path: "../VitaCoreHeartbeat"),
        .package(path: "../VitaCoreMiroFish")
    ],
    targets: [
        .target(
            name: "VitaCoreIntegration",
            dependencies: ["VitaCoreContracts"]
        ),
        .testTarget(
            name: "VitaCoreIntegrationTests",
            dependencies: [
                "VitaCoreContracts",
                "VitaCoreGraph",
                "VitaCoreSynthetic",
                "VitaCorePersona",
                "VitaCoreThreshold",
                "VitaCoreSkillBus",
                "VitaCoreHeartbeat",
                "VitaCoreMiroFish"
            ]
        )
    ]
)
