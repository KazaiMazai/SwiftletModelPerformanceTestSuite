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
//    static let sizes = [1_000]
//    static let sizes = [1_000, 5_000, 10_000]
    static let sizes = [10, 100, 1_000, 10_000, 100_000]

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

    /// Measures a read/query closure. The store must already be populated
    /// (outside the measured region) by the caller. Each iteration's duration
    /// is also recorded for CSV export.
    func measureRead(_ work: () -> Void) {
        measure {
            let start = DispatchTime.now().uptimeNanoseconds
            work()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            BenchmarkResultsWriter.record(test: self.name, seconds: Double(elapsed) / 1_000_000_000)
        }
    }

    /// Measures a write closure with per-iteration setup kept *out* of the
    /// measured region. `prepare` runs before each measured iteration (build a
    /// fresh store and any pre-mutated objects); only `work` is timed and
    /// recorded for CSV export.
    func measureWrite<State>(prepare: () -> State, work: (State) -> Void) {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            let state = prepare()
            let start = DispatchTime.now().uptimeNanoseconds
            self.startMeasuring()
            work(state)
            self.stopMeasuring()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            BenchmarkResultsWriter.record(test: self.name, seconds: Double(elapsed) / 1_000_000_000)
        }
    }
}
