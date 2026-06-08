//
//  BenchReport.swift
//  bench-report
//
//  Parses BenchmarkResults/results.csv and prints a per-size comparison table
//  (operations × engine configs) with the fastest cell per row highlighted.
//
//  Usage: swift run bench-report [path] [--type int|string] [--metric avg|min]
//         swift run bench-report --relational   (Northwind views, relational.csv)
//

import Foundation

@main
struct BenchReport {

    struct Row {
        let engine, indexing, access, operation, valueType: String
        let size, samples: Int
        let avg, min, max, stddev: Double
    }

    // Column order + display labels. `idx` = indexed; a bare engine name is the
    // config with no secondary index (SwiftletModel's unindexed, the others' default).
    static let configOrder: [(engine: String, indexing: String, label: String)] = [
        ("SwiftletModel", "indexed",   "Swiftlet idx"),
        ("SwiftletModel", "unindexed", "Swiftlet"),
        ("GRDB",          "default",   "GRDB"),
        ("SQLiteData",    "default",   "SQLiteData"),
        ("Realm",         "default",   "Realm"),
        ("Realm",         "indexed",   "Realm idx"),
        ("SwiftData",     "default",   "SwiftData"),
        ("SwiftData",     "indexed",   "SwiftData idx"),
    ]

    static let operations = ["byID", "equality", "notEqual", "comparison", "sort", "insert", "update"]
    static let typedReads: Set<String> = ["equality", "notEqual", "comparison", "sort"]

    // Relational (Northwind) mode: the three relational engines and the four
    // view workloads. None of these are typed, so `typedReads` is empty.
    static let relationalConfigOrder: [(engine: String, indexing: String, label: String)] = [
        ("SwiftletModel", "default", "Swiftlet"),
        ("GRDB",          "default", "GRDB"),
        ("SwiftData",     "default", "SwiftData"),
    ]
    static let relationalOps = ["orderDetailsExtended", "productsByCategory", "orderInvoice", "invoices"]

    // Display labels for the (machine-friendly) operation keys.
    static let opLabels: [String: String] = [
        "byID": "ID lookup", "equality": "equal", "notEqual": "not equal",
        "comparison": "compare", "sort": "sort", "insert": "insert", "update": "update",
        "orderDetailsExtended": "orderDetailsExt", "productsByCategory": "productsByCat",
        "orderInvoice": "orderInvoice (nav)", "invoices": "invoices (bulk)",
    ]
    static func label(_ op: String) -> String { opLabels[op] ?? op }

    /// Resolves which `valueType` row to read for a cell. Typed reads use the
    /// requested int/string. The SwiftletModel *indexed* config splits its writes
    /// by index kind (`hash`/`comparable`); here we surface the comparable (B-tree)
    /// variant as the representative so the cross-engine write rows compare one
    /// B-tree index per engine. The hash variant is reported separately. Everything
    /// else (untyped ops) uses "-".
    static func lookupVT(_ op: String, _ valueType: String, _ typedReads: Set<String>,
                         engine: String, indexing: String) -> String {
        if typedReads.contains(op) { return valueType }
        if (op == "insert" || op == "update") && engine == "SwiftletModel" && indexing == "indexed" {
            return "comparable"
        }
        return "-"
    }

    static func main() {
        var valueType = "int"
        var metric = "avg"
        var byEngine = false
        var relational = false
        var indexCost = false
        var explicitPath: String?

        let rest = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < rest.count {
            switch rest[i] {
            case "--type":   i += 1; if i < rest.count { valueType = rest[i] }
            case "--metric": i += 1; if i < rest.count { metric = rest[i] }
            case "--by-engine": byEngine = true
            case "--relational": relational = true
            case "--index-cost": indexCost = true
            case "-h", "--help": printHelp(); return
            default: if !rest[i].hasPrefix("-") { explicitPath = rest[i] }
            }
            i += 1
        }

        let path = explicitPath ?? (relational ? "BenchmarkResults/relational.csv" : "BenchmarkResults/results.csv")
        let allConfigs = relational ? relationalConfigOrder : configOrder
        let ops = relational ? relationalOps : operations
        let typed: Set<String> = relational ? [] : typedReads
        let unit = relational ? "orders" : "rows"

        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            FileHandle.standardError.write(Data("bench-report: cannot read '\(path)'\n".utf8))
            exit(1)
        }
        let rows = parse(text)
        guard !rows.isEmpty else {
            FileHandle.standardError.write(Data("bench-report: no rows in '\(path)'\n".utf8))
            exit(1)
        }

        let configs = allConfigs.filter { c in
            rows.contains { $0.engine == c.engine && $0.indexing == c.indexing }
        }
        let sizes = Set(rows.map { $0.size }).sorted()

        if indexCost {
            renderIndexCost(rows: rows, sizes: sizes, metric: metric)
            return
        }

