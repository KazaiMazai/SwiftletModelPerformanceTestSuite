//
//  SwiftDataIndexedWriteTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  SwiftData write benchmarks against an in-memory store with `#Index`
//  (IndexedSwiftUser). Shows the index-maintenance cost on writes.
//

import XCTest
import ParametrizedXCTestCase
import SwiftData

final class SwiftDataIndexedWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! SwiftDataIndexedWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SwiftDataIndexedWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (ModelContext, [IndexedSwiftUser]) in
                let context = Stores.emptyIndexedSwiftDataContext()
                let users = records.map { IndexedSwiftUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
                return (context, users)
            },
            work: { state in
                for user in state.1 { state.0.insert(user) }
                try! state.0.save()
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (ModelContext, [IndexedSwiftUser]) in
                let context = Stores.emptyIndexedSwiftDataContext()
                let users = records.map { IndexedSwiftUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
                for user in users { context.insert(user) }
                try! context.save()
                return (context, users)
            },
            work: { state in
                for user in state.1 { user.firstName = BenchmarkData.mutatedName }
                try! state.0.save()
            }
        )
    }
}
