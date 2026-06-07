//
//  SQLiteDataReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Read benchmarks for Point-Free SQLiteData against an in-memory DatabaseQueue.
//  No secondary indexes (default config); `id` is the primary key.
//

import XCTest
import ParametrizedXCTestCase
import SQLiteData

final class SQLiteDataReadTests: BenchmarkCase {

    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_equality_int",      { ($0 as! SQLiteDataReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SQLiteDataReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SQLiteDataReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SQLiteDataReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SQLiteDataReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SQLiteDataReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SQLiteDataReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SQLiteDataReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SQLiteDataReadTests).read_byID($1) }),
        ])
    }

    func read_equality_int(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.age.eq(BenchmarkData.targetAge) }.fetchAll(db) } }
    }

    func read_equality_string(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.firstName.eq(BenchmarkData.targetName) }.fetchAll(db) } }
    }

    func read_notEqual_int(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.age.neq(BenchmarkData.targetAge) }.fetchAll(db) } }
    }

    func read_notEqual_string(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.firstName.neq(BenchmarkData.targetName) }.fetchAll(db) } }
    }

    func read_comparison_int(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.age > BenchmarkData.ageThreshold }.fetchAll(db) } }
    }

    func read_comparison_string(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.where { $0.firstName > BenchmarkData.nameThreshold }.fetchAll(db) } }
    }

    func read_sort_int(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.order { $0.age }.fetchAll(db) } }
    }

    func read_sort_string(_ size: Int) {
        let queue = SQLiteStore.populatedQueue(BenchmarkData.records(count: size))
        measureRead { _ = try! queue.read { db in try SQLiteUser.order { $0.firstName }.fetchAll(db) } }
    }

    func read_byID(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        let queue = SQLiteStore.populatedQueue(records)
        let targetID = records[size / 2].id
        measureRead { _ = try! queue.read { db in try SQLiteUser.find(targetID).fetchOne(db) } }
    }
}
