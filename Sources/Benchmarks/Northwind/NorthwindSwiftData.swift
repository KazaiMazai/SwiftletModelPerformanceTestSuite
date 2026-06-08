//
//  NorthwindSwiftData.swift
//  SwiftletModelPerformanceTestSuite
//
//  Northwind schema as SwiftData @Model classes with relationships, an
//  in-memory builder, and the view workloads as object-graph navigation
//  (relationships are lazily faulted as they're traversed).
//

import Foundation
import SwiftData

@Model final class SDCategory {
    @Attribute(.unique) var id: Int
    var name: String
    @Relationship(inverse: \SDProduct.category) var products: [SDProduct] = []
    init(id: Int, name: String) { self.id = id; self.name = name }
}

@Model final class SDSupplier {
    @Attribute(.unique) var id: Int
    var companyName: String
    var country: String
    @Relationship(inverse: \SDProduct.supplier) var products: [SDProduct] = []
    init(id: Int, companyName: String, country: String) { self.id = id; self.companyName = companyName; self.country = country }
}

@Model final class SDShipper {
    @Attribute(.unique) var id: Int
    var companyName: String
    @Relationship(inverse: \SDOrder.shipper) var orders: [SDOrder] = []
    init(id: Int, companyName: String) { self.id = id; self.companyName = companyName }
}

@Model final class SDEmployee {
    @Attribute(.unique) var id: Int
    var lastName: String
    var firstName: String
    @Relationship(inverse: \SDOrder.employee) var orders: [SDOrder] = []
    init(id: Int, lastName: String, firstName: String) { self.id = id; self.lastName = lastName; self.firstName = firstName }
}

@Model final class SDCustomer {
    @Attribute(.unique) var id: String
    var companyName: String
    var contactName: String
    var city: String
    var country: String
    @Relationship(inverse: \SDOrder.customer) var orders: [SDOrder] = []
    init(id: String, companyName: String, contactName: String, city: String, country: String) {
        self.id = id; self.companyName = companyName; self.contactName = contactName; self.city = city; self.country = country
    }
}

@Model final class SDProduct {
    @Attribute(.unique) var id: Int
    var name: String
    var unitPrice: Double
    var unitsInStock: Int
    var discontinued: Bool
    var category: SDCategory?
    var supplier: SDSupplier?
    @Relationship(inverse: \SDOrderDetail.product) var orderDetails: [SDOrderDetail] = []
    init(id: Int, name: String, unitPrice: Double, unitsInStock: Int, discontinued: Bool) {
        self.id = id; self.name = name; self.unitPrice = unitPrice; self.unitsInStock = unitsInStock; self.discontinued = discontinued
    }
}

@Model final class SDOrder {
    @Attribute(.unique) var id: Int
    var orderDate: Double
    var freight: Double
    var shipCountry: String
    var customer: SDCustomer?
    var employee: SDEmployee?
    var shipper: SDShipper?
    @Relationship(inverse: \SDOrderDetail.order) var orderDetails: [SDOrderDetail] = []
    init(id: Int, orderDate: Double, freight: Double, shipCountry: String) {
        self.id = id; self.orderDate = orderDate; self.freight = freight; self.shipCountry = shipCountry
    }
}

@Model final class SDOrderDetail {
    @Attribute(.unique) var id: String
    var unitPrice: Double
    var quantity: Int
    var discount: Double
    var order: SDOrder?
    var product: SDProduct?
    init(id: String, unitPrice: Double, quantity: Int, discount: Double) {
        self.id = id; self.unitPrice = unitPrice; self.quantity = quantity; self.discount = discount
    }
}

enum NorthwindSwiftData {

