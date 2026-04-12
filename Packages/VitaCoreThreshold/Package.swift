// swift-tools-version: 5.9
// VitaCoreThreshold — C14 ThresholdEngine.
//
// Wave 1 Sprint 1.A. Resolves per-user metric bands (safe/watch/alert/
// critical) from PersonaContext conditions + medications + clinician
// overrides. Produces a `ThresholdSet` that HeartbeatEngine and Home
// Dashboard consume to classify live readings.

import PackageDescription

let package = Package(
    name: "VitaCoreThreshold",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCoreThreshold",
            targets: ["VitaCoreThreshold"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph"),
        .package(path: "../VitaCoreSynthetic"),
        .package(path: "../VitaCorePersona")
    ],
    targets: [
        .target(
            name: "VitaCoreThreshold",
            dependencies: ["VitaCoreContracts"]
        ),
        .testTarget(
            name: "VitaCoreThresholdTests",
            dependencies: [
                "VitaCoreThreshold",
                "VitaCoreGraph",
                "VitaCoreSynthetic",
                "VitaCorePersona"
            ]
        )
    ]
)
