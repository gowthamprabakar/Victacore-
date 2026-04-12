// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VitaCoreMock",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "VitaCoreMock",
            targets: ["VitaCoreMock"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts")
    ],
    targets: [
        .target(
            name: "VitaCoreMock",
            dependencies: ["VitaCoreContracts"],
            path: "Sources/VitaCoreMock"
        )
    ]
)