    static func context(_ ds: NorthwindDataset) -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: SDCategory.self, SDSupplier.self, SDShipper.self, SDEmployee.self,
            SDCustomer.self, SDProduct.self, SDOrder.self, SDOrderDetail.self,
            configurations: config)
        let ctx = ModelContext(container)

        var catByID: [Int: SDCategory] = [:]
        for c in ds.categories { let e = SDCategory(id: c.id, name: c.name); ctx.insert(e); catByID[c.id] = e }
        var supByID: [Int: SDSupplier] = [:]
        for s in ds.suppliers { let e = SDSupplier(id: s.id, companyName: s.companyName, country: s.country); ctx.insert(e); supByID[s.id] = e }
        var shipByID: [Int: SDShipper] = [:]
        for s in ds.shippers { let e = SDShipper(id: s.id, companyName: s.companyName); ctx.insert(e); shipByID[s.id] = e }
        var empByID: [Int: SDEmployee] = [:]
        for e0 in ds.employees { let e = SDEmployee(id: e0.id, lastName: e0.lastName, firstName: e0.firstName); ctx.insert(e); empByID[e0.id] = e }
        var custByID: [String: SDCustomer] = [:]
        for c in ds.customers {
            let e = SDCustomer(id: c.id, companyName: c.companyName, contactName: c.contactName, city: c.city, country: c.country)
            ctx.insert(e); custByID[c.id] = e
        }
        var prodByID: [Int: SDProduct] = [:]
        for p in ds.products {
            let e = SDProduct(id: p.id, name: p.name, unitPrice: p.unitPrice, unitsInStock: p.unitsInStock, discontinued: p.discontinued)
            e.category = catByID[p.categoryID]; e.supplier = supByID[p.supplierID]
            ctx.insert(e); prodByID[p.id] = e
        }
        var orderByID: [Int: SDOrder] = [:]
        for o in ds.orders {
            let e = SDOrder(id: o.id, orderDate: o.orderDate, freight: o.freight, shipCountry: o.shipCountry)
            e.customer = custByID[o.customerID]; e.employee = empByID[o.employeeID]; e.shipper = shipByID[o.shipVia]
            ctx.insert(e); orderByID[o.id] = e
        }
        for d in ds.orderDetails {
            let e = SDOrderDetail(id: "\(d.orderID)-\(d.productID)", unitPrice: d.unitPrice, quantity: d.quantity, discount: d.discount)
            e.order = orderByID[d.orderID]; e.product = prodByID[d.productID]
            ctx.insert(e)
        }
        try! ctx.save()
        return ctx
    }

    // MARK: - View workloads (object-graph navigation)

    static func orderDetailsExtended(_ ctx: ModelContext) -> Int {
        let details = try! ctx.fetch(FetchDescriptor<SDOrderDetail>())
        var count = 0
        for d in details {
            _ = (d.product?.name, d.unitPrice * Double(d.quantity) * (1 - d.discount))
            count += 1
        }
        return count
    }

    static func productsByCategory(_ ctx: ModelContext) -> Int {
        let products = try! ctx.fetch(FetchDescriptor<SDProduct>())
        var count = 0
        for p in products where !p.discontinued {
            _ = (p.category?.name, p.name, p.unitsInStock)
            count += 1
        }
        return count
    }

    /// Navigational: fetch each sampled order by id, then fault its graph.
    static func orderInvoice(_ ctx: ModelContext, orderIDs: [Int]) -> Int {
        var rows = 0
        for oid in orderIDs {
            var fd = FetchDescriptor<SDOrder>(predicate: #Predicate { $0.id == oid })
            fd.fetchLimit = 1
            guard let o = try! ctx.fetch(fd).first else { continue }
            for d in o.orderDetails {
                _ = (o.customer?.companyName, o.employee?.firstName, o.shipper?.companyName, d.product?.name,
                     d.unitPrice * Double(d.quantity) * (1 - d.discount))
                rows += 1
            }
        }
        return rows
    }

    static func invoices(_ ctx: ModelContext) -> Int {
        let orders = try! ctx.fetch(FetchDescriptor<SDOrder>())
        var rows = 0
        for o in orders {
            for d in o.orderDetails {
                _ = (o.id, o.customer?.companyName, o.employee?.firstName, o.shipper?.companyName, d.product?.name,
                     d.unitPrice * Double(d.quantity) * (1 - d.discount))
                rows += 1
            }
        }
        return rows
    }
}
