//
//  RealmIndexedWriteTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Realm write benchmarks against an in-memory Realm with a single general index
//  on `firstName` (`RealmUserNameIndexed`) — the field the update mutates, so
//  `update` actually churns the index. Isolated single-index write cost.
//

import XCTest
import ParametrizedXCTestCase
import RealmSwift

final class RealmIndexedWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! RealmIndexedWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! RealmIndexedWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Realm, [RealmUserNameIndexed]) in
                let realm = Stores.emptyRealm()
                let users = records.map { RealmUserNameIndexed(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
                return (realm, users)
            },
            work: { state in
                try! state.0.write { state.0.add(state.1) }
            }
        )
    }

    func write_update(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Realm, [RealmUserNameIndexed]) in
                let realm = Stores.emptyRealm()
                let users = records.map { RealmUserNameIndexed(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
                try! realm.write { realm.add(users) }
                return (realm, users)
            },
            work: { state in
                try! state.0.write {
                    for user in state.1 { user.firstName = BenchmarkData.mutatedName }
                }
            }
        )
    }
}
