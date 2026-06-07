//
//  GRDBReadTests.swift
//  RealmVsSwiftDataBenchmarks
//
//  Read benchmarks using GRDB's native query interface, in-memory DatabaseQueue.
//

import XCTest
import ParametrizedXCTestCase
import GRDB

final class GRDBReadTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_equality_int",      { ($0 as! GRDBReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! GRDBReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! GRDBReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! GRDBReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! GRDBReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! GRDBReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! GRDBReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! GRDBReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! GRDBReadTests).read_byID($1) }),
        ])
    }

    func read_equality_int(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.age == BenchmarkData.targetAge).fetchAll(db) } }
    }

    func read_equality_string(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.firstName == BenchmarkData.targetName).fetchAll(db) } }
    }

    func read_notEqual_int(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.age != BenchmarkData.targetAge).fetchAll(db) } }
    }

    func read_notEqual_string(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.firstName != BenchmarkData.targetName).fetchAll(db) } }
    }

    func read_comparison_int(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.age > BenchmarkData.ageThreshold).fetchAll(db) } }
    }

    func read_comparison_string(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.filter(GRDBUser.Columns.firstName > BenchmarkData.nameThreshold).fetchAll(db) } }
    }

    func read_sort_int(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.order(GRDBUser.Columns.age).fetchAll(db) } }
    }

    func read_sort_string(_ size: Int) {
        let queue = GRDBStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try GRDBUser.order(GRDBUser.Columns.firstName).fetchAll(db) } }
    }

    func read_byID(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        let queue = GRDBStore.populatedQueue(records)
        let targetID = records[size / 2].id.uuidString
        measureRead { _ = try! queue.read { db in try GRDBUser.fetchOne(db, key: targetID) } }
    }
}
