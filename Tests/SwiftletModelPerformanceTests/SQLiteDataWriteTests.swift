//
//  SQLiteDataWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Write benchmarks for Point-Free SQLiteData against an in-memory DatabaseQueue.
//  insert: one batch INSERT in a transaction. update: per-id UPDATE statements
//  in a single transaction (mirrors "update N rows", no prior read).
//

import XCTest
import ParametrizedXCTestCase
import SQLiteData

final class SQLiteDataWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! SQLiteDataWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! SQLiteDataWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (DatabaseQueue, [SQLiteUser]) in
                (SQLiteStore.emptyQueue(), SQLiteStore.users(records))
            },
            work: { state in
                try! state.0.write { db in try SQLiteUser.insert { state.1 }.execute(db) }
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (DatabaseQueue, [UUID]) in
                (SQLiteStore.populatedQueue(records), records.map { $0.id })
            },
            work: { state in
                try! state.0.write { db in
                    for id in state.1 {
                        try SQLiteUser.find(id).update { $0.firstName = BenchmarkData.mutatedName }.execute(db)
                    }
                }
            }
        )
    }
}
