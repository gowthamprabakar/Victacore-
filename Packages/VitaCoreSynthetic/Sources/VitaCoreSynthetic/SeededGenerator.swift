// SeededGenerator.swift
// VitaCoreSynthetic — Deterministic random-number source.
//
// We can't use `SystemRandomNumberGenerator` because it's non-deterministic
// by design. Instead we implement **SplitMix64** — the reference seeding
// generator from Vigna 2014, used as the "seed expander" for xoshiro/xorshiro
// families. It's 64-bit, passes TestU01 BigCrush, has zero state overhead
// beyond a single `UInt64`, and produces byte-identical sequences for a
// given seed across Swift releases and Apple architectures.
//
// This generator is the single source of randomness for every generator
// in `VitaCoreSynthetic`. Tests rely on its reproducibility — changing the
// algorithm is a breaking change to every committed fixture.

import Foundation

// MARK: - SeededGenerator

/// Deterministic pseudo-random number generator implementing SplitMix64.
/// Thread-safety: this type is a value type and is NOT safe to mutate
/// from multiple threads simultaneously. Pass a fresh copy per task.
public struct SeededGenerator: RandomNumberGenerator, Sendable {

    private var state: UInt64

    public init(seed: UInt64) {
        // Avoid the degenerate all-zero state; SplitMix64 handles zero
        // correctly but we mix in a non-zero constant for safety so users
        // who pass `seed: 0` still get a sensible stream.
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // MARK: Convenience helpers shared by every generator

    /// Uniform `Double` in `[0, 1)`.
    public mutating func nextUnitInterval() -> Double {
        // Top 53 bits → double precision mantissa.
        let top53 = next() >> 11
        return Double(top53) / Double(1 << 53)
    }

    /// Uniform `Double` in the closed range `[low, high]`.
    public mutating func nextUniform(_ low: Double, _ high: Double) -> Double {
        low + (high - low) * nextUnitInterval()
    }

    /// Standard normal (mean 0, stdev 1) via Box–Muller.
    public mutating func nextGaussian() -> Double {
        // Guard against log(0) producing -∞.
        var u1 = nextUnitInterval()
        while u1 < .leastNormalMagnitude { u1 = nextUnitInterval() }
        let u2 = nextUnitInterval()
        let r = (-2.0 * log(u1)).squareRoot()
        let theta = 2.0 * Double.pi * u2
        return r * cos(theta)
    }

    /// Gaussian with given mean and standard deviation.
    public mutating func nextGaussian(mean: Double, stdev: Double) -> Double {
        mean + stdev * nextGaussian()
    }

    /// Bernoulli trial — returns `true` with probability `p`.
    public mutating func nextBernoulli(_ p: Double) -> Bool {
        nextUnitInterval() < p
    }

    /// Uniform integer in the closed range `[low, high]`.
    public mutating func nextInt(_ low: Int, _ high: Int) -> Int {
        precondition(high >= low, "SeededGenerator.nextInt: high < low")
        let span = UInt64(high - low + 1)
        return low + Int(next() % span)
    }

    /// Picks a random element from a non-empty collection.
    public mutating func pick<T>(_ elements: [T]) -> T {
        precondition(!elements.isEmpty, "SeededGenerator.pick: empty array")
        return elements[nextInt(0, elements.count - 1)]
    }
}

