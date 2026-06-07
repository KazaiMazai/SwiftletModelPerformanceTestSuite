//
//  RealmIndexedReadTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  Realm read benchmarks against an in-memory Realm with indexed `firstName`
//  and `age` (IndexedRealmUser). Mirror of RealmReadTests. Note: Realm indexes
//  accelerate equality/IN lookups; range/sort still scan.
//

import XCTest
import ParametrizedXCTestCase
import RealmSwift

final class RealmIndexedReadTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_equality_int",      { ($0 as! RealmIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! RealmIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! RealmIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! RealmIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! RealmIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! RealmIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! RealmIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! RealmIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! RealmIndexedReadTests).read_byID($1) }),
        ])
    }

    func read_equality_int(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("age == %d", BenchmarkData.targetAge)) }
    }

    func read_equality_string(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("firstName == %@", BenchmarkData.targetName)) }
    }

    func read_notEqual_int(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("age != %d", BenchmarkData.targetAge)) }
    }

    func read_notEqual_string(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("firstName != %@", BenchmarkData.targetName)) }
    }

    func read_comparison_int(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("age > %d", BenchmarkData.ageThreshold)) }
    }

    func read_comparison_string(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).filter("firstName > %@", BenchmarkData.nameThreshold)) }
    }

    func read_sort_int(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).sorted(byKeyPath: "age")) }
    }

    func read_sort_string(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        measureRead { _ = Array(realm.objects(IndexedRealmUser.self).sorted(byKeyPath: "firstName")) }
    }

    func read_byID(_ size: Int) {
        let realm = Stores.indexedRealm(BenchmarkData.records(count: size))
        let targetID = realm.objects(IndexedRealmUser.self).first!.id
        measureRead { _ = realm.object(ofType: IndexedRealmUser.self, forPrimaryKey: targetID) }
    }
}
