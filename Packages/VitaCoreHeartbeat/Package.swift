// swift-tools-version: 5.9
// VitaCoreHeartbeat — C09 HeartbeatEngine Lite.
//
// Phase 3 Sprint 3.A. The monitoring loop that evaluates readings
// against resolved thresholds and dispatches alerts + triggers
// MiroFish analysis on threshold crossings.

import PackageDescription

let package = Package(
    name: "VitaCoreHeartbeat",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VitaCoreHeartbeat", targets: ["VitaCoreHeartbeat"])
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
            name: "VitaCoreHeartbeat",
            dependencies: ["VitaCoreContracts", "VitaCoreThreshold"]
        ),
        .testTarget(
            name: "VitaCoreHeartbeatTests",
            dependencies: [
                "VitaCoreHeartbeat", "VitaCoreGraph",
                "VitaCoreSynthetic", "VitaCorePersona", "VitaCoreThreshold"
            ]
        )
    ]
)
