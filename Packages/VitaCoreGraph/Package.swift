// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VitaCoreGraph",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCoreGraph",
            targets: ["VitaCoreGraph"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.10.0")
    ],
    targets: [
        .target(
            name: "VitaCoreGraph",
            dependencies: [
                "VitaCoreContracts",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/VitaCoreGraph"
        ),
        .testTarget(
            name: "VitaCoreGraphTests",
            dependencies: ["VitaCoreGraph"],
            path: "Tests/VitaCoreGraphTests"
        )
    ]
)
