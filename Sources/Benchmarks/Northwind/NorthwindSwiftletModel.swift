//
//  NorthwindSwiftletModel.swift
//  SwiftletModelPerformanceTestSuite
//
//  SwiftletModel entities for the Northwind schema (normalized graph with
//  @Relationship), a builder that loads a NorthwindDataset into a Context, and
//  the relational-retrieval workloads (Northwind views) as graph traversals.
//

import Foundation
import SwiftletModel

@EntityModel
struct NWMCategory {
    let id: Int
    var name: String
    @Relationship(inverse: \.category) var products: [NWMProduct]?
    init(id: Int, name: String) { self.id = id; self.name = name }
}

@EntityModel
struct NWMSupplier {
    let id: Int
    var companyName: String
    var country: String
    @Relationship(inverse: \.supplier) var products: [NWMProduct]?
    init(id: Int, companyName: String, country: String) { self.id = id; self.companyName = companyName; self.country = country }
}

@EntityModel
struct NWMShipper {
    let id: Int
    var companyName: String
    @Relationship(inverse: \.shipper) var orders: [NWMOrder]?
    init(id: Int, companyName: String) { self.id = id; self.companyName = companyName }
}

@EntityModel
struct NWMEmployee {
    let id: Int
    var lastName: String
    var firstName: String
    @Relationship(inverse: \.employee) var orders: [NWMOrder]?
    init(id: Int, lastName: String, firstName: String) { self.id = id; self.lastName = lastName; self.firstName = firstName }
}

@EntityModel
struct NWMCustomer {
    let id: String
    var companyName: String
    var contactName: String
    var city: String
    var country: String
    @Relationship(inverse: \.customer) var orders: [NWMOrder]?
    init(id: String, companyName: String, contactName: String, city: String, country: String) {
        self.id = id; self.companyName = companyName; self.contactName = contactName; self.city = city; self.country = country
    }
}

@EntityModel
struct NWMProduct {
    let id: Int
    var name: String
    var unitPrice: Double
    var unitsInStock: Int
    var discontinued: Bool
    @Relationship(inverse: \.products) var category: NWMCategory?
    @Relationship(inverse: \.products) var supplier: NWMSupplier?
    @Relationship(inverse: \.product) var orderDetails: [NWMOrderDetail]?
    init(id: Int, name: String, unitPrice: Double, unitsInStock: Int, discontinued: Bool) {
        self.id = id; self.name = name; self.unitPrice = unitPrice; self.unitsInStock = unitsInStock; self.discontinued = discontinued
    }
}

@EntityModel
struct NWMOrder {
    let id: Int
    var orderDate: Double
    var freight: Double
    var shipCountry: String
    @Relationship(inverse: \.orders) var customer: NWMCustomer?
    @Relationship(inverse: \.orders) var employee: NWMEmployee?
    @Relationship(inverse: \.orders) var shipper: NWMShipper?
    @Relationship(inverse: \.order) var orderDetails: [NWMOrderDetail]?
    init(id: Int, orderDate: Double, freight: Double, shipCountry: String) {
        self.id = id; self.orderDate = orderDate; self.freight = freight; self.shipCountry = shipCountry
    }
}

@EntityModel
struct NWMOrderDetail {
    let id: String           // "<orderID>-<productID>" (composite PK)
    var unitPrice: Double
    var quantity: Int
    var discount: Double
    @Relationship(inverse: \.orderDetails) var order: NWMOrder?
    @Relationship(inverse: \.orderDetails) var product: NWMProduct?
    init(id: String, unitPrice: Double, quantity: Int, discount: Double) {
        self.id = id; self.unitPrice = unitPrice; self.quantity = quantity; self.discount = discount
    }
}

enum NorthwindSwiftlet {

    static func context(_ ds: NorthwindDataset) -> Context {
        var ctx = Context()

        var catByID: [Int: NWMCategory] = [:]
        for c in ds.categories { let e = NWMCategory(id: c.id, name: c.name); try! e.save(to: &ctx); catByID[c.id] = e }
        var supByID: [Int: NWMSupplier] = [:]
        for s in ds.suppliers { let e = NWMSupplier(id: s.id, companyName: s.companyName, country: s.country); try! e.save(to: &ctx); supByID[s.id] = e }
        var shipByID: [Int: NWMShipper] = [:]
        for s in ds.shippers { let e = NWMShipper(id: s.id, companyName: s.companyName); try! e.save(to: &ctx); shipByID[s.id] = e }
        var empByID: [Int: NWMEmployee] = [:]
        for e0 in ds.employees { let e = NWMEmployee(id: e0.id, lastName: e0.lastName, firstName: e0.firstName); try! e.save(to: &ctx); empByID[e0.id] = e }
        var custByID: [String: NWMCustomer] = [:]
        for c in ds.customers {
            let e = NWMCustomer(id: c.id, companyName: c.companyName, contactName: c.contactName, city: c.city, country: c.country)
            try! e.save(to: &ctx); custByID[c.id] = e
        }

        var prodByID: [Int: NWMProduct] = [:]
        for p in ds.products {
            var e = NWMProduct(id: p.id, name: p.name, unitPrice: p.unitPrice, unitsInStock: p.unitsInStock, discontinued: p.discontinued)
            e.$category = .relation(catByID[p.categoryID]!)
            e.$supplier = .relation(supByID[p.supplierID]!)
            try! e.save(to: &ctx); prodByID[p.id] = e
        }
        var orderByID: [Int: NWMOrder] = [:]
        for o in ds.orders {
            var e = NWMOrder(id: o.id, orderDate: o.orderDate, freight: o.freight, shipCountry: o.shipCountry)
            e.$customer = .relation(custByID[o.customerID]!)
            e.$employee = .relation(empByID[o.employeeID]!)
            e.$shipper = .relation(shipByID[o.shipVia]!)
            try! e.save(to: &ctx); orderByID[o.id] = e
        }
        for d in ds.orderDetails {
            var e = NWMOrderDetail(id: "\(d.orderID)-\(d.productID)", unitPrice: d.unitPrice, quantity: d.quantity, discount: d.discount)
            e.$order = .relation(orderByID[d.orderID]!)
            e.$product = .relation(prodByID[d.productID]!)
            try! e.save(to: &ctx)
        }
        return ctx
    }

