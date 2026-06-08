//
//  SwiftDataIndexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftData read benchmarks against in-memory stores indexed on a single field
//  (B-tree `#Index`): int queries hit `SwiftUserAgeIndexed`, string queries hit
//  `SwiftUserNameIndexed`, so each read measures one index in isolation.
//

import Foundation
import SwiftData

final class SwiftDataIndexedReadTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("read_equality_int",      { ($0 as! SwiftDataIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SwiftDataIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SwiftDataIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SwiftDataIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SwiftDataIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SwiftDataIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SwiftDataIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SwiftDataIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SwiftDataIndexedReadTests).read_byID($1) }),
        ]
    }

    private func fetch<T: PersistentModel>(_ context: ModelContext, _ descriptor: FetchDescriptor<T>) {
        _ = try! context.fetch(descriptor)
    }

    // Int queries → entity indexed on `age`.
    func read_equality_int(_ size: Int) {
        let context = Stores.ageIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetAge
        let predicate = #Predicate<SwiftUserAgeIndexed> { $0.age == target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_notEqual_int(_ size: Int) {
        let context = Stores.ageIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetAge
        let predicate = #Predicate<SwiftUserAgeIndexed> { $0.age != target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_comparison_int(_ size: Int) {
        let context = Stores.ageIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let threshold = BenchmarkData.ageThreshold
        let predicate = #Predicate<SwiftUserAgeIndexed> { $0.age > threshold }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_sort_int(_ size: Int) {
        let context = Stores.ageIndexedSwiftDataContext(BenchmarkData.records(count: size))
        measureRead { fetch(context, FetchDescriptor<SwiftUserAgeIndexed>(sortBy: [SortDescriptor(\.age)])) }
    }

    // String queries → entity indexed on `firstName`.
    func read_equality_string(_ size: Int) {
        let context = Stores.nameIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetName
        let predicate = #Predicate<SwiftUserNameIndexed> { $0.firstName == target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_notEqual_string(_ size: Int) {
        let context = Stores.nameIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let target = BenchmarkData.targetName
        let predicate = #Predicate<SwiftUserNameIndexed> { $0.firstName != target }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_comparison_string(_ size: Int) {
        let context = Stores.nameIndexedSwiftDataContext(BenchmarkData.records(count: size))
        let threshold = BenchmarkData.nameThreshold
        let predicate = #Predicate<SwiftUserNameIndexed> { $0.firstName > threshold }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }

    func read_sort_string(_ size: Int) {
        let context = Stores.nameIndexedSwiftDataContext(BenchmarkData.records(count: size))
        measureRead { fetch(context, FetchDescriptor<SwiftUserNameIndexed>(sortBy: [SortDescriptor(\.firstName)])) }
    }

    // byID → primary key; entity choice is irrelevant.
    func read_byID(_ size: Int) {
        let context = Stores.nameIndexedSwiftDataContext(BenchmarkData.records(count: size))
        var probe = FetchDescriptor<SwiftUserNameIndexed>()
        probe.fetchLimit = 1
        let targetID = try! context.fetch(probe).first!.id
        let predicate = #Predicate<SwiftUserNameIndexed> { $0.id == targetID }
        measureRead { fetch(context, FetchDescriptor(predicate: predicate)) }
    }
}
