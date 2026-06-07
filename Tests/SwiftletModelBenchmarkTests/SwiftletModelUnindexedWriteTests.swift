//
//  SwiftletModelUnindexedWriteTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  SwiftletModel write benchmarks against the unindexed `PlainUser` — isolates
//  the cost of index maintenance versus the indexed suite.
//

import XCTest
import ParametrizedXCTestCase
import SwiftletModel

final class SwiftletModelUnindexedWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! SwiftletModelUnindexedWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SwiftletModelUnindexedWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { (records.map { PlainUser(record: $0) }, Context()) },
            work: { state in
                var context = state.1
                for user in state.0 { try! user.save(to: &context) }
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Context, [PlainUser]) in
                var context = Context()
                for record in records { try! PlainUser(record: record).save(to: &context) }
                let mutated = records.map {
                    PlainUser(id: $0.id, firstName: BenchmarkData.mutatedName, surname: $0.surname, age: $0.age)
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
