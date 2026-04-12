// swift-tools-version: 5.9
// VitaCoreInference — On-device LLM runtime (Gemma 4 E4B via MLX-Swift).
//
// Wave 0 Sprint 0.2 proof-of-concept: demonstrates that MLX-Swift can load
// `mlx-community/gemma-4-e4b-it-4bit` on iPhone 15 Pro and stream tokens
// through a protocol-conformant runtime, unblocking C10 Gemma4Runtime.

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
        // MLX-Swift model containers, tokenizers, LLM generation loop.
        // mlx-swift-examples vends `MLXLLM`, `MLXLMCommon`, and friends as
        // SwiftPM products; pinning to 2.x (the current major) keeps us on
        // the stable API surface that supports Gemma 4 out of the box.
        .package(
            url: "https://github.com/ml-explore/mlx-swift-examples.git",
            from: "2.29.1"
        )
    ],
    targets: [
        .target(
            name: "VitaCoreInference",
            dependencies: [
                "VitaCoreContracts",
                // Text-only LLM runtime (kept for small-model fallbacks).
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                // Vision-language runtime. Gemma 3n E4B full multimodal
                // (text + vision + audio) loads through this path via
                // `VLMModelFactory` + `VLMRegistry` entries. This is the
                // main runtime VitaCore targets for Wave 5.
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
                // Shared language-model plumbing (tokeniser, KV cache,
                // generate loop, UserInput types with image support).
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ]
        ),
        .testTarget(
            name: "VitaCoreInferenceTests",
            dependencies: ["VitaCoreInference"]
        )
    ]
)
