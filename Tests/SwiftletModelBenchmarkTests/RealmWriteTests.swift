//
//  RealmWriteTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  Realm write benchmarks against an in-memory Realm. Only the write
//  transaction is timed; update mutates managed objects held from setup, so
//  there is no prior read query.
//

import XCTest
import ParametrizedXCTestCase
import RealmSwift

final class RealmWriteTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("write_insert", { ($0 as! RealmWriteTests).write_insert($1) }),
            ("write_update", { ($0 as! RealmWriteTests).write_update($1) }),
        ])
    }

    func write_insert(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        measureWrite(
            prepare: { () -> (Realm, [RealmUser]) in
                let realm = Stores.emptyRealm()
                let users = records.map { RealmUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
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
            prepare: { () -> (Realm, [RealmUser]) in
                let realm = Stores.emptyRealm()
                let users = records.map { RealmUser(firstName: $0.firstName, surname: $0.surname, age: $0.age) }
                try! realm.write { realm.add(users) }   // `users` are now managed objects
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
