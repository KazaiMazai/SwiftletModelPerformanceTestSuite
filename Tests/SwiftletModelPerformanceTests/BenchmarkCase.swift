//
//  BenchmarkCase.swift
//  SwiftletModelPerformanceTestSuite
//
//  Base class for all benchmark suites. Provides:
//   - the dataset sizes every suite is parametrized over,
//   - runtime registration of one `test_<name>_<size>` method per (case, size),
//   - thin wrappers around XCTest's measurement APIs for reads and writes.
//

import XCTest
import ParametrizedXCTestCase

class BenchmarkCase: ParametrizedTestCase {

    /// Row counts every benchmark is run against.
    static let sizes = [10, 100, 1_000, 10_000]

    // Warmup (discarded) + measured iteration counts. Reads are cheap to repeat,
    // so they get more; writes rebuild a fresh store every iteration, so fewer.
    static let readRampup = 5
    static let readIterations = 50
    static let writeRampup = 3
    static let writeIterations = 20

    // Subclasses override this and return `registerParametrized(...)`.
    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        []
    }

    /// Synthesises a `test_<name>_<size>` method for every (entry × size) pair.
    /// Each generated method invokes `entry.body(instance, size)`.
    class func registerParametrized(
        _ entries: [(name: String, body: (BenchmarkCase, Int) -> Void)]
    ) -> [_QuickSelectorWrapper] {
        var wrappers: [_QuickSelectorWrapper] = []
        for entry in entries {
            for size in sizes {
                let body = entry.body
                let block: @convention(block) (BenchmarkCase) -> Void = { instance in
                    body(instance, size)
                }
                let implementation = imp_implementationWithBlock(block)
                let selector = NSSelectorFromString("test_\(entry.name)_\(size)")
                class_addMethod(self, selector, implementation, "v@:")
                wrappers.append(_QuickSelectorWrapper(selector: selector))
            }
        }
        return wrappers
    }

    // Each finished test appends its summary row to the CSV.
    override func tearDown() {
        BenchmarkResultsWriter.flush(test: name)
        super.tearDown()
    }

    // MARK: - Measurement helpers
    //
    // A manual warmup + timed loop (instead of XCTest's `measure`) so we control
    // rampup and iteration count: the first `rampup` runs are discarded to reach
    // steady state (warm caches, lazy init, prepared-statement compilation, …),
    // then each of the next `iterations` runs is timed and recorded for the CSV.

    /// Times a read/query closure. The store must already be populated (outside
    /// the measured region) by the caller.
    func measureRead(_ work: () -> Void) {
        for _ in 0..<Self.readRampup { work() }
        for _ in 0..<Self.readIterations {
            let start = DispatchTime.now().uptimeNanoseconds
            work()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            BenchmarkResultsWriter.record(test: name, seconds: Double(elapsed) / 1_000_000_000)
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
            BenchmarkResultsWriter.record(test: name, seconds: Double(elapsed) / 1_000_000_000)
        }
    }
}