    // MARK: - View workloads (graph traversals)

    /// "Order Details Extended": each line item with its product + extended price.
    /// Traverse from the *few* side (Product → its details) so each of the 77
    /// products is resolved once, not re-resolved per detail row.
    static func orderDetailsExtended(_ ctx: Context) -> Int {
        let products = NWMProduct.query().with(\.$orderDetails).resolve(in: ctx)
        var count = 0
        for p in products {
            for d in p.orderDetails ?? [] {
                let extended = d.unitPrice * Double(d.quantity) * (1 - d.discount)
                _ = (p.name, extended)
                count += 1
            }
        }
        return count
    }

    /// "Products by Category": non-discontinued products with their category
    /// name — traversed from Category → its products (8 categories resolved once).
    static func productsByCategory(_ ctx: Context) -> Int {
        let categories = NWMCategory.query().with(\.$products).resolve(in: ctx)
        var count = 0
        for c in categories {
            for p in c.products ?? [] where !p.discontinued {
                _ = (c.name, p.name, p.unitsInStock)
                count += 1
            }
        }
        return count
    }

    /// Navigational: for each sampled order, traverse its graph to build that
    /// one order's invoice rows. Direct graph access — no query per relationship.
    static func orderInvoice(_ ctx: Context, orderIDs: [Int]) -> Int {
        var rows = 0
        for oid in orderIDs {
            let query = NWMOrder.query(oid)
                .with(\.$customer).with(\.$employee).with(\.$shipper)
                .with(\.$orderDetails) { $0.with(\.$product) }
            guard let o = query.resolve(in: ctx) else { continue }
            for d in o.orderDetails ?? [] {
                let extended = d.unitPrice * Double(d.quantity) * (1 - d.discount)
                _ = (o.customer?.companyName, o.employee?.firstName, o.shipper?.companyName, d.product?.name, extended)
                rows += 1
            }
        }
        return rows
    }

    /// "Invoices": the wide 6-table join — orders with customer, employee,
    /// shipper, and each line item's product, flattened to invoice rows.
    static func invoices(_ ctx: Context) -> Int {
        let orders = NWMOrder.query()
            .with(\.$customer)
            .with(\.$employee)
            .with(\.$shipper)
            .with(\.$orderDetails) { $0.with(\.$product) }
            .resolve(in: ctx)
        var rows = 0
        for o in orders {
            for d in o.orderDetails ?? [] {
                let extended = d.unitPrice * Double(d.quantity) * (1 - d.discount)
                _ = (o.id, o.customer?.companyName, o.employee?.firstName, o.shipper?.companyName, d.product?.name, extended)
                rows += 1
            }
        }
        return rows
    }

    /// "Invoices", hand-joined: resolve *every* entity exactly once — products
    /// into a lookup dictionary (only 77 distinct), and orders with their parents
    /// + detail lists — then look the product up per line item instead of
    /// re-resolving it. The in-memory equivalent of GRDB's hash join; avoids the
    /// ~4×N redundant product materializations the nested `.with(\.$product)` does.
    static func invoicesJoined(_ ctx: Context) -> Int {
        var prodByID: [Int: NWMProduct] = [:]
        for p in NWMProduct.query().resolve(in: ctx) { prodByID[p.id] = p }

        let orders = NWMOrder.query()
            .with(\.$customer)
            .with(\.$employee)
            .with(\.$shipper)
            .with(\.$orderDetails)
            .resolve(in: ctx)

        var rows = 0
        for o in orders {
            for d in o.orderDetails ?? [] {
                // d.id == "<orderID>-<productID>"; pull the FK without resolving.
                let pid = d.id.split(separator: "-").last.flatMap { Int($0) }
                let product = pid.flatMap { prodByID[$0] }
                let extended = d.unitPrice * Double(d.quantity) * (1 - d.discount)
                _ = (o.id, o.customer?.companyName, o.employee?.firstName, o.shipper?.companyName, product?.name, extended)
                rows += 1
            }
        }
        return rows
    }
}