        if byEngine {
            for c in configs {
                renderByEngine(rows: rows, config: c, sizes: sizes, valueType: valueType,
                               metric: metric, operations: ops, typedReads: typed, unit: unit)
                print("")
            }
        } else {
            for size in sizes {
                render(rows: rows, size: size, configs: configs, valueType: valueType,
                       metric: metric, operations: ops, typedReads: typed, unit: unit)
                print("")
            }
        }
    }

    // MARK: - Per-engine scaling table (rows = sizes, columns = operations)

    static func renderByEngine(rows: [Row], config: (engine: String, indexing: String, label: String),
                               sizes: [Int], valueType: String, metric: String,
                               operations: [String], typedReads: Set<String>, unit: String) {

        func value(_ op: String, _ size: Int) -> Double? {
            let vt = lookupVT(op, valueType, typedReads, engine: config.engine, indexing: config.indexing)
            guard let r = rows.first(where: {
                $0.engine == config.engine && $0.indexing == config.indexing
                && $0.operation == op && $0.valueType == vt && $0.size == size
            }) else { return nil }
            return metric == "min" ? r.min : r.avg
        }

        let sizeLabels = sizes.map { $0.formattedWithCommas() }
        var rowsW = unit.count
        for s in sizeLabels { rowsW = max(rowsW, s.count) }

        var colW = operations.map { label($0).count }
        for (oi, op) in operations.enumerated() {
            for size in sizes { if let v = value(op, size) { colW[oi] = max(colW[oi], fmt(v).count) } }
        }

        let typedNote = typedReads.isEmpty ? "" : " · typed reads = \(valueType)"
        print(bold("  \(config.engine) · \(config.indexing) · \(metric) ms\(typedNote)  "))
        printRule(rowsW, colW, "┌", "┬", "┐")
        printRow(rowsW, colW, unit.padded(rowsW), operations.enumerated().map { label($1).centered(colW[$0]) }, bolded: true)
        printRule(rowsW, colW, "├", "┼", "┤")
        for (si, size) in sizes.enumerated() {
            let cells = operations.enumerated().map { (oi, op) -> String in
                guard let v = value(op, size) else { return "—".rightPadded(colW[oi]) }
                return fmt(v).leftPadded(colW[oi])
            }
            printRow(rowsW, colW, sizeLabels[si].leftPadded(rowsW), cells, bolded: false)
        }
        printRule(rowsW, colW, "└", "┴", "┘")
    }

    // MARK: - SwiftletModel index-maintenance breakdown (hash vs comparable)

    static func renderIndexCost(rows: [Row], sizes: [Int], metric: String) {
        // Columns: each (operation, index kind) pair that SwiftletModel writes split into.
        let cols: [(op: String, kind: String, label: String)] = [
            ("insert", "hash", "insert·hash"), ("insert", "comparable", "insert·cmp"),
            ("update", "hash", "update·hash"), ("update", "comparable", "update·cmp"),
        ]

        func value(_ op: String, _ kind: String, _ size: Int) -> Double? {
            guard let r = rows.first(where: {
                $0.engine == "SwiftletModel" && $0.indexing == "indexed"
                && $0.operation == op && $0.valueType == kind && $0.size == size
            }) else { return nil }
            return metric == "min" ? r.min : r.avg
        }

        let sizeLabels = sizes.map { $0.formattedWithCommas() }
        var rowsW = "rows".count
        for s in sizeLabels { rowsW = max(rowsW, s.count) }

        var colW = cols.map { $0.label.count }
        for (ci, c) in cols.enumerated() {
            for size in sizes { if let v = value(c.op, c.kind, size) { colW[ci] = max(colW[ci], fmt(v).count) } }
        }

        print(bold("  SwiftletModel · indexed · write cost per single index · \(metric) ms  "))
        printRule(rowsW, colW, "┌", "┬", "┐")
        printRow(rowsW, colW, "rows".padded(rowsW), cols.enumerated().map { $1.label.centered(colW[$0]) }, bolded: true)
        printRule(rowsW, colW, "├", "┼", "┤")
        for (si, size) in sizes.enumerated() {
            let cells = cols.enumerated().map { (ci, c) -> String in
                guard let v = value(c.op, c.kind, size) else { return "—".rightPadded(colW[ci]) }
                return fmt(v).leftPadded(colW[ci])
            }
            printRow(rowsW, colW, sizeLabels[si].leftPadded(rowsW), cells, bolded: false)
        }
        printRule(rowsW, colW, "└", "┴", "┘")
    }

    // MARK: - Rendering

    static func render(rows: [Row], size: Int,
                       configs: [(engine: String, indexing: String, label: String)],
                       valueType: String, metric: String,
                       operations: [String], typedReads: Set<String>, unit: String) {

        func value(_ op: String, _ c: (engine: String, indexing: String, label: String)) -> Double? {
            let vt = lookupVT(op, valueType, typedReads, engine: c.engine, indexing: c.indexing)
            guard let r = rows.first(where: {
                $0.engine == c.engine && $0.indexing == c.indexing
                && $0.operation == op && $0.valueType == vt && $0.size == size
            }) else { return nil }
            return metric == "min" ? r.min : r.avg
        }

        // Column widths.
        let opHeader = "operation"
        var labelW = opHeader.count
        for op in operations { labelW = max(labelW, label(op).count) }

        var colW = configs.map { max($0.label.count, 7) }
        for (ci, c) in configs.enumerated() {
            for op in operations {
                if let v = value(op, c) { colW[ci] = max(colW[ci], fmt(v).count) }
            }
        }

        let typedNote = typedReads.isEmpty ? "" : " · typed reads = \(valueType)"
        let title = "  \(size.formattedWithCommas()) \(unit) · \(metric) ms\(typedNote)  "
        print(bold(title))

        // Header
        printRule(labelW, colW, "┌", "┬", "┐")
        printRow(labelW, colW, opHeader.padded(labelW), configs.enumerated().map { $1.label.centered(colW[$0]) }, bolded: true)
        printRule(labelW, colW, "├", "┼", "┤")

        // Body
        for op in operations {
            let vals = configs.map { value(op, $0) }
            let present = vals.compactMap { $0 }
            guard !present.isEmpty else { continue }
            let best = present.min()!
            let cells = vals.enumerated().map { (ci, v) -> String in
                guard let v else { return "—".rightPadded(colW[ci]) }
                let s = fmt(v).leftPadded(colW[ci])
                return v == best ? highlight(s) : s
            }
            printRow(labelW, colW, label(op).padded(labelW), cells, bolded: false)
        }

        printRule(labelW, colW, "└", "┴", "┘")
    }

    // MARK: - Table primitives

    static func printRule(_ lw: Int, _ cw: [Int], _ l: String, _ m: String, _ r: String) {
        var s = l + String(repeating: "─", count: lw + 2)
        for w in cw { s += m + String(repeating: "─", count: w + 2) }
        s += r
        print(s)
    }

    static func printRow(_ lw: Int, _ cw: [Int], _ label: String, _ cells: [String], bolded: Bool) {
        var s = "│ " + (bolded ? bold(label) : label) + " "
        for c in cells { s += "│ " + c + " " }
        s += "│"
        print(s)
    }

    // MARK: - Formatting helpers

    static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    static let isTTY = isatty(STDOUT_FILENO) != 0
    static func bold(_ s: String) -> String { isTTY ? "\u{001B}[1m\(s)\u{001B}[0m" : s }
    static func highlight(_ s: String) -> String { isTTY ? "\u{001B}[1;32m\(s)\u{001B}[0m" : s }
    static func highlightIf(_ cond: Bool, _ s: String) -> String { cond ? highlight(s) : s }

    static func parse(_ text: String) -> [Row] {
        text.split(separator: "\n").dropFirst().compactMap { line in
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 11 else { return nil }
            return Row(engine: f[0], indexing: f[1], access: f[2], operation: f[3], valueType: f[4],
                       size: Int(f[5]) ?? 0, samples: Int(f[6]) ?? 0,
                       avg: Double(f[7]) ?? 0, min: Double(f[8]) ?? 0,
                       max: Double(f[9]) ?? 0, stddev: Double(f[10]) ?? 0)
        }
    }

    static func printHelp() {
        print("""
        bench-report — render BenchmarkResults CSV as a comparison table

        USAGE: swift run bench-report [path] [--type int|string] [--metric avg|min] [--by-engine] [--relational]

          path          CSV path (default: BenchmarkResults/results.csv,
                        or BenchmarkResults/relational.csv with --relational)
          --type        value type for typed reads: int (default) or string
          --metric      avg (default) or min
          --by-engine   one table per engine, rows = item counts, columns = operations
                        (default layout: one table per size, rows = ops, columns = engines)
          --relational  render the Northwind relational-view results (SwiftletModel /
                        GRDB / SwiftData over orderDetailsExt, productsByCat,
                        orderInvoice, invoices); size = order count
          --index-cost  SwiftletModel indexed write cost broken down by index kind
                        (hash vs comparable BTree) for insert/update across sizes

        Note: in the flat tables, SwiftletModel·indexed writes show the comparable
        (BTree) variant as the representative; use --index-cost for the full split.
        """)
    }
}

private extension String {
    func padded(_ w: Int) -> String { count >= w ? self : self + String(repeating: " ", count: w - count) }
    func leftPadded(_ w: Int) -> String { count >= w ? self : String(repeating: " ", count: w - count) + self }
    func rightPadded(_ w: Int) -> String { leftPadded(w) }
    func centered(_ w: Int) -> String {
        guard count < w else { return self }
        let total = w - count, left = total / 2
        return String(repeating: " ", count: left) + self + String(repeating: " ", count: total - left)
    }
}

private extension Int {
    func formattedWithCommas() -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
