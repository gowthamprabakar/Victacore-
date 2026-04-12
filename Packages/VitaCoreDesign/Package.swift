// swift-tools-version: 5.9
// VitaCoreDesign — Design system package for VitaCore
// Ethereal Light theme, iOS 26 Liquid Glass, zero external dependencies

import PackageDescription

let package = Package(
    name: "VitaCoreDesign",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "VitaCoreDesign",
            targets: ["VitaCoreDesign"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VitaCoreDesign",
            dependencies: [],
            path: "Sources/VitaCoreDesign"
        )
    ]
)
