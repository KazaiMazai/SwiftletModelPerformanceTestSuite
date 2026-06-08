//
//  SwiftDataIndexedWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftData write benchmarks against an in-memory store with a single B-tree
//  index on `firstName` (`SwiftUserNameIndexed`) — the field the update mutates,
//  so `update` actually churns the index. Isolated single-index write cost.
//

import Foundation
import SwiftData

final class SwiftDataIndexedWriteTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("write_insert", { ($0 as! SwiftDataIndexedWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SwiftDataIndexedWriteTests).write_update($1) }),
        ]
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (ModelContext, [SwiftUserNameIndexed]) in
                let context = Stores.emptyNameIndexedSwiftDataContext()
                let users = records.map { SwiftUserNameIndexed(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
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
            prepare: { () -> (ModelContext, [SwiftUserNameIndexed]) in
                let context = Stores.emptyNameIndexedSwiftDataContext()
                let users = records.map { SwiftUserNameIndexed(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
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
