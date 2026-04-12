// Gemma4RuntimeTests.swift
// VitaCoreInference — Smoke tests for Gemma4Runtime.
//
// The real integration test (download weights → load → stream tokens) is
// marked `.disabled` by default because it requires ~3 GB of network
// download and several seconds of compute. Flip the `runOnDeviceBenchmark`
// flag or run via the companion benchmark executable to exercise it.

import Foundation
import CoreImage
import Testing
@testable import VitaCoreInference

// MARK: - Unit-level smoke tests

@Test("Runtime starts in unloaded state")
func testInitialState() async {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let loadDuration = await runtime.lastLoadDuration
    let peak = await runtime.lastLoadPeakMemoryBytes
    #expect(loadDuration == 0)
    #expect(peak == 0)
}

@Test("Generate before load throws modelNotLoaded")
func testGenerateBeforeLoadThrows() async {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    let stream = runtime.generate(prompt: "Hello", maxTokens: 8)

    do {
        for try await _ in stream { }
        Issue.record("Expected modelNotLoaded error")
    } catch let error as Gemma4Error {
        #expect(error == .modelNotLoaded)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Quantisation rawValues map to the expected HuggingFace repos")
func testQuantisationIds() {
    #expect(Gemma4Runtime.Quantisation.gemma3n_q4.rawValue == "mlx-community/gemma-3n-E4B-it-4bit")
    #expect(Gemma4Runtime.Quantisation.gemma3n_q8.rawValue == "mlx-community/gemma-3n-E4B-it-8bit")
    #expect(Gemma4Runtime.Quantisation.gemma4_q4.rawValue == "mlx-community/gemma-4-e4b-it-4bit")
}

@Test("Gemma 4 quantisations are flagged as not yet supported")
func testGemma4FlaggedAsUnsupported() async {
    #expect(Gemma4Runtime.Quantisation.gemma3n_q4.isSupportedByCurrentMLX == true)
    #expect(Gemma4Runtime.Quantisation.gemma3n_q8.isSupportedByCurrentMLX == true)
    #expect(Gemma4Runtime.Quantisation.gemma4_q4.isSupportedByCurrentMLX == false)
}

@Test("Generate signature accepts optional image for multimodal input")
func testMultimodalSignature() async {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)
    // Compile-time check: the overload takes an optional CIImage so the
    // food-photo path (MiroFish) and the text-only chat path share the
    // same entry point.
    let blank = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
    let stream = runtime.generate(prompt: "describe", image: blank, maxTokens: 4)
    do {
        for try await _ in stream { }
        Issue.record("Expected modelNotLoaded error")
    } catch let error as Gemma4Error {
        #expect(error == .modelNotLoaded)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Load on a Gemma 4 quantisation throws unsupportedByCurrentMLX")
func testLoadGemma4Throws() async {
    let runtime = Gemma4Runtime(quantisation: .gemma4_q4)
    do {
        try await runtime.load()
        Issue.record("Expected unsupportedByCurrentMLX error")
    } catch let error as Gemma4Error {
        if case .unsupportedByCurrentMLX = error {
            // ok
        } else {
            Issue.record("Unexpected Gemma4Error: \(error)")
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

// MARK: - On-device benchmark (opt-in)

/// Flip this to `true` on an Apple Silicon Mac or physical iPhone 15 Pro+
/// to run the full download + generate benchmark. It is NOT expected to
/// run in CI or in the sim (MLX Metal path is too slow under Rosetta).
private let runOnDeviceBenchmark = false

@Test("On-device: load + stream generate", .disabled(if: !runOnDeviceBenchmark))
func testLoadAndStreamBenchmark() async throws {
    let runtime = Gemma4Runtime(quantisation: .gemma3n_q4)

    try await runtime.load { fraction in
        // Simple console breadcrumbs for manual runs.
        print(String(format: "  download: %.1f%%", fraction * 100))
    }
    let loadDuration = await runtime.lastLoadDuration
    let peakBytes = await runtime.lastLoadPeakMemoryBytes
    print("✅ Loaded in \(String(format: "%.2f", loadDuration))s, peak RAM \(peakBytes / 1_048_576) MB")

    // Stream a short response and count tokens / measure first-token latency.
    var firstTokenAt: Date?
    var chunkCount = 0
    var totalChars = 0
    let prompt = "In one sentence, what is a healthy fasting glucose range?"
    let streamStart = Date()

    for try await delta in runtime.generate(prompt: prompt, maxTokens: 128) {
        if firstTokenAt == nil { firstTokenAt = Date() }
        chunkCount += 1
        totalChars += delta.count
    }

    let end = Date()
    let totalSeconds = end.timeIntervalSince(streamStart)
    let firstTokenLatency = firstTokenAt.map { $0.timeIntervalSince(streamStart) } ?? 0

    print("✅ First token in \(String(format: "%.2f", firstTokenLatency))s")
    print("✅ Streamed \(chunkCount) chunks / \(totalChars) chars in \(String(format: "%.2f", totalSeconds))s")

    #expect(chunkCount > 0)
    #expect(totalChars > 0)
    _ = loadDuration   // silence unused warnings
    _ = peakBytes
}
