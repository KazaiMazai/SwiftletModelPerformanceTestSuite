//
//  NorthwindDataset.swift
//  SwiftletModelPerformanceTestSuite
//
//  Engine-agnostic, deterministically-seeded data shaped like the Northwind
//  sample database (Category / Supplier / Shipper / Employee / Customer /
//  Product / Order / OrderDetail). Reference tables keep Northwind-ish
//  cardinalities (8 categories, 77 products, …); Orders/OrderDetails scale with
//  the requested order count so relational workloads can be swept by size.
//

import Foundation

// MARK: - Records (plain values, no engine types)

struct NWCategory { let id: Int; let name: String }
struct NWSupplier { let id: Int; let companyName: String; let country: String }
struct NWShipper { let id: Int; let companyName: String }
struct NWEmployee { let id: Int; let lastName: String; let firstName: String; let reportsTo: Int? }
struct NWCustomer { let id: String; let companyName: String; let contactName: String; let city: String; let country: String }
struct NWProduct {
    let id: Int; let name: String; let categoryID: Int; let supplierID: Int
    let unitPrice: Double; let unitsInStock: Int; let discontinued: Bool
}
struct NWOrder {
    let id: Int; let customerID: String; let employeeID: Int; let shipVia: Int
    let orderDate: Double; let freight: Double; let shipCountry: String
}
struct NWOrderDetail { let orderID: Int; let productID: Int; let unitPrice: Double; let quantity: Int; let discount: Double }

struct NorthwindDataset {
    let categories: [NWCategory]
    let suppliers: [NWSupplier]
    let shippers: [NWShipper]
    let employees: [NWEmployee]
    let customers: [NWCustomer]
    let products: [NWProduct]
    let orders: [NWOrder]
    let orderDetails: [NWOrderDetail]
}

enum NorthwindData {

    private static let categoryNames = [
        "Beverages", "Condiments", "Confections", "Dairy Products",
        "Grains/Cereals", "Meat/Poultry", "Produce", "Seafood",
    ]
    private static let countries = ["USA", "UK", "Germany", "France", "Sweden", "Brazil", "Italy", "Spain", "Canada", "Japan"]
    private static let cities = ["London", "Berlin", "Paris", "Madrid", "Rome", "Seattle", "Boston", "Lyon", "Graz", "Tokyo"]

    /// Builds a full Northwind-shaped graph with `orderCount` orders. Reference
    /// tables are fixed-size; orders fan out to ~4 line items each.
    static func generate(orderCount: Int) -> NorthwindDataset {
        var rng = SeededGenerator(seed: 0x4E_4F_52_54_48_57_4E)   // "NORTHWN"

        let categories = (1...8).map { NWCategory(id: $0, name: categoryNames[$0 - 1]) }
        let suppliers = (1...10).map { NWSupplier(id: $0, companyName: "Supplier \($0)", country: countries.randomElement(using: &rng)!) }
        let shippers = (1...3).map { NWShipper(id: $0, companyName: ["Speedy Express", "United Package", "Federal Shipping"][$0 - 1]) }

        let employees: [NWEmployee] = (1...9).map { i in
            NWEmployee(id: i,
                       lastName: surnames.randomElement(using: &rng) ?? "Smith",
                       firstName: firstNames.randomElement(using: &rng) ?? "Jan",
                       reportsTo: i <= 2 ? nil : Int.random(in: 1...2, using: &rng))
        }

        let products: [NWProduct] = (1...77).map { i in
            NWProduct(id: i,
                      name: "Product \(i)",
                      categoryID: Int.random(in: 1...8, using: &rng),
                      supplierID: Int.random(in: 1...10, using: &rng),
                      unitPrice: Double(Int.random(in: 300...12000, using: &rng)) / 100,
                      unitsInStock: Int.random(in: 0...150, using: &rng),
                      discontinued: Int.random(in: 0..<20, using: &rng) == 0)
        }

        let customerCount = max(10, orderCount / 20)
        let customers: [NWCustomer] = (0..<customerCount).map { i in
            NWCustomer(id: String(format: "CUST%05d", i),
                       companyName: "Company \(i)",
                       contactName: "\(firstNames.randomElement(using: &rng) ?? "Jan") \(surnames.randomElement(using: &rng) ?? "Smith")",
                       city: cities.randomElement(using: &rng)!,
                       country: countries.randomElement(using: &rng)!)
        }

        var orders: [NWOrder] = []
        var details: [NWOrderDetail] = []
        orders.reserveCapacity(orderCount)
        details.reserveCapacity(orderCount * 4)
        let baseDate = 852_076_800.0   // 1997-01-01

        for oid in 1...max(1, orderCount) {
            let cust = customers[Int.random(in: 0..<customers.count, using: &rng)]
            orders.append(NWOrder(
                id: oid,
                customerID: cust.id,
                employeeID: Int.random(in: 1...9, using: &rng),
                shipVia: Int.random(in: 1...3, using: &rng),
                orderDate: baseDate + Double(Int.random(in: 0..<31_536_000, using: &rng)),
                freight: Double(Int.random(in: 0...50000, using: &rng)) / 100,
                shipCountry: cust.country))

            // 1–7 distinct products per order (composite PK OrderID+ProductID).
            var used = Set<Int>()
            for _ in 0..<Int.random(in: 1...7, using: &rng) {
                let pid = Int.random(in: 1...77, using: &rng)
                guard used.insert(pid).inserted else { continue }
                let product = products[pid - 1]
                details.append(NWOrderDetail(
                    orderID: oid,
                    productID: pid,
                    unitPrice: product.unitPrice,
                    quantity: Int.random(in: 1...30, using: &rng),
                    discount: [0.0, 0.0, 0.0, 0.05, 0.1, 0.15, 0.2].randomElement(using: &rng)!))
            }
        }

        return NorthwindDataset(categories: categories, suppliers: suppliers, shippers: shippers,
                                employees: employees, customers: customers, products: products,
                                orders: orders, orderDetails: details)
    }
}
