//
//  SwiftletModelIndexedWriteTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  SwiftletModel write benchmarks against the fully indexed `IndexedUser`.
//  Pure write path: stores/objects are prepared outside the measured region,
//  only the save loop is timed — no prior reads.
//

import XCTest
import ParametrizedXCTestCase
import SwiftletModel

final class SwiftletModelIndexedWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! SwiftletModelIndexedWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SwiftletModelIndexedWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { (records.map { IndexedUser(record: $0) }, Context()) },
            work: { state in
                var context = state.1
                for user in state.0 { try! user.save(to: &context) }
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Context, [IndexedUser]) in
                var context = Context()
                for record in records { try! IndexedUser(record: record).save(to: &context) }
                // Mutated copies prepared up front — the measured region only re-saves.
                let mutated = records.map {
                    IndexedUser(id: $0.id, firstName: BenchmarkData.mutatedName, surname: $0.surname, age: $0.age)
                }
                return (context, mutated)
            },
            work: { state in
                var context = state.0
                for user in state.1 { try! user.save(to: &context) }
            }
        )
    }
}
