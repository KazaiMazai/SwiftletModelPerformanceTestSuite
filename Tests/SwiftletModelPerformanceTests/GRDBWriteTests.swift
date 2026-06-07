//
//  GRDBWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Write benchmarks using GRDB directly. insert: per-row inserts in one
//  transaction. update: per-id UPDATE statements in one transaction (no read).
//

import XCTest
import ParametrizedXCTestCase
import GRDB

final class GRDBWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! GRDBWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! GRDBWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (DatabaseQueue, [GRDBUser]) in
                (GRDBStore.emptyQueue(), GRDBStore.users(records))
            },
            work: { state in
                try! state.0.write { db in
                    for user in state.1 { try user.insert(db) }
                }
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (DatabaseQueue, [String]) in
                (GRDBStore.populatedQueue(records), records.map { $0.id.uuidString })
            },
            work: { state in
                try! state.0.write { db in
                    for id in state.1 {
                        _ = try GRDBUser.filter(key: id).updateAll(db, GRDBUser.Columns.firstName.set(to: BenchmarkData.mutatedName))
                    }
                }
            }
        )
    }
}
