//
//  BenchmarkCase.swift
//  SwiftletModelPerformanceTestSuite
//
//  Base class for all benchmark suites. Provides:
//   - the dataset sizes every suite is parametrized over,
//   - the engine/indexing/access metadata derived from the subclass name,
//   - manual rampup + timed measurement loops for reads and writes.
//
//  No XCTest: suites are plain classes listed in the `benchmarks` runner, which
//  runs each declared case over every size and records timings to CSV.
//

import Foundation

/// Identifies one measured result (a single case at a single size) and the file
/// it belongs to. The `id` is the accumulation/lookup key for the writer.
struct BenchmarkKey {
    let engine, indexing, access, operation, valueType: String
    let size: Int
    let file: String   // "results.csv" or "relational.csv"

    var id: String { "\(engine)|\(indexing)|\(access)|\(operation)|\(valueType)|\(size)|\(file)" }
}

class BenchmarkCase {

    required init() {}

    /// Set by the runner before each case body runs; the measure helpers record
    /// their samples against it.
    var current: BenchmarkKey!

    /// Row counts every benchmark is run against.
    static let sizes = [10, 100, 1_000, 10_000]

    // Warmup (discarded) + measured iteration counts. Reads are cheap to repeat,
    // so they get more; writes rebuild a fresh store every iteration, so fewer.
    static let readRampup = 5
    static let readIterations = 50
    static let writeRampup = 3
    static let writeIterations = 20

    /// Subclasses override this to declare their cases. Each entry's `name` is
    /// `<access>_<operation>[_<valueType>]` (e.g. `read_equality_int`,
    /// `write_insert_hash`); the runner expands it over all sizes.
    class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] { [] }

    // MARK: - Metadata derived from the concrete subclass name

    static var suiteName: String { String(describing: self) }

    static var engine: String {
        let n = suiteName
        return n.hasPrefix("SwiftletModel") ? "SwiftletModel"
            : n.hasPrefix("SQLiteData") ? "SQLiteData"
            : n.hasPrefix("SwiftData") ? "SwiftData"
            : n.hasPrefix("GRDB") ? "GRDB"
            : n.hasPrefix("Realm") ? "Realm" : "Unknown"
    }

    static var indexing: String {
        let n = suiteName
        return n.contains("Unindexed") ? "unindexed"
            : n.contains("Indexed") ? "indexed" : "default"
    }

    static var access: String {
        let n = suiteName
        return n.contains("Write") ? "write" : n.contains("Read") ? "read" : "unknown"
    }

    /// Relational (Northwind) suites write to their own file.
    static var file: String { suiteName.contains("Northwind") ? "relational.csv" : "results.csv" }

    /// Splits a case name into `(operation, valueType)`:
    /// `read_equality_int` → (`equality`, `int`); `write_insert_hash` →
    /// (`insert`, `hash`); `read_invoices` → (`invoices`, `-`).
    static func parse(name: String) -> (operation: String, valueType: String) {
        let comps = name.split(separator: "_").map(String.init)
        let operation = comps.count > 1 ? comps[1] : (comps.first ?? name)
        let valueType = comps.count > 2 ? comps[2] : "-"
        return (operation, valueType)
    }

    // MARK: - Measurement helpers
    //
    // A manual warmup + timed loop so we control rampup and iteration count: the
    // first `rampup` runs are discarded to reach steady state (warm caches, lazy
    // init, prepared-statement compilation, …), then each of the next
    // `iterations` runs is timed and recorded for the CSV.

    /// Times a read/query closure. The store must already be populated (outside
    /// the measured region) by the caller.
    func measureRead(_ work: () -> Void) {
        for _ in 0..<Self.readRampup { work() }
        for _ in 0..<Self.readIterations {
            let start = DispatchTime.now().uptimeNanoseconds
            work()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            BenchmarkResultsWriter.record(current, seconds: Double(elapsed) / 1_000_000_000)
        }
    }

    /// Times a write closure with per-iteration setup kept *out* of the timed
    /// region. `prepare` runs before each iteration (build a fresh store and any
    /// pre-mutated objects); only `work` is timed and recorded.
    func measureWrite<State>(prepare: () -> State, work: (State) -> Void) {
        for _ in 0..<Self.writeRampup {
            let state = prepare()
            work(state)
        }
        for _ in 0..<Self.writeIterations {
            let state = prepare()
            let start = DispatchTime.now().uptimeNanoseconds
            work(state)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            BenchmarkResultsWriter.record(current, seconds: Double(elapsed) / 1_000_000_000)
        }
    }
}
