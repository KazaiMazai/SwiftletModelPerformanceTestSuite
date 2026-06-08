//
//  NorthwindReadTests.swift
//  SwiftletModelPerformanceTestSuite
//
//  Relational-retrieval benchmarks on synthetic Northwind data: the same three
//  views run as SwiftletModel graph traversals vs GRDB hand-written JOINs.
//  Size = order count (line items fan out ~4×).
//

import XCTest
import ParametrizedXCTestCase
import SwiftletModel
import GRDB
import SwiftData

/// Deterministic sample of order IDs for the navigational workload — the SAME
/// set for every engine, so the per-order traversal does identical work. Caps
/// at ~200 lookups so the point-query cost dominates over fan-out.
func northwindOrderSample(_ size: Int) -> [Int] {
    Array(stride(from: 1, through: max(1, size), by: max(1, size / 200)))
}

final class SwiftletModelNorthwindReadTests: BenchmarkCase {
    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_orderDetailsExtended", { ($0 as! SwiftletModelNorthwindReadTests).read_orderDetailsExtended($1) }),
            ("read_productsByCategory",   { ($0 as! SwiftletModelNorthwindReadTests).read_productsByCategory($1) }),
            ("read_invoices",             { ($0 as! SwiftletModelNorthwindReadTests).read_invoices($1) }),
            ("read_invoicesJoined",       { ($0 as! SwiftletModelNorthwindReadTests).read_invoicesJoined($1) }),
            ("read_orderInvoice",         { ($0 as! SwiftletModelNorthwindReadTests).read_orderInvoice($1) }),
        ])
    }

    func read_orderDetailsExtended(_ size: Int) {
        let ctx = NorthwindSwiftlet.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftlet.orderDetailsExtended(ctx) }
    }
    func read_productsByCategory(_ size: Int) {
        let ctx = NorthwindSwiftlet.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftlet.productsByCategory(ctx) }
    }
    func read_invoices(_ size: Int) {
        let ctx = NorthwindSwiftlet.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftlet.invoices(ctx) }
    }
    func read_invoicesJoined(_ size: Int) {
        let ctx = NorthwindSwiftlet.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftlet.invoicesJoined(ctx) }
    }
    func read_orderInvoice(_ size: Int) {
        let ctx = NorthwindSwiftlet.context(NorthwindData.generate(orderCount: size))
        let ids = northwindOrderSample(size)
        measureRead { _ = NorthwindSwiftlet.orderInvoice(ctx, orderIDs: ids) }
    }
}

final class GRDBNorthwindReadTests: BenchmarkCase {
    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_orderDetailsExtended", { ($0 as! GRDBNorthwindReadTests).read_orderDetailsExtended($1) }),
            ("read_productsByCategory",   { ($0 as! GRDBNorthwindReadTests).read_productsByCategory($1) }),
            ("read_invoices",             { ($0 as! GRDBNorthwindReadTests).read_invoices($1) }),
            ("read_orderInvoice",         { ($0 as! GRDBNorthwindReadTests).read_orderInvoice($1) }),
        ])
    }

    func read_orderDetailsExtended(_ size: Int) {
        let q = NorthwindGRDB.queue(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindGRDB.orderDetailsExtended(q) }
    }
    func read_productsByCategory(_ size: Int) {
        let q = NorthwindGRDB.queue(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindGRDB.productsByCategory(q) }
    }
    func read_invoices(_ size: Int) {
        let q = NorthwindGRDB.queue(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindGRDB.invoices(q) }
    }
    func read_orderInvoice(_ size: Int) {
        let q = NorthwindGRDB.queue(NorthwindData.generate(orderCount: size))
        let ids = northwindOrderSample(size)
        measureRead { _ = NorthwindGRDB.orderInvoice(q, orderIDs: ids) }
    }
}

final class SwiftDataNorthwindReadTests: BenchmarkCase {
    override class func _qck_testMethodSelectors() -> [_QuickSelectorWrapper] {
        registerParametrized([
            ("read_orderDetailsExtended", { ($0 as! SwiftDataNorthwindReadTests).read_orderDetailsExtended($1) }),
            ("read_productsByCategory",   { ($0 as! SwiftDataNorthwindReadTests).read_productsByCategory($1) }),
            ("read_invoices",             { ($0 as! SwiftDataNorthwindReadTests).read_invoices($1) }),
            ("read_orderInvoice",         { ($0 as! SwiftDataNorthwindReadTests).read_orderInvoice($1) }),
        ])
    }

    func read_orderDetailsExtended(_ size: Int) {
        let ctx = NorthwindSwiftData.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftData.orderDetailsExtended(ctx) }
    }
    func read_productsByCategory(_ size: Int) {
        let ctx = NorthwindSwiftData.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftData.productsByCategory(ctx) }
    }
    func read_invoices(_ size: Int) {
        let ctx = NorthwindSwiftData.context(NorthwindData.generate(orderCount: size))
        measureRead { _ = NorthwindSwiftData.invoices(ctx) }
    }
    func read_orderInvoice(_ size: Int) {
        let ctx = NorthwindSwiftData.context(NorthwindData.generate(orderCount: size))
        let ids = northwindOrderSample(size)
        measureRead { _ = NorthwindSwiftData.orderInvoice(ctx, orderIDs: ids) }
    }
}
