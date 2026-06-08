//
//  RealmIndexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Realm read benchmarks against in-memory Realms indexed on a single field:
//  int queries hit `RealmUserAgeIndexed`, string queries hit
//  `RealmUserNameIndexed`, so each read measures one index in isolation. (Realm
//  offers one general index type; range/sort still scan.)
//

import Foundation
import RealmSwift

final class RealmIndexedReadTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("read_equality_int",      { ($0 as! RealmIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! RealmIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! RealmIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! RealmIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! RealmIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! RealmIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! RealmIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! RealmIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! RealmIndexedReadTests).read_byID($1) }),
        ]
    }

    // Int queries → entity indexed on `age`.
    func read_equality_int(_ size: Int) {
        let realm = Stores.ageIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserAgeIndexed.self).filter("age == %d", BenchmarkData.targetAge)) }
    }

    func read_notEqual_int(_ size: Int) {
        let realm = Stores.ageIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserAgeIndexed.self).filter("age != %d", BenchmarkData.targetAge)) }
    }

    func read_comparison_int(_ size: Int) {
        let realm = Stores.ageIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserAgeIndexed.self).filter("age > %d", BenchmarkData.ageThreshold)) }
    }

    func read_sort_int(_ size: Int) {
        let realm = Stores.ageIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserAgeIndexed.self).sorted(byKeyPath: "age")) }
    }

    // String queries → entity indexed on `firstName`.
    func read_equality_string(_ size: Int) {
        let realm = Stores.nameIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserNameIndexed.self).filter("firstName == %@", BenchmarkData.targetName)) }
    }

    func read_notEqual_string(_ size: Int) {
        let realm = Stores.nameIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserNameIndexed.self).filter("firstName != %@", BenchmarkData.targetName)) }
    }

    func read_comparison_string(_ size: Int) {
        let realm = Stores.nameIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserNameIndexed.self).filter("firstName > %@", BenchmarkData.nameThreshold)) }
    }

    func read_sort_string(_ size: Int) {
        let realm = Stores.nameIndexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(RealmUserNameIndexed.self).sorted(byKeyPath: "firstName")) }
    }

    // byID → primary key; entity choice is irrelevant.
    func read_byID(_ size: Int) {
        let realm = Stores.nameIndexedRealm(BenchmarkData.records(count: size))
        let targetID = realm.objects(RealmUserNameIndexed.self).first!.id
        measureRead { _ = realm.object(ofType: RealmUserNameIndexed.self, forPrimaryKey: targetID) }
    }
}
