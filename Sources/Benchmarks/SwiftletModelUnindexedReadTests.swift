//
//  SwiftletModelUnindexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel read benchmarks against the unindexed `PlainUser` — every
//  query is a full linear scan. Mirror of the indexed suite for direct
//  index-impact comparison.
//

import Foundation
import SwiftletModel

final class SwiftletModelUnindexedReadTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("read_equality_int",      { ($0 as! SwiftletModelUnindexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SwiftletModelUnindexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SwiftletModelUnindexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SwiftletModelUnindexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SwiftletModelUnindexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SwiftletModelUnindexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SwiftletModelUnindexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SwiftletModelUnindexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SwiftletModelUnindexedReadTests).read_byID($1) }),
        ]
    }

    func read_equality_int(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.age == BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_equality_string(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.firstName == BenchmarkData.targetName).resolve(in: context) }
    }

    func read_notEqual_int(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.age != BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_notEqual_string(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.firstName != BenchmarkData.targetName).resolve(in: context) }
    }

    func read_comparison_int(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.age > BenchmarkData.ageThreshold).resolve(in: context) }
    }

    func read_comparison_string(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.filter(\.firstName > BenchmarkData.nameThreshold).resolve(in: context) }
    }

    func read_sort_int(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.query().sorted(by: \.age).resolve(in: context) }
    }

    func read_sort_string(_ size: Int) {
        let context = Stores.plainContext(BenchmarkData.records(count: size))
        measureRead { _ = PlainUser.query().sorted(by: \.firstName).resolve(in: context) }
    }

    func read_byID(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        let context = Stores.plainContext(records)
        let targetID = records[size / 2].id
        measureRead { _ = PlainUser.query(targetID).resolve(in: context) }
    }
}
