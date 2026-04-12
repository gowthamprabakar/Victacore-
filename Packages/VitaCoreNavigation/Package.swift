// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VitaCoreNavigation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "VitaCoreNavigation",
            targets: ["VitaCoreNavigation"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts")
    ],
    targets: [
        .target(
            name: "VitaCoreNavigation",
            dependencies: ["VitaCoreContracts"],
            path: "Sources/VitaCoreNavigation"
        )
    ]
)
