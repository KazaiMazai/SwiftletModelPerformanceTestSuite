//
//  SwiftletModelIndexedWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel indexed write benchmarks. To isolate the maintenance cost of a
//  *single* index (rather than four at once), each write is run twice: against
//  an entity with one hash index and against one with one comparable BTree index.
//  Both index `firstName` — the field the update mutates — so `update` actually
//  churns the index (old key removed, new key inserted), not just re-saves past
//  an idle one. Pure write path: stores/objects are prepared outside the measured
//  region, only the save loop is timed. The index kind lands in the CSV
//  `valueType` column (`hash` / `comparable`).
//

import Foundation
import SwiftletModel

final class SwiftletModelIndexedWriteTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("write_insert_hash",       { ($0 as! SwiftletModelIndexedWriteTests).write_insert_hash($1) }),
            ("write_insert_comparable", { ($0 as! SwiftletModelIndexedWriteTests).write_insert_comparable($1) }),
            ("write_update_hash",       { ($0 as! SwiftletModelIndexedWriteTests).write_update_hash($1) }),
            ("write_update_comparable", { ($0 as! SwiftletModelIndexedWriteTests).write_update_comparable($1) }),
        ]
    }

    func write_insert_hash(_ size: Int)       { insert(StringHashUser.self, size) }
    func write_insert_comparable(_ size: Int) { insert(StringSortUser.self, size) }
    func write_update_hash(_ size: Int)       { update(StringHashUser.self, size) }
    func write_update_comparable(_ size: Int) { update(StringSortUser.self, size) }

    // MARK: - Generic write helpers

    private func insert<U: BenchmarkUser>(_ type: U.Type, _ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { (records.map { U(record: $0) }, Context()) },
            work: { state in
                var context = state.1
                for user in state.0 { try! user.save(to: &context, options: .default) }
            }
        )
    }

    private func update<U: BenchmarkUser>(_ type: U.Type, _ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Context, [U]) in
                var context = Context()
                for record in records { try! U(record: record).save(to: &context, options: .default) }
                // Mutated copies prepared up front — the measured region only re-saves.
                let mutated = records.map {
                    U(id: $0.id, firstName: BenchmarkData.mutatedName, surname: $0.surname, age: $0.age)
                }
                return (context, mutated)
            },
            work: { state in
                var context = state.0
                for user in state.1 { try! user.save(to: &context, options: .default) }
            }
        )
    }
}
