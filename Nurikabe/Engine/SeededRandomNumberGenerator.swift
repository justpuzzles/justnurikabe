//
//  SeededRandomNumberGenerator.swift
//  Nurikabe
//
//  Deterministic RNG, ported from the sibling apps. Generation must be
//  bit-reproducible per seed — baked fallback proofs and generation tests
//  depend on it, and the system RNG guarantees no such thing.
//

import Foundation

/// SplitMix64. Small, fast, and its output is fully specified by the algorithm,
/// so it is reproducible across platforms and Swift versions.
nonisolated struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the all-zero state, whose first outputs are poor.
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
