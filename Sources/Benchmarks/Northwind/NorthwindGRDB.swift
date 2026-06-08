//
//  NorthwindGRDB.swift
//  SwiftletModelPerformanceTestSuite
//
//  Northwind schema in plain GRDB (the SQL-join baseline): FK columns + indexes,
//  and the view workloads as hand-written indexed JOINs — SQLite's best case.
//

import Foundation
import GRDB

enum NorthwindGRDB {

    private static let schema = """
        CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
        CREATE TABLE suppliers (id INTEGER PRIMARY KEY, companyName TEXT NOT NULL, country TEXT NOT NULL);
        CREATE TABLE shippers (id INTEGER PRIMARY KEY, companyName TEXT NOT NULL);
        CREATE TABLE employees (id INTEGER PRIMARY KEY, lastName TEXT NOT NULL, firstName TEXT NOT NULL);
        CREATE TABLE customers (id TEXT PRIMARY KEY, companyName TEXT NOT NULL, contactName TEXT NOT NULL, city TEXT NOT NULL, country TEXT NOT NULL);
        CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT NOT NULL, categoryID INTEGER, supplierID INTEGER, unitPrice REAL NOT NULL, unitsInStock INTEGER NOT NULL, discontinued INTEGER NOT NULL);
        CREATE TABLE orders (id INTEGER PRIMARY KEY, customerID TEXT, employeeID INTEGER, shipVia INTEGER, orderDate REAL NOT NULL, freight REAL NOT NULL, shipCountry TEXT NOT NULL);
        CREATE TABLE orderDetails (orderID INTEGER NOT NULL, productID INTEGER NOT NULL, unitPrice REAL NOT NULL, quantity INTEGER NOT NULL, discount REAL NOT NULL, PRIMARY KEY (orderID, productID));
        CREATE INDEX ix_products_category ON products(categoryID);
        CREATE INDEX ix_orders_customer ON orders(customerID);
        CREATE INDEX ix_orders_employee ON orders(employeeID);
        CREATE INDEX ix_orders_shipper ON orders(shipVia);
        CREATE INDEX ix_od_product ON orderDetails(productID);
        """

    static func queue(_ ds: NorthwindDataset) -> DatabaseQueue {
        let q = try! DatabaseQueue()
        try! q.write { db in
            try db.execute(sql: schema)
            for c in ds.categories { try db.execute(sql: "INSERT INTO categories VALUES (?,?)", arguments: [c.id, c.name]) }
            for s in ds.suppliers { try db.execute(sql: "INSERT INTO suppliers VALUES (?,?,?)", arguments: [s.id, s.companyName, s.country]) }
            for s in ds.shippers { try db.execute(sql: "INSERT INTO shippers VALUES (?,?)", arguments: [s.id, s.companyName]) }
            for e in ds.employees { try db.execute(sql: "INSERT INTO employees VALUES (?,?,?)", arguments: [e.id, e.lastName, e.firstName]) }
            for c in ds.customers { try db.execute(sql: "INSERT INTO customers VALUES (?,?,?,?,?)", arguments: [c.id, c.companyName, c.contactName, c.city, c.country]) }
            for p in ds.products { try db.execute(sql: "INSERT INTO products VALUES (?,?,?,?,?,?,?)", arguments: [p.id, p.name, p.categoryID, p.supplierID, p.unitPrice, p.unitsInStock, p.discontinued ? 1 : 0]) }
            for o in ds.orders { try db.execute(sql: "INSERT INTO orders VALUES (?,?,?,?,?,?,?)", arguments: [o.id, o.customerID, o.employeeID, o.shipVia, o.orderDate, o.freight, o.shipCountry]) }
            for d in ds.orderDetails { try db.execute(sql: "INSERT INTO orderDetails VALUES (?,?,?,?,?)", arguments: [d.orderID, d.productID, d.unitPrice, d.quantity, d.discount]) }
        }
        return q
    }

    // MARK: - View workloads (hand-written JOINs)

    static func orderDetailsExtended(_ q: DatabaseQueue) -> Int {
        try! q.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT od.orderID, od.productID, p.name AS productName, od.unitPrice, od.quantity, od.discount
                FROM orderDetails od JOIN products p ON p.id = od.productID
                """)
            var count = 0
            for r in rows {
                let unitPrice: Double = r["unitPrice"]; let quantity: Int = r["quantity"]; let discount: Double = r["discount"]
                let name: String = r["productName"]
                _ = (name, unitPrice * Double(quantity) * (1 - discount))
                count += 1
            }
            return count
        }
    }

    static func productsByCategory(_ q: DatabaseQueue) -> Int {
        try! q.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT c.name AS categoryName, p.name AS productName, p.unitsInStock, p.discontinued
                FROM categories c JOIN products p ON c.id = p.categoryID
                WHERE p.discontinued <> 1
                """)
            var count = 0
            for r in rows {
                let cat: String = r["categoryName"]; let name: String = r["productName"]; let stock: Int = r["unitsInStock"]
                _ = (cat, name, stock)
                count += 1
            }
            return count
        }
    }

    /// Navigational: one joined query per sampled order (prepared statement is
    /// cached, but each lookup still executes the join + statement step).
    static func orderInvoice(_ q: DatabaseQueue, orderIDs: [Int]) -> Int {
        try! q.read { db in
            var rows = 0
            for oid in orderIDs {
                let r = try Row.fetchAll(db, sql: """
                    SELECT cu.companyName AS customerName, e.firstName AS salesperson,
                           sh.companyName AS shipperName, p.name AS productName,
                           od.unitPrice, od.quantity, od.discount
                    FROM orders o
                    JOIN customers cu ON cu.id = o.customerID
                    JOIN employees e ON e.id = o.employeeID
                    JOIN shippers sh ON sh.id = o.shipVia
                    JOIN orderDetails od ON o.id = od.orderID
                    JOIN products p ON p.id = od.productID
                    WHERE o.id = ?
                    """, arguments: [oid])
                for row in r {
                    let unitPrice: Double = row["unitPrice"]; let quantity: Int = row["quantity"]; let discount: Double = row["discount"]
                    let cust: String = row["customerName"]; let prod: String = row["productName"]
                    _ = (cust, prod, unitPrice * Double(quantity) * (1 - discount))
                    rows += 1
                }
            }
            return rows
        }
    }

    static func invoices(_ q: DatabaseQueue) -> Int {
        try! q.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT o.id AS orderID, cu.companyName AS customerName, e.firstName AS salesperson,
                       sh.companyName AS shipperName, p.name AS productName,
                       od.unitPrice, od.quantity, od.discount
                FROM customers cu
                JOIN orders o ON cu.id = o.customerID
                JOIN employees e ON e.id = o.employeeID
                JOIN orderDetails od ON o.id = od.orderID
                JOIN products p ON p.id = od.productID
                JOIN shippers sh ON sh.id = o.shipVia
                """)
            var count = 0
            for r in rows {
                let unitPrice: Double = r["unitPrice"]; let quantity: Int = r["quantity"]; let discount: Double = r["discount"]
                let orderID: Int = r["orderID"]; let cust: String = r["customerName"]
                let sales: String = r["salesperson"]; let ship: String = r["shipperName"]; let prod: String = r["productName"]
                _ = (orderID, cust, sales, ship, prod, unitPrice * Double(quantity) * (1 - discount))
                count += 1
            }
            return count
        }
    }
}
