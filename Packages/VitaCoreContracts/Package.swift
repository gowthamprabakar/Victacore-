// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VitaCoreContracts",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCoreContracts",
            targets: ["VitaCoreContracts"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VitaCoreContracts",
            dependencies: [],
            path: "Sources/VitaCoreContracts"
        )
    ]
)
