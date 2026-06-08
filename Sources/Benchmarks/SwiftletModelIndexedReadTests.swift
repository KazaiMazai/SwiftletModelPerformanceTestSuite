//
//  SwiftletModelIndexedReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel read benchmarks. Each query runs against an entity carrying
//  *only* the one index that query uses (hash for `==`, comparable BTree for
//  `!=` / `>` / sort), so each index is measured in isolation rather than
//  alongside three unrelated ones. One measured method per (operation × type).
//

import Foundation
import SwiftletModel

final class SwiftletModelIndexedReadTests: BenchmarkCase {

    override class func cases() -> [(name: String, body: (BenchmarkCase, Int) -> Void)] {
        [
            ("read_equality_int",      { ($0 as! SwiftletModelIndexedReadTests).read_equality_int($1) }),
            ("read_equality_string",   { ($0 as! SwiftletModelIndexedReadTests).read_equality_string($1) }),
            ("read_notEqual_int",      { ($0 as! SwiftletModelIndexedReadTests).read_notEqual_int($1) }),
            ("read_notEqual_string",   { ($0 as! SwiftletModelIndexedReadTests).read_notEqual_string($1) }),
            ("read_comparison_int",    { ($0 as! SwiftletModelIndexedReadTests).read_comparison_int($1) }),
            ("read_comparison_string", { ($0 as! SwiftletModelIndexedReadTests).read_comparison_string($1) }),
            ("read_sort_int",          { ($0 as! SwiftletModelIndexedReadTests).read_sort_int($1) }),
            ("read_sort_string",       { ($0 as! SwiftletModelIndexedReadTests).read_sort_string($1) }),
            ("read_byID",              { ($0 as! SwiftletModelIndexedReadTests).read_byID($1) }),
        ]
    }

    // equality → hash index
    func read_equality_int(_ size: Int) {
        let context = Stores.context(IntHashUser.self, BenchmarkData.records(count: size))
        measureRead { _ = IntHashUser.filter(\.age == BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_equality_string(_ size: Int) {
        let context = Stores.context(StringHashUser.self, BenchmarkData.records(count: size))
        measureRead { _ = StringHashUser.filter(\.firstName == BenchmarkData.targetName).resolve(in: context) }
    }

    // notEqual / comparison / sort → comparable BTree index
    func read_notEqual_int(_ size: Int) {
        let context = Stores.context(IntSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = IntSortUser.filter(\.age != BenchmarkData.targetAge).resolve(in: context) }
    }

    func read_notEqual_string(_ size: Int) {
        let context = Stores.context(StringSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = StringSortUser.filter(\.firstName != BenchmarkData.targetName).resolve(in: context) }
    }

    func read_comparison_int(_ size: Int) {
        let context = Stores.context(IntSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = IntSortUser.filter(\.age > BenchmarkData.ageThreshold).resolve(in: context) }
    }

    func read_comparison_string(_ size: Int) {
        let context = Stores.context(StringSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = StringSortUser.filter(\.firstName > BenchmarkData.nameThreshold).resolve(in: context) }
    }

    func read_sort_int(_ size: Int) {
        let context = Stores.context(IntSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = IntSortUser.query().sorted(by: \.age).resolve(in: context) }
    }

    func read_sort_string(_ size: Int) {
        let context = Stores.context(StringSortUser.self, BenchmarkData.records(count: size))
        measureRead { _ = StringSortUser.query().sorted(by: \.firstName).resolve(in: context) }
    }

    // byID → primary key (no secondary index); any entity is equivalent.
    func read_byID(_ size: Int) {
        let records = BenchmarkData.records(count: size)
        let context = Stores.context(IntHashUser.self, records)
        let targetID = records[size / 2].id
        measureRead { _ = IntHashUser.query(targetID).resolve(in: context) }
    }
}
