// swift-tools-version: 5.9
// VitaCoreInference — On-device LLM runtime + food database + inference provider.

import PackageDescription

let package = Package(
    name: "VitaCoreInference",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaCoreInference",
            targets: ["VitaCoreInference"]
        )
    ],
    dependencies: [
        .package(path: "../VitaCoreContracts"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-examples.git",
            from: "2.29.1"
        ),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            from: "7.10.0"
        )
    ],
    targets: [
        .target(
            name: "VitaCoreInference",
            dependencies: [
                "VitaCoreContracts",
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [
                .copy("vitacore_food.sqlite")
            ]
        ),
        .testTarget(
            name: "VitaCoreInferenceTests",
            dependencies: ["VitaCoreInference"]
        )
    ]
)
