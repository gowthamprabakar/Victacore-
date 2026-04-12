// Gemma4Runtime.swift
// VitaCoreInference — Gemma on-device multimodal runtime via MLX-Swift.
//
// Wave 0 Sprint 0.2 proof of concept.
//
// Core spec (from VITACORE_IDEOLOGY_v2.0): ONE on-device multimodal model
// handles text generation, image analysis (meal photos, plate detection),
// and optionally audio / speech understanding. Privacy-first — no PHI
// ever leaves the device during inference. Initial model download from
// HuggingFace (one-time, cached in app sandbox) is the only network
// touchpoint and can be gated by explicit user consent.
//
// Runtime plumbing: this file loads a VLM into an MLX `ModelContainer`
// via `VLMModelFactory` and streams generated tokens as decoded text
// deltas. Callers may attach an optional `UIImage` (rendered to a
// `CIImage` input) to exercise the vision tower.
//
// Target selection (2026-04-11):
//   • Spec target: `mlx-community/gemma-4-e4b-it-4bit` (multimodal).
//     Blocked: mlx-swift-examples 2.29.1 has no `gemma4` VLM module.
//   • Shipping today: `mlx-community/gemma-3n-E4B-it-4bit` via MLXVLM.
//     Same effective-4B Per-Layer-Embeddings backbone, natively
//     text + vision + audio, recognised by `VLMRegistry`. Swap to
//     Gemma 4 is a one-line Quantisation enum flip when upstream ships.

import Foundation
import CoreImage
import MLXLMCommon
import MLXVLM

// MARK: - Gemma4Runtime

