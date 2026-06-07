//
//  SwiftletModelIndexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel read benchmarks against the fully indexed `IndexedUser`.
//  One measured method per (operation × type), each parametrized over all sizes.
//

import XCTest
import ParametrizedXCTestCase
import SwiftletModel

final class SwiftletModelIndexedReadTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_equality_int",      { ($0 as! SwiftletModelIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SwiftletModelIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SwiftletModelIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SwiftletModelIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SwiftletModelIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SwiftletModelIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SwiftletModelIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SwiftletModelIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SwiftletModelIndexedReadTests).read_byID($1) }),
        ])
    }

    func read_equality_int(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.age == BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_equality_string(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.firstName == BenchmarkData.targetName).resolve(in: context) }
    }

    func read_notEqual_int(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.age != BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_notEqual_string(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.firstName != BenchmarkData.targetName).resolve(in: context) }
    }

    func read_comparison_int(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.age > BenchmarkData.ageThreshold).resolve(in: context) }
    }

    func read_comparison_string(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.filter(\.firstName > BenchmarkData.nameThreshold).resolve(in: context) }
    }

    func read_sort_int(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.query().sorted(by: \.age).resolve(in: context) }
    }

    func read_sort_string(_ size: Int) {
        let context = Stores.indexedContext(BenchmarkData.records(count: size))
        measureRead { _ = IndexedUser.query().sorted(by: \.firstName).resolve(in: context) }
    }

    func read_byID(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        let context = Stores.indexedContext(records)
        let targetID = records[size / 2].id
        measureRead { _ = IndexedUser.query(targetID).resolve(in: context) }
    }
}
