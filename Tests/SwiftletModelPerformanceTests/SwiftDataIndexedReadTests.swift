//
//  SwiftDataIndexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftData read benchmarks against an in-memory store with `#Index` on the
//  queried fields (IndexedSwiftUser). Mirror of SwiftDataReadTests.
//

import XCTest
import ParametrizedXCTestCase
import SwiftData

final class SwiftDataIndexedReadTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_equality_int",      { ($0 as! SwiftDataIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SwiftDataIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SwiftDataIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SwiftDataIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SwiftDataIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SwiftDataIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SwiftDataIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SwiftDataIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SwiftDataIndexedReadTests).read_byID($1) }),
        ])
    }

    private func fetch(_ context: ModelContext, _ descriptor: FetchDescriptor<IndexedSwiftUser>) {
        _ = try! context.fetch(descriptor)
    }

    func read_equality_int(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetAge
        let predicate = #Predicate<IndexedSwiftUser> { $0.age == target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_equality_string(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetName
        let predicate = #Predicate<IndexedSwiftUser> { $0.firstName == target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_notEqual_int(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetAge
        let predicate = #Predicate<IndexedSwiftUser> { $0.age != target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_notEqual_string(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetName
        let predicate = #Predicate<IndexedSwiftUser> { $0.firstName != target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_comparison_int(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let threshold = BenchmarkData.ageThreshold
        let predicate = #Predicate<IndexedSwiftUser> { $0.age > threshold }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_comparison_string(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        let threshold = BenchmarkData.nameThreshold
        let predicate = #Predicate<IndexedSwiftUser> { $0.firstName > threshold }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_sort_int(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        measureRead { fetch(context, FetchDescriptor(sortBy: [SortDescriptor(\.age)])) }
    }

    func read_sort_string(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        measureRead { fetch(context, FetchDescriptor(sortBy: [SortDescriptor(\.firstName)])) }
    }

    func read_byID(_ size: Int) {
        let context = Stores.indexedSwiftDataContext(BenchmarkData.records(count: size))
        var probe = FetchDescriptor<IndexedSwiftUser>()
        probe.fetchLimit = 1
        let targetID = try! context.fetch(probe).first!.id
        let predicate = #Predicate<IndexedSwiftUser> { $0.id == targetID }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }
}