/// Actor-isolated wrapper around an MLX `ModelContainer` holding a
/// quantised multimodal Gemma 3n / Gemma 4 E4B model. Use `load()` once,
/// then call `generate(prompt:image:maxTokens:)` to stream text.
public actor Gemma4Runtime {

    // -------------------------------------------------------------------------
    // MARK: Model identifiers
    // -------------------------------------------------------------------------

    /// Quantised on-device model target.
    ///
    /// **Architecture note (Wave 0, 2026-04-11):** `mlx-swift-examples`
    /// 2.29.1 — the latest release as of this sprint — does NOT yet ship
    /// a `gemma4` model-type mapping. The `mlx-community/gemma-4-e4b-*`
    /// weights declare `model_type: "gemma4"` and require a
    /// `Gemma4ForConditionalGeneration` implementation in `MLXVLM` which
    /// has not been ported yet.
    ///
    /// The nearest shipping-today equivalent is **Gemma 3n E4B full
    /// multimodal**, which uses the same effective-4B / Per-Layer
    /// Embeddings backbone as Gemma 4 E4B and is already supported by
    /// `MLXVLM` via its Gemma3 VL entries in `VLMRegistry`. We default to
    /// it for the Wave 0 PoC so the full MiroFish pipeline (photo → food
    /// breakdown → text explanation) can be validated end-to-end today;
    /// the moment `mlx-swift-examples` ships `gemma4` support, flipping
    /// the default to `.gemma4_q4` is a one-line change with no other
    /// call-site churn because everything downstream talks to the opaque
    /// `Quantisation` enum and not the model id.
    public enum Quantisation: String, Sendable, CaseIterable {

        // --- Shipping today (MLXVLM path) -------------------------------

        /// Gemma 3n E4B, 4-bit, **full multimodal** (text + vision + audio).
        /// Wave 0 PoC default. Fits the 8 GB RAM budget of iPhone 15 Pro
        /// with headroom for the rest of the app.
        case gemma3n_q4 = "mlx-community/gemma-3n-E4B-it-4bit"

        /// Gemma 3n E4B, 8-bit, full multimodal. Opt-in for iPhone 16/17
        /// Pro (12 GB RAM) where the extra memory enables higher-precision
        /// weights without compromising Wave 5 agent performance.
        case gemma3n_q8 = "mlx-community/gemma-3n-E4B-it-8bit"

        // --- Pending MLX runtime support --------------------------------

        /// Gemma 4 E4B, 4-bit. **Not yet loadable** —
        /// `mlx-swift-examples` does not ship a `gemma4` architecture
        /// module as of 2.29.1. Listed here for forward compatibility
        /// only; we will flip `gemma3n_q4` → `gemma4_q4` as the default
        /// once upstream ships support.
        case gemma4_q4 = "mlx-community/gemma-4-e4b-it-4bit"

        /// Whether MLXVLM can actually load this quantisation today.
        public var isSupportedByCurrentMLX: Bool {
            switch self {
            case .gemma3n_q4, .gemma3n_q8: return true
            case .gemma4_q4:               return false
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: State
    // -------------------------------------------------------------------------

    private let quantisation: Quantisation
    private var container: ModelContainer?

    /// Seconds the last `load()` call took. Populated after load completes.
    public private(set) var lastLoadDuration: TimeInterval = 0

    /// Peak resident memory (bytes) observed during the last `load()` call.
    public private(set) var lastLoadPeakMemoryBytes: UInt64 = 0

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    public init(quantisation: Quantisation = .gemma3n_q4) {
        self.quantisation = quantisation
    }

    // -------------------------------------------------------------------------
    // MARK: Load
    // -------------------------------------------------------------------------

    /// Downloads (first run) and loads the VLM into memory. Safe to call
    /// multiple times; subsequent calls are no-ops once the container
    /// exists.
    ///
    /// - Parameter progress: Optional callback receiving download progress
    ///   in the range 0...1 while weights are being fetched.
    public func load(
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard container == nil else { return }
        guard quantisation.isSupportedByCurrentMLX else {
            throw Gemma4Error.unsupportedByCurrentMLX(quantisation.rawValue)
        }

        // Register the model configuration with the shared VLM factory.
        // This lets us pass arbitrary HuggingFace ids without having to
        // patch `VLMRegistry` in the mlx-swift-examples package.
        let configuration = ModelConfiguration(id: quantisation.rawValue)
        VLMModelFactory.shared.modelRegistry.register(
            configurations: [configuration]
        )

        let start = Date()

        self.container = try await VLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { update in
            progress?(update.fractionCompleted)
        }

        self.lastLoadDuration = Date().timeIntervalSince(start)
        self.lastLoadPeakMemoryBytes = Self.currentResidentBytes()
    }

    // -------------------------------------------------------------------------
    // MARK: Generate (streaming, multimodal)
    // -------------------------------------------------------------------------

    /// Streams a model response token-by-token as decoded text chunks.
    ///
    /// - Parameters:
    ///   - prompt: User prompt. Callers are responsible for any system-
    ///     prompt / instruction wrapping appropriate to Gemma's chat
    ///     template.
    ///   - image: Optional input image. When supplied, the vision tower
    ///     is exercised and the prompt becomes an image-grounded query.
    ///     Pass `nil` for a text-only generation.
    ///   - maxTokens: Upper bound on generated tokens. Defaults to 256.
    ///   - temperature: Sampling temperature. Defaults to 0.7.
    /// - Returns: An `AsyncThrowingStream` yielding incremental text
    ///   deltas (empty deltas are filtered).
    public nonisolated func generate(
        prompt: String,
        image: CIImage? = nil,
        maxTokens: Int = 256,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runGeneration(
                        prompt: prompt,
                        image: image,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runGeneration(
        prompt: String,
        image: CIImage?,
        maxTokens: Int,
        temperature: Float,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let container else {
            throw Gemma4Error.modelNotLoaded
        }

        let parameters = GenerateParameters(temperature: temperature)

        // Build UserInput: text-only or image-grounded.
        let userInput: UserInput
        if let image {
            userInput = UserInput(
                prompt: prompt,
                images: [.ciImage(image)]
            )
        } else {
            userInput = UserInput(prompt: prompt)
        }

        _ = try await container.perform { context in
            let input = try await context.processor.prepare(input: userInput)

            // Running-decoded text so we can yield deltas rather than the
            // full string each callback. MLX-Swift's generate callback is
            // invoked once per emitted token with the cumulative token
            // array; we compute the text delta and stream it.
            var previousText = ""

            return try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            ) { tokens in
                let currentText = context.tokenizer.decode(tokens: tokens)
                if currentText.count > previousText.count {
                    let delta = String(
                        currentText[
                            currentText.index(
                                currentText.startIndex,
                                offsetBy: previousText.count
                            )...
                        ]
                    )
                    if !delta.isEmpty {
                        continuation.yield(delta)
                    }
                    previousText = currentText
                }
                return tokens.count >= maxTokens ? .stop : .more
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Memory telemetry
    // -------------------------------------------------------------------------

    /// Returns current resident memory (bytes) using `mach_task_basic_info`.
    /// Used by benchmarks to report peak RAM after model load.
    private static func currentResidentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Errors

public enum Gemma4Error: Error, LocalizedError, Sendable, Equatable {
    case modelNotLoaded
    case unsupportedByCurrentMLX(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Gemma runtime has not been loaded. Call load() first."
        case .unsupportedByCurrentMLX(let id):
            return "\(id) is not yet supported by mlx-swift-examples. " +
                   "Use a `.gemma3n_*` quantisation until gemma4 support ships."
        }
    }
}
