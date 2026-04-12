// swift-tools-version: 5.9
// VitaCorePersona — C01 PersonaEngine implementation.
//
// Wave 1 Sprint 1.1. Provides a persistent, GRDB-backed persona store
// plus a graph-driven inferencer that can auto-populate a starter
// PersonaContext from the user's reading history. Conforms to the
// frozen `PersonaEngineProtocol` contract from VitaCoreContracts so it
// is a zero-friction drop-in for the mock currently used by the app.

import PackageDescription

let package = Package(
    name: "VitaCorePersona",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCorePersona",
            targets: ["VitaCorePersona"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(path: "../VitaCoreGraph"),
        .package(path: "../VitaCoreSynthetic"),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            from: "7.10.0"
        )
    ],
    targets: [
        .target(
            name: "VitaCorePersona",
            dependencies: [
                "VitaCoreContracts",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "VitaCorePersonaTests",
            dependencies: [
                "VitaCorePersona",
                "VitaCoreGraph",
                "VitaCoreSynthetic",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        )
    ]
)
