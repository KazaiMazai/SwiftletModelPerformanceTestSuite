//
//  SwiftDataWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftData write benchmarks against an in-memory store. Objects and stores
//  are prepared outside the measured region; only insert+save / mutate+save is
//  timed — no prior reads (update holds references from setup).
//

import Foundation
import SwiftData

final class SwiftDataWriteTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("write_insert", { ($0 as! SwiftDataWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SwiftDataWriteTests).write_update($1) }),
        ]
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (ModelContext, [SwiftUser]) in
                let context = Stores.emptySwiftDataContext()
                let users = records.map { SwiftUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
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
            prepare: { () -> (ModelContext, [SwiftUser]) in
                let context = Stores.emptySwiftDataContext()
                let users = records.map { SwiftUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
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
