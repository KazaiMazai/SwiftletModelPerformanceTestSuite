//
//  BenchmarkDataset.swift
//  RealmVsSwiftDataBenchmarks
//
//  Deterministic, engine-agnostic dataset. The same records feed SwiftletModel,
//  SwiftData and Realm so every engine queries identical data and result-set
//  sizes are comparable. A seeded PRNG makes runs reproducible.
//

import Foundation

/// Deterministic SplitMix64 generator so the dataset is identical run-to-run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A single engine-agnostic user row.
struct UserRecord {
    let id: UUID
    let firstName: String
    let surname: String
    let age: Int
}

enum BenchmarkData {

    // Shared query targets — chosen so every operation has a non-trivial,
    // comparable result set at all sizes.
    static let targetName = "Jane"      // equality / non-equality (String)
    static let targetAge = 42           // equality / non-equality (Int)
    static let ageThreshold = 50        // comparison: age > 50
    static let nameThreshold = "M"      // comparison: firstName > "M"
    static let mutatedName = "Wendy"    // value written by update benchmarks

    /// Builds `count` deterministic records. Every 20th row is forced to
    /// `targetName` and every 25th row to `targetAge` so equality/non-equality
    /// queries always have matches, even at the smallest size.
    static func records(count: Int) -> [UserRecord] {
        var rng = SeededGenerator(seed: 0x1234_ABCD_5678_EF90)
        var records: [UserRecord] = []
        records.reserveCapacity(count)

        for index in 0..<count {
            let firstName = (index % 20 == 0)
                ? targetName
                : (firstNames.randomElement(using: &rng) ?? targetName)
            let surname = surnames.randomElement(using: &rng) ?? "Smith"
            let age = (index % 25 == 0)
                ? targetAge
                : Int.random(in: 0..<99, using: &rng)

            records.append(UserRecord(id: UUID(), firstName: firstName, surname: surname, age: age))
        }
        return records
    }
}
