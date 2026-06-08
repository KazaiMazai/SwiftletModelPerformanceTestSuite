//
//  Runner.swift
//  benchmarks
//
//  Entry point. Holds the registry of benchmark suites and runs each declared
//  case over every size, recording timings to CSV. Replaces XCTest discovery —
//  suites are listed explicitly here, and filtering is by plain CLI args.
//
//  Usage: swift run -c release benchmarks [--suite <substring>] [--size <n>]
//

import Foundation

@main
struct BenchmarkRunner {

    /// Every benchmark suite. Flat micro-benchmarks write to `results.csv`;
    /// the Northwind suites write to `relational.csv` (routed by class name).
    static let suites: [BenchmarkCase.Type] = [
        // SwiftletModel
        SwiftletModelIndexedReadTests.self,
        SwiftletModelUnindexedReadTests.self,
        SwiftletModelIndexedWriteTests.self,
        SwiftletModelUnindexedWriteTests.self,
        // SwiftData
        SwiftDataReadTests.self,
        SwiftDataIndexedReadTests.self,
        SwiftDataWriteTests.self,
        SwiftDataIndexedWriteTests.self,
        // Realm
        RealmReadTests.self,
        RealmIndexedReadTests.self,
        RealmWriteTests.self,
        RealmIndexedWriteTests.self,
        // GRDB
        GRDBReadTests.self,
        GRDBWriteTests.self,
        // SQLiteData
        SQLiteDataReadTests.self,
        SQLiteDataWriteTests.self,
        // Relational (Northwind) → relational.csv
        SwiftletModelNorthwindReadTests.self,
        GRDBNorthwindReadTests.self,
        SwiftDataNorthwindReadTests.self,
    ]

    static func main() {
        var suiteFilter: String?
        var sizeFilter: Int?

        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--suite": i += 1; if i < args.count { suiteFilter = args[i] }
            case "--size":  i += 1; if i < args.count { sizeFilter = Int(args[i]) }
            case "-h", "--help": printHelp(); return
            default: break
            }
            i += 1
        }

        let selected = suites.filter {
            suiteFilter == nil || $0.suiteName.localizedCaseInsensitiveContains(suiteFilter!)
        }
        guard !selected.isEmpty else {
            FileHandle.standardError.write(Data("benchmarks: no suites match '\(suiteFilter ?? "")'\n".utf8))
            exit(1)
        }
        let sizes = sizeFilter.map { [$0] } ?? BenchmarkCase.sizes

        var done = 0
        for suiteType in selected {
            let instance = suiteType.init()
            for entry in suiteType.cases() {
                let (operation, valueType) = BenchmarkCase.parse(name: entry.name)
                for size in sizes {
                    let key = BenchmarkKey(
                        engine: suiteType.engine, indexing: suiteType.indexing,
                        access: suiteType.access, operation: operation, valueType: valueType,
                        size: size, file: suiteType.file)
                    instance.current = key
                    entry.body(instance, size)
                    BenchmarkResultsWriter.flush(key)
                    done += 1
                    print("✓ \(suiteType.suiteName).\(entry.name) [\(size)]")
                }
            }
        }
        print("\nDone: \(done) cases across \(selected.count) suite(s).")
    }

    static func printHelp() {
        print("""
        benchmarks — run the SwiftletModel performance suite (no XCTest)

        USAGE: swift run -c release benchmarks [--suite <substring>] [--size <n>]

          --suite <substring>   only run suites whose class name contains <substring>
                                (case-insensitive), e.g. --suite SwiftletModel,
                                --suite Northwind, --suite IndexedWrite
          --size <n>            only run the given dataset size (default: 10/100/1000/10000)

        Flat results → BenchmarkResults/results.csv; Northwind → relational.csv.
        Render with: swift run bench-report  (add --relational / --by-engine / --index-cost)

        IMPORTANT: always run with -c release — a debug build compiles the Swift
        engine layers unoptimized and distorts the comparison. A filtered run
        rewrites only the file(s) its suites touch.
        """)
    }
}
